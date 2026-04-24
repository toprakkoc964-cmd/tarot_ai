import { BatchResponse, getMessaging } from 'firebase-admin/messaging';
import { getFirestore } from 'firebase-admin/firestore';

function db() {
  return getFirestore();
}

function messaging() {
  return getMessaging();
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

  return [...new Set([...inlineTokens, ...subcollectionTokens])];
}

export async function sendAudioReadyNotification(input: {
  uid: string;
  readingId: string;
  lang: string;
}) {
  const tokens = await getUserFcmTokens(input.uid);
  if (tokens.length === 0) {
    return {
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
      failures: [],
    };
  }

  const title = input.lang === 'tr' ? 'Sesli falın hazır' : 'Your audio reading is ready';
  const body =
    input.lang === 'tr'
      ? 'Emilia mesajını seslendirdi. Dinlemek için uygulamayı aç.'
      : 'Emilia has narrated your reading. Open the app to listen.';

  const response = await messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      type: 'reading_audio_ready',
      readingId: input.readingId
    }
  });

  return summarizeBatchResponse(tokens, response);
}

export async function sendDailyNudge(input: {
  uid: string;
  lang: string;
  zodiac: string;
  deepLink: string;
}) {
  const tokens = await getUserFcmTokens(input.uid);
  if (tokens.length === 0) {
    return {
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
      failures: [],
    };
  }

  const title = input.lang === 'tr' ? 'Gunun karti seni bekliyor' : 'Your daily card is waiting';
  const body =
    input.lang === 'tr'
      ? `${input.zodiac} enerjin icin bugunluk acilim hazir.`
      : `A quick spread is ready for your ${input.zodiac} energy today.`;

  const response = await messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      type: 'daily_nudge',
      deeplink: input.deepLink
    }
  });

  return summarizeBatchResponse(tokens, response);
}
