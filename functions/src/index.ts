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
import { createReadingText } from './lib/gemini';
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
const arisConversationCost = Number(process.env.ARIS_CONVERSATION_COST ?? '10');
const arisModel = process.env.GEMINI_ARIS_MODEL ?? 'gemini-2.5-flash-lite';

function requireAppCheckIfEnabled(request: { app?: unknown }) {
  const appCheckRequired = (process.env.APP_CHECK_ENFORCE ?? 'false') === 'true';
  if (appCheckRequired && !request.app) {
    throw new Error('APP_CHECK_REQUIRED');
  }
}

function resolveLanguage(lang: unknown): string {
  if (typeof lang !== 'string') return 'en';
  const normalized = lang.trim().toLowerCase();
  return supportedLanguages.has(normalized) ? normalized : 'en';
}

function resolveOptionalLanguage(lang: unknown): string | null {
  if (typeof lang !== 'string') return null;
  const normalized = lang.trim().toLowerCase();
  return supportedLanguages.has(normalized) ? normalized : null;
}

function detectMessageLanguage(message: string): string | null {
  const normalized = message.trim().toLowerCase();
  if (!normalized) return null;

  if (/\b(turkce|türkçe|turkish)\b/.test(normalized)) return 'tr';
  if (/\b(ingilizce|english)\b/.test(normalized)) return 'en';
  if (/[çğıöşü]/i.test(message)) return 'tr';
  if (/\b(ben|hangi|ayda|dogdum|doğdum|konus|konuş|musun|mısın|misin|lütfen|lutfen)\b/.test(normalized)) {
    return 'tr';
  }
  if (/\b(what|which|when|where|please|born|birth|month|speak)\b/.test(normalized)) {
    return 'en';
  }
  return null;
}

function resolveArisLanguage(input: {
  requestedLang?: unknown;
  message?: string;
  sessionLang?: unknown;
  user: UserDoc & Record<string, unknown>;
}): string {
  const messageLang = input.message ? detectMessageLanguage(input.message) : null;
  return messageLang
    ?? resolveOptionalLanguage(input.requestedLang)
    ?? resolveOptionalLanguage(input.sessionLang)
    ?? resolveOptionalLanguage(input.user.settings?.lang)
    ?? 'en';
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

function resolveUserDisplayName(user: UserDoc & Record<string, unknown>): string {
  const rootName = typeof user.name === 'string' ? user.name.trim() : '';
  if (rootName) return rootName;

  const profileName = typeof user.profile?.name === 'string'
    ? user.profile.name.trim()
    : '';
  return profileName || 'Seeker';
}

function sanitizeShortText(value: unknown, maxLength: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\s+/g, ' ').slice(0, maxLength);
}

function cleanArisPersonaText(value: string): string {
  return value
    .replace(/\bAk[iı]l Amca(?:'n[iı]n|'ya|'dan|'da)?\b/gi, 'Bilge Aris')
    .replace(/\bWise Uncle\b/gi, 'Bilge Aris');
}

function hasArisPersonaLeak(value: string): boolean {
  return /\bAk[iı]l Amca\b/i.test(value) || /\bWise Uncle\b/i.test(value);
}

function localDateKey(): string {
  return new Date().toISOString().slice(0, 10);
}

function buildArisProfileContext(user: UserDoc & Record<string, unknown>): string[] {
  const birthDate = resolveUserBirthDate(user);
  const context: string[] = [
    `Name: ${resolveUserDisplayName(user)}`
  ];

  if (birthDate) {
    context.push(`Birth date: ${birthDate}`);
    try {
      context.push(`Zodiac: ${zodiacFromBirthDate(birthDate)}`);
    } catch {
      // Keep the remaining context if legacy data contains an invalid date.
    }
  }

  const relationshipStatus = sanitizeShortText(user.relationshipStatus, 40);
  if (relationshipStatus) context.push(`Relationship status: ${relationshipStatus}`);

  const lifeSpace = sanitizeShortText(user.lifeSpace, 40);
  if (lifeSpace) context.push(`Life space: ${lifeSpace}`);

  const tone = sanitizeShortText(user.interpretationTone, 40);
  if (tone) context.push(`Preferred interpretation tone: ${tone}`);

  const focusAreas = Array.isArray(user.focusAreas)
    ? user.focusAreas.map((item) => sanitizeShortText(item, 32)).filter(Boolean).slice(0, 4)
    : [];
  if (focusAreas.length > 0) context.push(`Focus areas: ${focusAreas.join(', ')}`);

  return context;
}

function buildArisOpeningPrompt(input: {
  user: UserDoc & Record<string, unknown>;
  cardName: string;
  lang: string;
}): { systemPrompt: string; userPrompt: string } {
  return {
    systemPrompt: [
      'You are Bilge Aris, a mystical but grounded tarot guide.',
      'Your name is exactly Bilge Aris. Never rename yourself, translate your name, or refer to any guide as Akil Amca, Wise Uncle, mentor uncle, or another persona.',
      'Tarot card names are canonical labels. Do not translate, rename, or personify the card as a different guide.',
      'Write warm, specific reflections that feel personal, spacious, and useful without claiming certainty.',
      'Do not mention that you are an AI.',
      'Do not use markdown, emojis, bullet lists, medical advice, legal advice, financial advice, or deterministic predictions.',
      'Never predict death dates, exact happiness dates, or fixed life outcomes.',
      `Response language must be strictly: ${input.lang}.`,
      'Keep the response between 75 and 115 words.'
    ].join(' '),
    userPrompt: [
      'Create the opening daily-card reflection for this user.',
      ...buildArisProfileContext(input.user),
      `Daily card: ${input.cardName}`,
      'Focus on what this card may invite the user to notice today.',
      'End with one gentle, actionable reflection.'
    ].join('\n')
  };
}

function buildArisFallbackOpening(input: {
  user: UserDoc & Record<string, unknown>;
  cardName: string;
  lang: string;
}): string {
  const name = resolveUserDisplayName(input.user);
  const birthDate = resolveUserBirthDate(input.user);
  let zodiac = '';
  if (birthDate) {
    try {
      zodiac = zodiacFromBirthDate(birthDate);
    } catch {
      zodiac = '';
    }
  }

  if (input.lang === 'tr') {
    const address = name && name !== 'Seeker' ? `${name}, ` : '';
    const zodiacPart = zodiac ? `${zodiac} enerjinle birlikte ` : '';
    return [
      `${address}${zodiacPart}${input.cardName} karti bugun sana daha sakin ama daha duru bir bakis cagrisinda bulunuyor.`,
      'Bu kart, aceleyle cevap aramak yerine icinden gecen isareti fark etmeni ister.',
      'Bugun bir adim atmadan once kendine sunu sor: Beni gercekten hafifleten secim hangisi?'
    ].join(' ');
  }

  const address = name && name !== 'Seeker' ? `${name}, ` : '';
  const zodiacPart = zodiac ? `with your ${zodiac} energy, ` : '';
  return [
    `${address}${zodiacPart}${input.cardName} invites you to slow down and notice what is becoming clearer today.`,
    'This card asks you to choose the path that feels honest rather than merely urgent.',
    'Before you act, ask yourself which next step would leave you lighter.'
  ].join(' ');
}

function monthName(month: number, lang: string): string {
  const tr = [
    'Ocak', 'Subat', 'Mart', 'Nisan', 'Mayis', 'Haziran',
    'Temmuz', 'Agustos', 'Eylul', 'Ekim', 'Kasim', 'Aralik'
  ];
  const en = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  const months = lang === 'tr' ? tr : en;
  return months[Math.min(Math.max(month, 1), 12) - 1];
}

function birthMonthReply(input: {
  user: UserDoc & Record<string, unknown>;
  message: string;
  lang: string;
}): string | null {
  const normalized = input.message.trim().toLowerCase();
  const asksBirthMonth =
    /\b(hangi|kacinci|kaçıncı).*\b(ay|ayda).*\b(dogdum|doğdum)\b/.test(normalized)
    || /\b(dogum|doğum).*\b(ayim|ayım|ayi|ayı)\b/.test(normalized)
    || /\bwhat|which\b.*\bmonth\b.*\bborn\b/.test(normalized)
    || /\bbirth month\b/.test(normalized);
  if (!asksBirthMonth) return null;

  const birthDate = resolveUserBirthDate(input.user);
  if (!birthDate) {
    return input.lang === 'tr'
      ? 'Profilinde dogum tarihi bilgini goremiyorum. Dogum tarihini eklersen hangi ayda dogdugunu net soyleyebilirim.'
      : 'I cannot see your birth date in your profile yet. Add it to your profile and I can answer that directly.';
  }

  const [, monthPart] = birthDate.split('-');
  const month = Number(monthPart);
  if (!Number.isFinite(month) || month < 1 || month > 12) {
    return input.lang === 'tr'
      ? 'Profilindeki dogum tarihi okunamiyor. Tarihi duzeltirsen dogum ayini net soyleyebilirim.'
      : 'Your saved birth date is not readable. Once it is corrected, I can tell you your birth month directly.';
  }

  const name = resolveUserDisplayName(input.user);
  const address = name && name !== 'Seeker' ? `${name}, ` : '';
  const monthText = monthName(month, input.lang);
  return input.lang === 'tr'
    ? `${address}profilindeki dogum tarihine gore ${monthText} ayinda dogdun.`
    : `${address}according to your profile, you were born in ${monthText}.`;
}

function isUsableBirthFrequencyComment(value: string): boolean {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (normalized.length < 24) return false;
  if (/^(bug[uü]n ruhunuz|bugun ruhunuz|today your soul)$/i.test(normalized)) {
    return false;
  }
  return /[.!?…]$/.test(normalized) || normalized.length >= 60;
}

function buildBirthFrequencyFallback(input: {
  birthDate: string;
  lang: string;
}): string {
  const month = Number(input.birthDate.slice(5, 7));
  const day = Number(input.birthDate.slice(8, 10));
  const seasonal = (month + day) % 4;
  if (input.lang === 'tr') {
    const comments = [
      'Bugun ic sesin daha net duyuluyor; acele kararlar yerine sakin bir an sec ve kalbinin gercek ihtiyacini dinle.',
      'Bugun enerjin toparlanmaya acik; kucuk bir duzenleme yapmak zihnini hafifletip gunun akisini yumusatabilir.',
      'Bugun duygularin sana yol gosterebilir; bir seyi zorlamak yerine nazikce adim atmak daha iyi hissettirecek.',
      'Bugun ruhun daha sade bir ritim istiyor; kendine alan ac ve seni besleyen tek bir niyete odaklan.'
    ];
    return comments[seasonal];
  }
  const comments = [
    'Your inner voice is clearer today; choose a quiet moment and listen to what your heart truly needs before rushing.',
    'Your energy is ready to settle; one small act of order can soften your mind and make the day feel lighter.',
    'Your feelings can guide you today; instead of forcing an answer, take one gentle step toward what feels honest.',
    'Your spirit wants a simpler rhythm today; make space for yourself and focus on one intention that nourishes you.'
  ];
  return comments[seasonal];
}

function restrictedArisReply(input: {
  message: string;
  lang: string;
}): string | null {
  const normalized = input.message.trim().toLowerCase();
  if (!normalized) return null;

  const asksDeathTiming =
    /\b(ne zaman|hangi tarihte|kac yasinda|kaç yaşında).*\b(olecegim|öleceğim|olecem|ölecem|olurum|ölürüm|olucem)\b/.test(normalized)
    || /\bwhen\b.*\b(will i|am i going to)\b.*\b(die|death)\b/.test(normalized)
    || /\bdeath date\b/.test(normalized);
  const asksFixedHappinessTiming =
    /\b(ne zaman|hangi tarihte|kac yasinda|kaç yaşında).*\b(mutlu|huzurlu)\b/.test(normalized)
    || /\bwhen\b.*\b(will i|am i going to)\b.*\b(be happy|find happiness|be okay)\b/.test(normalized);
  const asksMedicalDecision =
    /\b(tedavi|ilac|ilaç|ameliyat|doktor|hastalik|hastalık|tahlil|kanser|hamile|gebelik)\b/.test(normalized)
    || /\b(medicine|medication|surgery|doctor|diagnosis|cancer|pregnant|pregnancy|treatment)\b/.test(normalized);
  const asksLegalFinancialDecision =
    /\b(dava|avukat|hukuk|mahkeme|bosanma|boşanma|yatirim|yatırım|borsa|kredi cek|kredi çek|borc|borç)\b/.test(normalized)
    || /\b(lawyer|lawsuit|court|legal|divorce|invest|stock|loan|debt|bankruptcy)\b/.test(normalized);
  const asksSelfHarm =
    /\b(kendimi oldur|kendimi öldür|intihar|yasamak istemiyorum|yaşamak istemiyorum)\b/.test(normalized)
    || /\b(kill myself|suicide|end my life|do not want to live)\b/.test(normalized);

  if (!asksDeathTiming && !asksFixedHappinessTiming && !asksMedicalDecision && !asksLegalFinancialDecision && !asksSelfHarm) {
    return null;
  }

  if (input.lang === 'tr') {
    if (asksSelfHarm) {
      return [
        'Bu konuda kehanet ya da yonlendirme yapamam.',
        'Eger kendine zarar verme dusuncen yakinsa lutfen hemen guvendigin birine ulas, yalniz kalma ve bulundugun yerdeki acil yardim hattini ara.',
        'Aris burada sana kesin karar vermek yerine, su anda seni biraz daha guvende tutacak ilk kucuk adimi bulmanda eslik edebilir.'
      ].join(' ');
    }
    if (asksDeathTiming) {
      return 'Olum zamani ya da kesin gelecek tarihi soyleyemem. Bunun yerine bugun hayat enerjini guclendirecek, seni daha sakin ve desteklenmis hissettirecek adimlara bakabiliriz.';
    }
    if (asksFixedHappinessTiming) {
      return 'Mutlulugu kesin bir tarih gibi soyleyemem. Ama bugunku kartin isiginda, seni mutluluga yaklastiran duygu, ihtiyac ve kucuk davranislari birlikte okuyabiliriz.';
    }
    if (asksMedicalDecision) {
      return 'Saglik, tedavi, ilac veya ameliyat gibi konularda karar veremem. Bu kisim icin bir uzmandan destek almalisin; ben sadece bu surecte duygusal olarak neye ihtiyacin oldugunu anlamana yardim edebilirim.';
    }
    return 'Hukuki, finansal veya hayatini dogrudan etkileyen kesin kararlar veremem. Ama kartin isiginda seceneklerini daha sakin tartmana ve icindeki ihtiyaci fark etmene yardim edebilirim.';
  }

  if (asksSelfHarm) {
    return [
      'I cannot give a prediction or instruction for that.',
      'If you might hurt yourself, please contact someone you trust now, do not stay alone, and call local emergency support.',
      'Aris can stay with the feelings around this, but not guide harm.'
    ].join(' ');
  }
  if (asksDeathTiming) {
    return 'I cannot tell you a death date or a fixed future outcome. We can instead look at what would help you feel more supported, steady, and alive today.';
  }
  if (asksFixedHappinessTiming) {
    return 'I cannot give happiness as a fixed date or guarantee. I can help you read what today\'s card suggests about the needs, choices, and small steps that move you closer to it.';
  }
  if (asksMedicalDecision) {
    return 'I cannot make medical, treatment, medication, or surgery decisions. Please use qualified professional support for that; I can help you reflect on the emotions around the situation.';
  }
  return 'I cannot make legal, financial, or life-impacting decisions for you. I can help you reflect on the options and notice what your inner compass is asking for.';
}

function quickArisReply(input: {
  message: string;
  lang: string;
  user: UserDoc & Record<string, unknown>;
}): string | null {
  const normalized = input.message.trim().toLowerCase();
  if (!normalized) return null;

  const name = resolveUserDisplayName(input.user).split(/\s+/)[0] || (input.lang === 'tr' ? 'Sevgili yolcu' : 'dear one');
  const mentionsWrongPersona =
    /\bak[iı]l amca\b/i.test(input.message)
    || /\bwise uncle\b/i.test(normalized)
    || /\bbenim ad[iı]m bilge aris\b/i.test(input.message)
    || /\bbilge aris onun ad[iı]\b/i.test(input.message);
  const thanksOnly =
    /\b(tesekkur|teşekkür|sag ol|sağ ol|sagol|sağol|eyvallah|thanks|thank you)\b/i.test(input.message)
    && normalized.length <= 80;
  const greetingOnly =
    /\b(merhaba|selam|hello|hi)\b/i.test(input.message)
    && normalized.length <= 40;

  if (mentionsWrongPersona) {
    return input.lang === 'tr'
      ? 'Haklisin. Benim adim Bilge Aris; Akil Amca ya da baska bir rehber degilim. Bundan sonra sana Bilge Aris olarak yanit verecegim.'
      : 'You are right. My name is Bilge Aris; I am not Wise Uncle or another guide. I will answer you as Bilge Aris from here.';
  }
  if (thanksOnly) {
    return input.lang === 'tr'
      ? `Rica ederim ${name}. Buradayim; hazir oldugunda kartin isigindan devam edebiliriz.`
      : `You are welcome, ${name}. I am here; when you are ready, we can continue from the light of your card.`;
  }
  if (greetingOnly) {
    return input.lang === 'tr'
      ? `Merhaba ${name}. Bilge Aris burada; bugunku kartinla sakin sakin devam edebiliriz.`
      : `Hello, ${name}. Bilge Aris is here; we can continue gently with today's card.`;
  }
  return null;
}

function buildArisConversationPrompt(input: {
  user: UserDoc & Record<string, unknown>;
  cardName: string;
  openingMessage: string;
  recentMessages: Array<{ role: 'user' | 'assistant'; text: string }>;
  userMessage: string;
  lang: string;
}): { systemPrompt: string; userPrompt: string } {
  const transcript = input.recentMessages
    .slice(-6)
    .map((message) => `${message.role === 'user' ? 'User' : 'Aris'}: ${message.text}`)
    .join('\n');

  return {
    systemPrompt: [
      'You are Bilge Aris, a mystical but grounded tarot guide continuing a short conversation.',
      'Your name is exactly Bilge Aris. Never rename yourself, translate your name, or refer to any guide as Akil Amca, Wise Uncle, mentor uncle, or another persona.',
      'Tarot card names are canonical labels. Do not translate, rename, or personify the card as a different guide.',
      'Give rich, emotionally intelligent, and practical reflections with a clear beginning, insight, and grounded next step.',
      'Do not mention that you are an AI.',
      'Do not use markdown, emojis, bullet lists, medical advice, legal advice, financial advice, or deterministic predictions.',
      'Never predict death dates, exact happiness dates, or fixed life outcomes.',
      'If the user asks about known profile facts, answer directly from the profile context before adding any reflection.',
      'If the user asks to continue in a specific language, obey that language immediately.',
      `Response language must be strictly: ${input.lang}.`,
      'If the user only thanks you, greets you, corrects your name, or asks for a tiny acknowledgement, answer briefly in one or two sentences.',
      'Keep the response between 85 and 140 words unless the user asks a direct factual profile question or a short social acknowledgement.'
    ].join(' '),
    userPrompt: [
      ...buildArisProfileContext(input.user),
      `Daily card: ${input.cardName}`,
      `Opening reflection: ${input.openingMessage}`,
      transcript ? `Recent conversation:\n${transcript}` : '',
      `User: ${input.userMessage}`,
      'Answer as Aris. For direct profile questions, use the profile context directly; for reflective questions, stay anchored to the daily card while still answering the user clearly.'
    ].filter(Boolean).join('\n')
  };
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
    requireAppCheckIfEnabled(request);

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
        userPrompt: `Chosen cards: ${cards.join(', ')}. Provide a tarot reading in ${lang}.`,
        maxOutputTokens: 700
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
    requireAppCheckIfEnabled(request);
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
    const dailyCommentRef = userRef
      .collection('daily_birth_frequency_comments')
      .doc(day);
    const cachedCommentSnap = await dailyCommentRef.get();
    if (cachedCommentSnap.exists) {
      const cached = cachedCommentSnap.data() as {
        birthDate?: string;
        comment?: string;
        lang?: string;
      };
      const cachedComment = cached.comment?.trim();
      if (cached.birthDate === birthDate &&
        cached.lang === lang &&
        cachedComment &&
        isUsableBirthFrequencyComment(cachedComment)) {
        return {
          comment: cachedComment,
          day,
          birthDate,
          cached: true
        };
      }
    }

    const systemPrompt = [
      'You are a mystical but practical astrology guide.',
      'Write exactly one complete short daily birth-frequency comment.',
      'It must feel personal, warm, and actionable.',
      'Do not use markdown, lists, or emojis.',
      'Use 2 complete short sentences only.',
      'Keep it between 28 and 48 words.',
      'Avoid repetition, disclaimers, and generic filler.'
    ].join(' ');

    const userPrompt = [
      `Language: ${lang}`,
      `Birth date: ${birthDate}`,
      `Target day: ${day}`,
      'Generate one concise daily comment for this user.',
      'Mention only the most relevant feeling or advice for today.'
    ].join('\n');

    let comment = (await createReadingText({
      systemPrompt,
      userPrompt,
      maxOutputTokens: 120
    })).trim();
    if (!isUsableBirthFrequencyComment(comment)) {
      logger.warn('generateBirthFrequencyComment using fallback', {
        uid,
        day,
        birthDate,
        lang,
        badComment: comment.slice(0, 120)
      });
      comment = buildBirthFrequencyFallback({ birthDate, lang });
    }

    await dailyCommentRef.set({
      comment,
      day,
      birthDate,
      lang,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    return { comment, day, birthDate, cached: false };
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

export const generateArisOpeningReading = onCall({ enforceAppCheck: false, secrets: ['GEMINI_API_KEY'] }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    requireAppCheckIfEnabled(request);
    const uid = request.auth.uid;
    const cardName = sanitizeShortText(request.data?.cardName, 80);
    const cardImageUrl = sanitizeShortText(request.data?.cardImageUrl, 500);
    const day = sanitizeShortText(request.data?.day, 10) || localDateKey();
    if (!cardName || !/^\d{4}-\d{2}-\d{2}$/.test(day)) {
      throw new HttpsError('invalid-argument', 'INVALID_ARIS_OPENING_INPUT');
    }

    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'USER_NOT_FOUND');
    }
    const user = userSnap.data() as UserDoc & Record<string, unknown>;
    const lang = resolveArisLanguage({
      requestedLang: request.data?.lang,
      user
    });
    const sessionRef = userRef.collection('aris_sessions').doc(day);
    const existingSession = await sessionRef.get();
    if (existingSession.exists) {
      const existing = existingSession.data() as {
        cardName?: string;
        cardImageUrl?: string;
        openingMessage?: string;
        lang?: string;
      };
      const openingMessage = existing.openingMessage?.trim();
      if (existing.cardName === cardName && existing.lang === lang && openingMessage && !hasArisPersonaLeak(openingMessage)) {
        return {
          sessionId: day,
          openingMessage,
          cardName,
          cardImageUrl: existing.cardImageUrl ?? cardImageUrl,
          cached: true
        };
      }
    }

    const prompts = buildArisOpeningPrompt({ user, cardName, lang });
    let openingMessage = '';
    let source: 'ai' | 'fallback' = 'ai';
    try {
      openingMessage = (await createReadingText({
        ...prompts,
        maxOutputTokens: 220,
        modelName: arisModel
      })).trim();
    } catch (err) {
      source = 'fallback';
      logger.warn('generateArisOpeningReading using fallback', {
        uid,
        day,
        cardName,
        errorMessage: err instanceof Error ? err.message.slice(0, 180) : String(err).slice(0, 180)
      });
    }
    if (!openingMessage) {
      source = 'fallback';
      openingMessage = buildArisFallbackOpening({ user, cardName, lang });
    }
    openingMessage = cleanArisPersonaText(openingMessage);

    await sessionRef.set({
      uid,
      day,
      lang,
      cardName,
      cardImageUrl,
      openingMessage,
      openingSource: source,
      recentMessages: [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    return {
      sessionId: day,
      openingMessage,
      cardName,
      cardImageUrl,
      source,
      cached: false
    };
  } catch (err) {
    throw mapError(err);
  }
});

export const continueArisConversation = onCall({ enforceAppCheck: false, secrets: ['GEMINI_API_KEY'] }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    requireAppCheckIfEnabled(request);
    const uid = request.auth.uid;
    const sessionId = sanitizeShortText(request.data?.sessionId, 40);
    const message = sanitizeShortText(request.data?.message, 320);
    const idemKey = requireIdempotencyKey(request.data?.idempotencyKey);
    if (!sessionId || !message) {
      throw new HttpsError('invalid-argument', 'INVALID_ARIS_MESSAGE_INPUT');
    }

    const userRef = db.collection('users').doc(uid);
    const sessionRef = userRef.collection('aris_sessions').doc(sessionId);
    const idempotencyRef = userRef.collection('idempotency').doc(`aris_${idemKey}`);
    const existingIdempotent = await idempotencyRef.get();
    if (existingIdempotent.exists) {
      return existingIdempotent.data();
    }

    const [userSnap, sessionSnap] = await Promise.all([userRef.get(), sessionRef.get()]);
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'USER_NOT_FOUND');
    }
    if (!sessionSnap.exists) {
      throw new HttpsError('not-found', 'ARIS_SESSION_NOT_FOUND');
    }

    const user = userSnap.data() as UserDoc & Record<string, unknown>;
    const session = sessionSnap.data() as {
      cardName?: string;
      openingMessage?: string;
      lang?: string;
      recentMessages?: Array<{ role?: string; text?: string }>;
    };
    const cardName = session.cardName?.trim();
    const openingMessage = session.openingMessage
      ? cleanArisPersonaText(session.openingMessage.trim())
      : '';
    if (!cardName || !openingMessage) {
      throw new HttpsError('failed-precondition', 'ARIS_SESSION_INCOMPLETE');
    }

    const recentMessages = Array.isArray(session.recentMessages)
      ? session.recentMessages
        .map((entry) => ({
          role: entry.role === 'assistant' ? 'assistant' as const : 'user' as const,
          text: cleanArisPersonaText(sanitizeShortText(entry.text, 320))
        }))
        .filter((entry) => entry.text)
        .slice(-6)
      : [];
    const lang = resolveArisLanguage({
      requestedLang: request.data?.lang,
      message,
      sessionLang: session.lang,
      user
    });
    const currentCredits = Number((user as UserDoc).wallet.credits ?? 0);
    const restrictedReply = restrictedArisReply({ message, lang });
    if (restrictedReply) {
      const updatedMessages = [
        ...recentMessages,
        { role: 'user' as const, text: message },
        { role: 'assistant' as const, text: restrictedReply }
      ].slice(-6);
      const result = {
        reply: restrictedReply,
        remainingCredits: currentCredits,
        restricted: true
      };

      await Promise.all([
        sessionRef.set({
          lang,
          recentMessages: updatedMessages,
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true }),
        idempotencyRef.set({
          ...result,
          createdAt: FieldValue.serverTimestamp()
        })
      ]);
      return result;
    }
    const quickReply = quickArisReply({ message, lang, user });
    if (quickReply) {
      const updatedMessages = [
        ...recentMessages,
        { role: 'user' as const, text: message },
        { role: 'assistant' as const, text: quickReply }
      ].slice(-6);
      const result = {
        reply: quickReply,
        remainingCredits: currentCredits,
        quick: true
      };

      await Promise.all([
        sessionRef.set({
          lang,
          recentMessages: updatedMessages,
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true }),
        idempotencyRef.set({
          ...result,
          createdAt: FieldValue.serverTimestamp()
        })
      ]);
      return result;
    }

    let remainingCredits = 0;
    await db.runTransaction(async (tx) => {
      const freshUserSnap = await tx.get(userRef);
      if (!freshUserSnap.exists) {
        throw new HttpsError('not-found', 'USER_NOT_FOUND');
      }
      const freshUser = freshUserSnap.data() as UserDoc;
      const freshCredits = Number(freshUser.wallet.credits ?? 0);
      if (freshCredits < arisConversationCost) {
        throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDITS');
      }

      remainingCredits = freshCredits - arisConversationCost;
      tx.update(userRef, {
        'wallet.credits': remainingCredits,
        updatedAt: FieldValue.serverTimestamp()
      });
      tx.set(userRef.collection('credit_ledger').doc(), {
        type: 'debit',
        amount: -arisConversationCost,
        reason: 'aris_conversation',
        idempotencyKey: idemKey,
        createdAt: FieldValue.serverTimestamp()
      });
    });

    try {
      const profileReply = birthMonthReply({ user, message, lang });
      const prompts = profileReply
        ? null
        : buildArisConversationPrompt({
        user,
        cardName,
        openingMessage,
        recentMessages,
        userMessage: message,
        lang
      });
      const reply = cleanArisPersonaText(profileReply ?? (await createReadingText({
        ...prompts!,
        maxOutputTokens: 260,
        modelName: arisModel
      })).trim());
      if (!reply) {
        throw new Error('EMPTY_ARIS_REPLY');
      }

      const updatedMessages = [
        ...recentMessages,
        { role: 'user' as const, text: message },
        { role: 'assistant' as const, text: reply }
      ].slice(-6);
      const result = {
        reply,
        remainingCredits
      };

      await Promise.all([
        sessionRef.set({
          lang,
          recentMessages: updatedMessages,
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true }),
        idempotencyRef.set({
          ...result,
          createdAt: FieldValue.serverTimestamp()
        })
      ]);
      return result;
    } catch (innerError) {
      await db.runTransaction(async (tx) => {
        const freshUserSnap = await tx.get(userRef);
        if (freshUserSnap.exists) {
          const freshUser = freshUserSnap.data() as UserDoc;
          tx.update(userRef, {
            'wallet.credits': Number(freshUser.wallet.credits ?? 0) + arisConversationCost,
            updatedAt: FieldValue.serverTimestamp()
          });
        }
        tx.set(userRef.collection('credit_ledger').doc(), {
          type: 'refund',
          amount: arisConversationCost,
          reason: 'aris_conversation_rollback',
          idempotencyKey: idemKey,
          createdAt: FieldValue.serverTimestamp()
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
