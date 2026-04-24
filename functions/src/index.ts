import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldPath, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as functionsV1 from 'firebase-functions/v1';
import * as logger from 'firebase-functions/logger';
import { mapError } from './lib/errors';
import { buildSystemPrompt } from './lib/context-builder';
import { createReadingText } from './lib/openai';
import { renderShareImage } from './lib/share-image';
import { buildShareDeepLink } from './lib/deep-link';
import { validateAppleReceipt } from './lib/purchase';
import { requireIdempotencyKey } from './lib/idempotency';
import { AIPersonaDoc, UserDoc } from './lib/types';
import { synthesizeSpeech } from './lib/audio';
import { getUserFcmTokens, sendAudioReadyNotification, sendDailyNudge } from './lib/fcm';
import { zodiacFromBirthDate } from './lib/zodiac';

initializeApp();

const db = getFirestore();
const storage = getStorage();

const consentVersion = process.env.CONSENT_VERSION ?? 'v1';
const initialFreeCredits = Number(process.env.INITIAL_FREE_CREDITS ?? '1');
const supportedLanguages = new Set(['tr', 'en', 'de', 'es', 'fr', 'it', 'pt']);
const defaultPersonaId = process.env.DEFAULT_PERSONA_ID ?? 'emilia';
const homeCardDrawCost = Number(process.env.HOME_CARD_DRAW_COST ?? '5');

function resolveLanguage(lang: unknown): string {
  if (typeof lang !== 'string') return 'en';
  const normalized = lang.trim().toLowerCase();
  return supportedLanguages.has(normalized) ? normalized : 'en';
}

function resolveUserBirthDate(user: UserDoc): string | null {
  const profileBirthDate = typeof user.profile?.birthDate === 'string'
    ? user.profile.birthDate.trim()
    : '';
  if (profileBirthDate) return profileBirthDate;

  const rootBirthDate = typeof user.birthDate === 'string'
    ? user.birthDate.trim()
    : '';
  return rootBirthDate || null;
}

async function getPersonaOrDefault(personaId: string): Promise<AIPersonaDoc> {
  const fallback: AIPersonaDoc = {
    name: 'Emilia',
    baseSystemPrompt: 'You are Emilia, a mystical but practical tarot guide.',
    tone: 'warm',
    active: true,
    version: 'v1'
  };

  const resolvedId = personaId || defaultPersonaId;
  const doc = await db.collection('ai_personas').doc(resolvedId).get();
  if (!doc.exists) return fallback;

  const data = doc.data() as AIPersonaDoc;
  if (!data.active || !data.baseSystemPrompt || !data.name) {
    return fallback;
  }
  return data;
}

export const handleUserCreated = functionsV1.auth.user().onCreate(async (user) => {
  if (!user?.uid) return;

  const userRef = db.collection('users').doc(user.uid);
  const snap = await userRef.get();
  if (snap.exists) return;

  const payload: UserDoc = {
    uid: user.uid,
    isProfileComplete: false,
    wallet: {
      credits: initialFreeCredits,
      isFirstFreeUsed: false
    },
    settings: {
      lang: 'tr',
      selectedPersonaId: 'emilia'
    },
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  };

  await userRef.set(payload, { merge: true });
});

export const handleUserDeleted = functionsV1.auth.user().onDelete(async (user) => {
  if (!user?.uid) return;

  const userRef = db.collection('users').doc(user.uid);
  try {
    await db.recursiveDelete(userRef);
  } catch (error) {
    functionsV1.logger.error('Failed to cleanup user document on auth delete', {
      uid: user.uid,
      error
    });
  }
});

export const generateTarotReading = onCall({ enforceAppCheck: false, secrets: ['GEMINI_API_KEY'] }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const appCheckOptional = (process.env.APP_CHECK_ENFORCE ?? 'false') === 'true';
    if (appCheckOptional && !request.app) {
      throw new Error('APP_CHECK_REQUIRED');
    }

    const intent = String(request.data?.intent ?? '').trim();
    const cards = Array.isArray(request.data?.cards) ? request.data.cards.map(String) : [];
    const idemKey = requireIdempotencyKey(request.data?.idempotencyKey);

    if (!intent || cards.length === 0) {
      throw new HttpsError('invalid-argument', 'INVALID_READING_INPUT');
    }

    const userRef = db.collection('users').doc(uid);
    const idempotencyRef = userRef.collection('idempotency').doc(`reading_${idemKey}`);

    const existingIdempotent = await idempotencyRef.get();
    if (existingIdempotent.exists) {
      return existingIdempotent.data();
    }

    const readingRef = userRef.collection('readings').doc();
    let previousCredits = 0;

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError('not-found', 'USER_NOT_FOUND');
      }

      const user = userSnap.data() as UserDoc;
      const profile = user.profile;
      if (!user.isProfileComplete || !profile?.name || !profile.birthDate) {
        throw new Error('PROFILE_INCOMPLETE');
      }

      if (user.wallet.credits <= 0) {
        throw new Error('INSUFFICIENT_CREDITS');
      }

      previousCredits = user.wallet.credits;
      tx.update(userRef, {
        'wallet.credits': previousCredits - 1,
        updatedAt: FieldValue.serverTimestamp()
      });

      tx.set(userRef.collection('credit_ledger').doc(), {
        type: 'debit',
        amount: -1,
        reason: 'reading_generation',
        idempotencyKey: idemKey,
        createdAt: FieldValue.serverTimestamp()
      });

      tx.set(readingRef, {
        uid,
        intent,
        cards,
        status: 'pending',
        idempotencyKey: idemKey,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });
    });

    try {
      const profileSnap = await userRef.get();
      const user = profileSnap.data() as UserDoc;
      const profile = user.profile!;
      const lang = resolveLanguage(user.settings?.lang);
      const persona = await getPersonaOrDefault(user.settings?.selectedPersonaId ?? defaultPersonaId);
      const systemPrompt = buildSystemPrompt(profile, intent, lang, persona);

      const aiResponse = await createReadingText({
        systemPrompt,
        userPrompt: `Chosen cards: ${cards.join(', ')}. Provide a tarot reading in ${lang}.`
      });

      const shareDeepLink = buildShareDeepLink(readingRef.id);
      const imageBuffer = renderShareImage({
        title: 'Share My Destiny',
        excerpt: aiResponse.slice(0, 220),
        footer: 'tarotai.app'
      });
      const filePath = `share/${uid}/${readingRef.id}.png`;
      const file = storage.bucket().file(filePath);
      await file.save(imageBuffer, { contentType: 'image/png', public: true });

      const shareImageUrl = `https://storage.googleapis.com/${storage.bucket().name}/${filePath}`;

      await readingRef.update({
        aiResponse,
        shareImageUrl,
        shareDeepLink,
        audioStatus: 'pending',
        status: 'succeeded_text',
        lang,
        updatedAt: FieldValue.serverTimestamp()
      });

      const result = {
        readingId: readingRef.id,
        aiResponse,
        shareImageUrl,
        shareDeepLink,
        audioStatus: 'pending',
        remainingCredits: previousCredits - 1
      };

      await idempotencyRef.set({ ...result, createdAt: FieldValue.serverTimestamp() });
      return result;
    } catch (innerError) {
      await db.runTransaction(async (tx) => {
        const userSnap = await tx.get(userRef);
        if (userSnap.exists) {
          const user = userSnap.data() as UserDoc;
          tx.update(userRef, {
            'wallet.credits': (user.wallet.credits ?? 0) + 1,
            updatedAt: FieldValue.serverTimestamp()
          });
        }

        tx.set(userRef.collection('credit_ledger').doc(), {
          type: 'refund',
          amount: 1,
          reason: 'reading_generation_rollback',
          idempotencyKey: idemKey,
          createdAt: FieldValue.serverTimestamp()
        });

        tx.update(readingRef, {
          status: 'failed_refunded',
          errorCode: 'AI_TEMPORARY_FAILURE',
          updatedAt: FieldValue.serverTimestamp()
        });
      });

      throw innerError;
    }
  } catch (err) {
    throw mapError(err);
  }
});

export const generateBirthFrequencyComment = onCall({ enforceAppCheck: false, secrets: ['GEMINI_API_KEY'] }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const incomingBirthDate = String(request.data?.birthDate ?? '').trim();
    const incomingDay = String(request.data?.day ?? '').trim();
    const incomingLang = String(request.data?.lang ?? '').trim();

    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'USER_NOT_FOUND');
    }

    const user = userSnap.data() as UserDoc;
    const birthDate = incomingBirthDate || resolveUserBirthDate(user) || '';
    if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
      throw new HttpsError('invalid-argument', 'INVALID_BIRTH_DATE');
    }

    const day = /^\d{4}-\d{2}-\d{2}$/.test(incomingDay)
      ? incomingDay
      : new Date().toISOString().slice(0, 10);
    const lang = resolveLanguage(incomingLang || user.settings?.lang);

    const systemPrompt = [
      'You are a mystical but practical astrology guide.',
      'Write exactly one short daily birth-frequency comment.',
      'It must feel personal, warm, and actionable.',
      'Do not use markdown, lists, or emojis.',
      'Use 1 or 2 short sentences only.',
      'Keep it under 28 words.',
      'Avoid repetition, disclaimers, and generic filler.'
    ].join(' ');

    const userPrompt = [
      `Language: ${lang}`,
      `Birth date: ${birthDate}`,
      `Target day: ${day}`,
      'Generate one concise daily comment for this user.',
      'Mention only the most relevant feeling or advice for today.'
    ].join('\n');

    const comment = (await createReadingText({ systemPrompt, userPrompt })).trim();
    if (!comment) {
      throw new Error('EMPTY_BIRTH_FREQUENCY_COMMENT');
    }

    return { comment, day, birthDate };
  } catch (err) {
    const errorCode = err instanceof HttpsError
      ? err.code
      : err instanceof Error
        ? err.name
        : 'unknown';
    const errorMessage = err instanceof Error ? err.message : String(err);
    logger.error('generateBirthFrequencyComment failed', {
      uid: request.auth?.uid ?? null,
      birthDate: String(request.data?.birthDate ?? '').trim() || null,
      day: String(request.data?.day ?? '').trim() || null,
      errorCode,
      errorMessage
    });
    throw mapError(err);
  }
});

export const consumeHomeCardDraw = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const userRef = db.collection('users').doc(uid);
    let remainingCredits = 0;

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError('not-found', 'USER_NOT_FOUND');
      }

      const user = userSnap.data() as UserDoc;
      const currentCredits = Number(user.wallet.credits ?? 0);
      if (currentCredits < homeCardDrawCost) {
        throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDITS');
      }

      remainingCredits = currentCredits - homeCardDrawCost;
      tx.update(userRef, {
        'wallet.credits': remainingCredits,
        updatedAt: FieldValue.serverTimestamp()
      });

      tx.set(userRef.collection('credit_ledger').doc(), {
        type: 'debit',
        amount: -homeCardDrawCost,
        reason: 'home_card_draw',
        createdAt: FieldValue.serverTimestamp()
      });
    });

    return {
      ok: true,
      drawCost: homeCardDrawCost,
      remainingCredits
    };
  } catch (err) {
    throw mapError(err);
  }
});

export const validateIosPurchase = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const idemKey = requireIdempotencyKey(request.data?.idempotencyKey);
    const transactionId = String(request.data?.transactionId ?? '');
    const productId = String(request.data?.productId ?? '');
    const receiptData = String(request.data?.receiptData ?? '');

    const userRef = db.collection('users').doc(uid);
    const idemRef = userRef.collection('idempotency').doc(`purchase_${idemKey}`);
    const transactionRef = userRef.collection('iap_transactions').doc(transactionId);
    const idemSnap = await idemRef.get();
    if (idemSnap.exists) {
      return idemSnap.data();
    }

    const validation = await validateAppleReceipt({ transactionId, productId, receiptData });
    if (!validation.isValid || validation.creditsToGrant <= 0) {
      throw new HttpsError('failed-precondition', 'PURCHASE_INVALID');
    }

    let remainingCredits = 0;
    await db.runTransaction(async (tx) => {
      const txSnap = await tx.get(transactionRef);
      if (txSnap.exists) {
        remainingCredits = Number((txSnap.data() as { remainingCredits?: number }).remainingCredits ?? 0);
        return;
      }

      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError('not-found', 'USER_NOT_FOUND');
      }

      const user = userSnap.data() as UserDoc;
      remainingCredits = (user.wallet.credits ?? 0) + validation.creditsToGrant;

      tx.update(userRef, {
        'wallet.credits': remainingCredits,
        updatedAt: FieldValue.serverTimestamp()
      });

      tx.set(userRef.collection('credit_ledger').doc(), {
        type: 'credit',
        amount: validation.creditsToGrant,
        reason: 'ios_purchase',
        productId,
        transactionId,
        idempotencyKey: idemKey,
        createdAt: FieldValue.serverTimestamp()
      });
      tx.set(transactionRef, {
        productId,
        transactionId,
        creditsGranted: validation.creditsToGrant,
        remainingCredits,
        createdAt: FieldValue.serverTimestamp()
      });
    });

    const result = {
      creditedAmount: validation.creditsToGrant,
      remainingCredits
    };

    await idemRef.set({ ...result, createdAt: FieldValue.serverTimestamp() });
    return result;
  } catch (err) {
    throw mapError(err);
  }
});

export const generateShareAsset = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const readingId = String(request.data?.readingId ?? '');
    if (!readingId) {
      throw new HttpsError('invalid-argument', 'INVALID_READING_ID');
    }

    const readingRef = db.collection('users').doc(uid).collection('readings').doc(readingId);
    const readingSnap = await readingRef.get();
    if (!readingSnap.exists) {
      throw new HttpsError('not-found', 'READING_NOT_FOUND');
    }

    const reading = readingSnap.data() as { aiResponse?: string };
    const shareDeepLink = buildShareDeepLink(readingId);
    const imageBuffer = renderShareImage({
      title: 'Share My Destiny',
      excerpt: (reading.aiResponse ?? '').slice(0, 220),
      footer: 'tarotai.app'
    });

    const path = `share/${uid}/${readingId}.png`;
    const file = storage.bucket().file(path);
    await file.save(imageBuffer, { contentType: 'image/png', public: true });
    const shareImageUrl = `https://storage.googleapis.com/${storage.bucket().name}/${path}`;

    await readingRef.update({
      shareImageUrl,
      shareDeepLink,
      updatedAt: FieldValue.serverTimestamp()
    });

    return { shareImageUrl, shareDeepLink };
  } catch (err) {
    throw mapError(err);
  }
});

export const saveOnboardingProfile = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const name = String(request.data?.name ?? '').trim();
    const birthDate = String(request.data?.birthDate ?? '').trim();
    const occupation = request.data?.occupation ? String(request.data.occupation).trim() : null;

    const privacyAccepted = Boolean(request.data?.privacyAccepted);
    const termsAccepted = Boolean(request.data?.termsAccepted);
    const aiProcessingAccepted = Boolean(request.data?.aiProcessingAccepted);

    if (!name || !birthDate) {
      throw new HttpsError('invalid-argument', 'PROFILE_FIELDS_REQUIRED');
    }
    if (!privacyAccepted || !termsAccepted || !aiProcessingAccepted) {
      throw new HttpsError('failed-precondition', 'CONSENT_REQUIRED');
    }

    const userRef = db.collection('users').doc(uid);
    await userRef.set(
      {
        profile: {
          name,
          birthDate,
          birthTime: request.data?.birthTime ? String(request.data.birthTime) : null,
          birthCity: request.data?.birthCity ? String(request.data.birthCity) : null,
          ...(occupation ? { occupation } : {})
        },
        consents: {
          privacyAcceptedAt: FieldValue.serverTimestamp(),
          termsAcceptedAt: FieldValue.serverTimestamp(),
          aiProcessingConsentAt: FieldValue.serverTimestamp(),
          consentVersion
        },
        isProfileComplete: true,
        settings: {
          lang: resolveLanguage(request.data?.lang),
          selectedPersonaId: String(request.data?.selectedPersonaId ?? defaultPersonaId)
        },
        updatedAt: FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    return { ok: true };
  } catch (err) {
    throw mapError(err);
  }
});

export const synthesizeReadingAudio = onDocumentUpdated(
  'users/{uid}/readings/{readingId}',
  async (event) => {
    const uid = event.params.uid;
    const readingId = event.params.readingId;
    const before = event.data?.before.data() as { status?: string } | undefined;
    const after = event.data?.after.data() as
      | { status?: string; audioUrl?: string; aiResponse?: string; lang?: string; audioStatus?: string }
      | undefined;

    if (!after) return;
    const transitionedToText = before?.status !== 'succeeded_text' && after.status === 'succeeded_text';
    if (!transitionedToText || !after.aiResponse || after.audioUrl) return;

    const readingRef = db.collection('users').doc(uid).collection('readings').doc(readingId);
    await readingRef.update({
      audioStatus: 'processing',
      updatedAt: FieldValue.serverTimestamp()
    });

    try {
      const audioBuffer = await synthesizeSpeech({
        text: after.aiResponse,
        lang: resolveLanguage(after.lang)
      });

      const path = `audio/${uid}/${readingId}.mp3`;
      const file = storage.bucket().file(path);
      await file.save(audioBuffer, { contentType: 'audio/mpeg', public: true });
      const audioUrl = `https://storage.googleapis.com/${storage.bucket().name}/${path}`;

      await readingRef.update({
        audioUrl,
        audioStatus: 'ready',
        status: 'succeeded_audio',
        updatedAt: FieldValue.serverTimestamp()
      });

      const userSnap = await db.collection('users').doc(uid).get();
      const user = userSnap.data() as UserDoc | undefined;
      await sendAudioReadyNotification({
        uid,
        readingId,
        lang: resolveLanguage(user?.settings?.lang)
      });
    } catch {
      await readingRef.update({
        audioStatus: 'failed',
        updatedAt: FieldValue.serverTimestamp()
      });
    }
  }
);

export const restoreIosPurchases = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const purchases = Array.isArray(request.data?.purchases) ? request.data.purchases : [];
    if (purchases.length === 0) {
      throw new HttpsError('invalid-argument', 'PURCHASES_REQUIRED');
    }

    let totalRestored = 0;
    let remainingCredits = 0;
    for (const item of purchases) {
      const transactionId = String(item?.transactionId ?? '');
      const productId = String(item?.productId ?? '');
      const receiptData = String(item?.receiptData ?? '');
      if (!transactionId || !productId || !receiptData) {
        continue;
      }

      const userRef = db.collection('users').doc(uid);
      const transactionRef = userRef.collection('iap_transactions').doc(transactionId);
      const existing = await transactionRef.get();
      if (existing.exists) {
        remainingCredits = Number((existing.data() as { remainingCredits?: number }).remainingCredits ?? 0);
        continue;
      }

      const validation = await validateAppleReceipt({ transactionId, productId, receiptData });
      if (!validation.isValid || validation.creditsToGrant <= 0) {
        continue;
      }

      await db.runTransaction(async (tx) => {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) return;
        const user = userSnap.data() as UserDoc;
        remainingCredits = Number(user.wallet.credits ?? 0) + validation.creditsToGrant;

        tx.update(userRef, {
          'wallet.credits': remainingCredits,
          updatedAt: FieldValue.serverTimestamp()
        });
        tx.set(userRef.collection('credit_ledger').doc(), {
          type: 'credit',
          amount: validation.creditsToGrant,
          reason: 'ios_restore',
          productId,
          transactionId,
          createdAt: FieldValue.serverTimestamp()
        });
        tx.set(transactionRef, {
          productId,
          transactionId,
          creditsGranted: validation.creditsToGrant,
          remainingCredits,
          createdAt: FieldValue.serverTimestamp()
        });
      });

      totalRestored += validation.creditsToGrant;
    }

    return {
      restoredCredits: totalRestored,
      remainingCredits
    };
  } catch (err) {
    throw mapError(err);
  }
});

export const sendDailyCardNudges = onSchedule(
  {
    schedule: 'every day 08:00',
    timeZone: process.env.DAILY_NUDGE_TIMEZONE ?? 'Europe/Istanbul'
  },
  async () => {
    const usersSnap = await db.collection('users').where('isProfileComplete', '==', true).limit(500).get();
    for (const userDoc of usersSnap.docs) {
      const user = userDoc.data() as UserDoc;
      if (user.settings?.notificationsEnabled === false) continue;
      const birthDate = resolveUserBirthDate(user);
      if (!birthDate) continue;

      await sendDailyNudge({
        uid: userDoc.id,
        lang: resolveLanguage(user.settings?.lang),
        zodiac: zodiacFromBirthDate(birthDate),
        deepLink: process.env.DAILY_NUDGE_DEEP_LINK ?? 'https://tarotai.app/daily'
      });
    }
  }
);

export const sendTestDailyNudge = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const userSnap = await db.collection('users').doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'USER_NOT_FOUND');
    }

    const user = userSnap.data() as UserDoc;
    const birthDate = resolveUserBirthDate(user);
    if (!birthDate) {
      throw new HttpsError('failed-precondition', 'BIRTH_DATE_REQUIRED');
    }

    const tokenCount = (await getUserFcmTokens(uid)).length;
    if (tokenCount === 0) {
      throw new HttpsError('failed-precondition', 'FCM_TOKEN_MISSING');
    }

    const zodiac = zodiacFromBirthDate(birthDate);
    const sendResult = await sendDailyNudge({
      uid,
      lang: resolveLanguage(user.settings?.lang),
      zodiac,
      deepLink: process.env.DAILY_NUDGE_DEEP_LINK ?? 'https://tarotai.app/daily'
    });

    logger.info('sendTestDailyNudge result', {
      uid,
      zodiac,
      sendResult
    });

    return {
      ok: true,
      tokenCount,
      sendResult,
      zodiac,
      sentAt: new Date().toISOString()
    };
  } catch (err) {
    throw mapError(err);
  }
});

export const backfillMissingUserWallets = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: process.env.DAILY_NUDGE_TIMEZONE ?? 'Europe/Istanbul'
  },
  async () => {
    let scanned = 0;
    let updated = 0;
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | null = null;

    while (true) {
      let query = db
        .collection('users')
        .orderBy(FieldPath.documentId())
        .limit(400);
      if (cursor) {
        query = query.startAfter(cursor);
      }

      const snap = await query.get();
      if (snap.empty) break;

      const batch = db.batch();
      let writesInBatch = 0;

      for (const doc of snap.docs) {
        scanned += 1;
        const data = doc.data() as Partial<UserDoc> & { wallet?: Record<string, unknown> };
        const walletRaw = data.wallet;
        const updates: Record<string, unknown> = {};

        if (!walletRaw || typeof walletRaw !== 'object') {
          updates.wallet = {
            credits: initialFreeCredits,
            isFirstFreeUsed: false
          };
        } else {
          if (typeof walletRaw.credits !== 'number') {
            updates['wallet.credits'] = initialFreeCredits;
          }
          if (typeof walletRaw.isFirstFreeUsed !== 'boolean') {
            updates['wallet.isFirstFreeUsed'] = false;
          }
        }

        if (Object.keys(updates).length > 0) {
          updates.updatedAt = FieldValue.serverTimestamp();
          batch.set(doc.ref, updates, { merge: true });
          writesInBatch += 1;
          updated += 1;
        }
      }

      if (writesInBatch > 0) {
        await batch.commit();
      }
      cursor = snap.docs[snap.docs.length - 1];
    }

    logger.info('backfillMissingUserWallets completed', {
      scanned,
      updated
    });
  }
);
