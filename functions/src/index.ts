import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as functionsV1 from 'firebase-functions/v1';
import { mapError } from './lib/errors';
import { buildSystemPrompt } from './lib/context-builder';
import { createReadingText } from './lib/openai';
import { renderShareImage } from './lib/share-image';
import { buildShareDeepLink } from './lib/deep-link';
import { validateAppleReceipt } from './lib/purchase';
import { requireIdempotencyKey } from './lib/idempotency';
import { AIPersonaDoc, UserDoc } from './lib/types';
import { synthesizeSpeech } from './lib/audio';
import { sendAudioReadyNotification, sendDailyNudge } from './lib/fcm';
import { zodiacFromBirthDate } from './lib/zodiac';

initializeApp();

const db = getFirestore();
const storage = getStorage();

const consentVersion = process.env.CONSENT_VERSION ?? 'v1';
const initialFreeCredits = Number(process.env.INITIAL_FREE_CREDITS ?? '1');
const supportedLanguages = new Set(['tr', 'en', 'de', 'es', 'fr', 'it', 'pt']);
const defaultPersonaId = process.env.DEFAULT_PERSONA_ID ?? 'emilia';

function resolveLanguage(lang: unknown): string {
  if (typeof lang !== 'string') return 'en';
  const normalized = lang.trim().toLowerCase();
  return supportedLanguages.has(normalized) ? normalized : 'en';
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

export const generateTarotReading = onCall({ enforceAppCheck: false }, async (request) => {
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
      if (!user.isProfileComplete || !profile?.name || !profile.birthDate || !profile.occupation) {
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
    const occupation = String(request.data?.occupation ?? '').trim();

    const privacyAccepted = Boolean(request.data?.privacyAccepted);
    const termsAccepted = Boolean(request.data?.termsAccepted);
    const aiProcessingAccepted = Boolean(request.data?.aiProcessingAccepted);

    if (!name || !birthDate || !occupation) {
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
          occupation
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
      if (!user.profile?.birthDate) continue;

      await sendDailyNudge({
        uid: userDoc.id,
        lang: resolveLanguage(user.settings?.lang),
        zodiac: zodiacFromBirthDate(user.profile.birthDate),
        deepLink: process.env.DAILY_NUDGE_DEEP_LINK ?? 'https://tarotai.app/daily'
      });
    }
  }
);
