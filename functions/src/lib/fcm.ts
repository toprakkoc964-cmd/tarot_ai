import { BatchResponse, getMessaging } from 'firebase-admin/messaging';
import { createHash } from 'node:crypto';
import { FieldPath, FieldValue, getFirestore } from 'firebase-admin/firestore';

function db() {
  return getFirestore();
}

function messaging() {
  return getMessaging();
}

function tokenOwnerId(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function tokenOwnerRef(token: string) {
  return db().collection('fcm_token_owners').doc(tokenOwnerId(token));
}

async function removeTokenFromUid(uid: string, token: string): Promise<void> {
  const userRef = db().collection('users').doc(uid);
  await Promise.all([
    userRef
      .set({ fcmTokens: FieldValue.arrayRemove(token) }, { merge: true })
      .catch(() => {}),
    userRef.collection('fcm_tokens').doc(token).delete().catch(() => {}),
  ]);
}

async function removeTokenFromOtherUsers(token: string, ownerUid: string): Promise<void> {
  const inlineSnap = await db()
    .collection('users')
    .where('fcmTokens', 'array-contains', token)
    .get();

  await Promise.all(
    inlineSnap.docs
      .filter((doc) => doc.id !== ownerUid)
      .map((doc) => removeTokenFromUid(doc.id, token))
  );

  try {
    const subcollectionSnap = await db()
      .collectionGroup('fcm_tokens')
      .where(FieldPath.documentId(), '==', token)
      .get();

    await Promise.all(
      subcollectionSnap.docs.map(async (doc) => {
        const userRef = doc.ref.parent.parent;
        const uid = userRef?.id;
        if (!uid || uid === ownerUid) return;
        await removeTokenFromUid(uid, token);
      })
    );
  } catch {
    // Some legacy token ids can be awkward for collectionGroup document-id
    // queries. The inline-token cleanup and owner mapping still protect future
    // sends, so do not fail registration.
  }
}

export async function registerFcmTokenForUid(uid: string, token: string): Promise<void> {
  await removeTokenFromOtherUsers(token, uid);
  const userRef = db().collection('users').doc(uid);
  await Promise.all([
    userRef.set(
      {
        fcmTokens: FieldValue.arrayUnion(token),
        fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    ),
    userRef.collection('fcm_tokens').doc(token).set(
      {
        uid,
        token,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    ),
    tokenOwnerRef(token).set(
      {
        uid,
        tokenHash: tokenOwnerId(token),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    ),
  ]);
}

export async function unregisterFcmTokenForUid(uid: string, token: string): Promise<void> {
  await removeTokenFromUid(uid, token);
  const ownerRef = tokenOwnerRef(token);
  const ownerSnap = await ownerRef.get();
  if (ownerSnap.get('uid') === uid) {
    await ownerRef.delete().catch(() => {});
  }
}

export type NotificationSendResult = {
  tokenCount: number;
  successCount: number;
  failureCount: number;
  failures: Array<{
    token: string;
    code: string;
    message: string;
  }>;
};

function summarizeBatchResponse(tokens: string[], response: BatchResponse): NotificationSendResult {
  return {
    tokenCount: tokens.length,
    successCount: response.successCount,
    failureCount: response.failureCount,
    failures: response.responses
      .map((item, index) => {
        if (item.success || !item.error) return null;
        return {
          token: tokens[index] ?? 'unknown',
          code: item.error.code,
          message: item.error.message,
        };
      })
      .filter((item): item is NonNullable<typeof item> => item !== null),
  };
}

async function pruneInvalidTokens(
  uid: string,
  failures: NotificationSendResult['failures']
): Promise<void> {
  const badTokens = failures
    .filter((failure) =>
      failure.code === 'messaging/registration-token-not-registered' ||
      failure.code === 'messaging/invalid-registration-token'
    )
    .map((failure) => failure.token)
    .filter((token) => token && token !== 'unknown');

  if (badTokens.length === 0) return;

  const userRef = db().collection('users').doc(uid);
  await userRef
    .set({ fcmTokens: FieldValue.arrayRemove(...badTokens) }, { merge: true })
    .catch(() => {});

  await Promise.all(
    badTokens.map((token) =>
      userRef.collection('fcm_tokens').doc(token).delete().catch(() => {})
    )
  );
}

async function filterTokensOwnedByUid(uid: string, tokens: string[]): Promise<string[]> {
  const result: string[] = [];
  await Promise.all(
    tokens.map(async (token) => {
      const ownerSnap = await tokenOwnerRef(token).get().catch(() => null);
      const ownerUid = ownerSnap?.get('uid');
      if (ownerUid && ownerUid !== uid) {
        await removeTokenFromUid(uid, token);
        return;
      }
      result.push(token);
    })
  );
  return result;
}

export async function getUserFcmTokens(uid: string): Promise<string[]> {
  const userRef = db().collection('users').doc(uid);
  const [userSnap, tokensSnap] = await Promise.all([
    userRef.get(),
    userRef.collection('fcm_tokens').get(),
  ]);

  const inlineTokens = Array.isArray(userSnap.get('fcmTokens'))
    ? userSnap
        .get('fcmTokens')
        .filter((value: unknown): value is string => typeof value === 'string')
    : [];

  const subcollectionTokens = tokensSnap.docs
    .map((doc) => doc.id)
    .filter((token) => token.length > 8);

  const uniqueTokens = [...new Set([...inlineTokens, ...subcollectionTokens])];
  return filterTokensOwnedByUid(uid, uniqueTokens);
}

export async function sendAudioReadyNotification(input: {
  uid: string;
  readingId: string;
  lang: string;
}) {
  const title = input.lang === 'tr' ? 'Sesli falın hazır' : 'Your audio reading is ready';
  const body =
    input.lang === 'tr'
      ? 'Emilia mesajını seslendirdi. Dinlemek için uygulamayı aç.'
      : 'Emilia has narrated your reading. Open the app to listen.';

  return sendNotificationToUser({
    uid: input.uid,
    title,
    body,
    data: {
      type: 'reading_audio_ready',
      readingId: input.readingId
    }
  });
}

export async function sendNotificationToUser(input: {
  uid: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<NotificationSendResult> {
  const tokens = await getUserFcmTokens(input.uid);
  if (tokens.length === 0) {
    return {
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
      failures: [],
    };
  }

  const response = await messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: input.title,
      body: input.body
    },
    data: input.data ?? {}
  });

  const summary = summarizeBatchResponse(tokens, response);
  await pruneInvalidTokens(input.uid, summary.failures);
  return summary;
}
