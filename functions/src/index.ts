import { config as loadEnv } from 'dotenv';
import { resolve } from 'node:path';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldPath, FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentDeleted, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as functionsV1 from 'firebase-functions/v1';
import * as logger from 'firebase-functions/logger';
import jwt from 'jsonwebtoken';

loadEnv({ path: resolve(__dirname, '../../.env') });

if (!process.env.GEMINI_API_KEY?.trim()) {
  logger.warn(
    'GEMINI_API_KEY is not set. Aris opening/chat will use card-based fallback text when Gemini is unavailable.'
  );
}

import { mapError } from './lib/errors';
import { buildSystemPrompt } from './lib/context-builder';
import { createReadingText } from './lib/gemini';
import { createCoffeeReadingWithVision } from './lib/coffee-reading';
import { renderShareImage } from './lib/share-image';
import { buildShareDeepLink } from './lib/deep-link';
import { validateAppleReceipt } from './lib/purchase';
import { requireIdempotencyKey } from './lib/idempotency';
import { checkAndBumpThrottle } from './lib/rate-limit';
import { AIPersonaDoc, UserDoc } from './lib/types';
import { synthesizeSpeech } from './lib/audio';
import { buildBirthFrequencyFallback } from './lib/birth-frequency';
import { sendAudioReadyNotification, sendNotificationToUser } from './lib/fcm';
import { zodiacFromBirthDate } from './lib/zodiac';
import { buildNotifVars, resolveUserLang } from './lib/notif-personalization';
import { pickNotification } from './notif-templates';
import {
  arisSpreadSystemRules,
  isOffTopicArisMessage,
  offTopicArisReply
} from './lib/aris-guardrails';
import { analyzePalmWithGemini } from './lib/palm-reading';

initializeApp();

const db = getFirestore();
const storage = getStorage();

const consentVersion = process.env.CONSENT_VERSION ?? 'v1';
const initialFreeCredits = Number(process.env.INITIAL_FREE_CREDITS ?? '1');
const supportedLanguages = new Set(['tr', 'en', 'de', 'es', 'fr', 'it', 'pt']);
const defaultPersonaId = process.env.DEFAULT_PERSONA_ID ?? 'emilia';
const homeCardDrawCost = Number(process.env.HOME_CARD_DRAW_COST ?? '5');
const arisConversationCost = Number(process.env.ARIS_CONVERSATION_COST ?? '10');
const coffeeReadingCost = Number(process.env.COFFEE_READING_COST ?? '20');
const arisModel = process.env.GEMINI_ARIS_MODEL ?? 'gemini-2.5-flash-lite';
const coffeeRequiredSteps = ['cupInside', 'saucer', 'cupSide'] as const;
const coffeeReservationTtlMs = 10 * 60 * 1000;
const coffeeRetentionMs = 7 * 24 * 60 * 60 * 1000;
const coffeeOrphanGraceMs = 24 * 60 * 60 * 1000;
const coffeeMaxImageBytes = 5 * 1024 * 1024;
const coffeeTenMinuteAttemptLimit = 3;
const coffeeDailyAttemptLimit = 10;
const readingThrottleWindowMs = 10 * 60 * 1000;
const readingWindowLimit = Number(process.env.READING_WINDOW_LIMIT ?? '5');
const readingDailyLimit = Number(process.env.READING_DAILY_LIMIT ?? '30');
const walletLowThreshold = 10;
const readingFollowupMs = 48 * 60 * 60 * 1000;
const unverifiedAccountTtlHours = Number(process.env.UNVERIFIED_ACCOUNT_TTL_HOURS ?? '24');
const appleAuthSecretNames = [
  'APPLE_TEAM_ID',
  'APPLE_KEY_ID',
  'APPLE_CLIENT_ID',
  'APPLE_PRIVATE_KEY',
];

type CoffeeStep = typeof coffeeRequiredSteps[number];
type CoffeeImageRefs = Record<CoffeeStep, string>;
type CoffeeReservationStatus = 'processing' | 'charged' | 'released' | 'expired';

type CoffeeReservationDoc = {
  uid: string;
  idempotencyKey: string;
  amount: number;
  status: CoffeeReservationStatus;
  expiresAtMs: number;
};

type CoffeeAnalysisState = {
  activeReservationId?: string | null;
  activeReservationExpiresAtMs?: number | null;
  activeReservationAmount?: number | null;
  windowStartedAtMs?: number;
  windowCount?: number;
  dayKey?: string;
  dayCount?: number;
};

type AppleRevokeResult = {
  attempted: boolean;
  success: boolean;
  errorCode?: string;
};

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

function timestampToMillis(value: unknown): number | null {
  if (!value) return null;
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'object' && 'toMillis' in value && typeof value.toMillis === 'function') {
    const millis = value.toMillis();
    return Number.isFinite(millis) ? millis : null;
  }
  return null;
}

function errorCode(error: unknown): string {
  return typeof error === 'object' && error && 'code' in error
    ? String((error as { code?: unknown }).code)
    : '';
}

function normalizeApplePrivateKey(value: string): string {
  return value.trim().replace(/\\n/g, '\n');
}

function requireAppleEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`APPLE_CONFIG_MISSING:${name}`);
  }
  return value;
}

function buildAppleClientSecret(): string {
  const teamId = requireAppleEnv('APPLE_TEAM_ID');
  const keyId = requireAppleEnv('APPLE_KEY_ID');
  const clientId = requireAppleEnv('APPLE_CLIENT_ID');
  const privateKey = normalizeApplePrivateKey(requireAppleEnv('APPLE_PRIVATE_KEY'));
  const now = Math.floor(Date.now() / 1000);

  return jwt.sign(
    {
      iss: teamId,
      iat: now,
      exp: now + 5 * 60,
      aud: 'https://appleid.apple.com',
      sub: clientId,
    },
    privateKey,
    {
      algorithm: 'ES256',
      keyid: keyId,
    },
  );
}

function safeAppleError(error: unknown): string {
  if (error instanceof Error) return error.message.slice(0, 180);
  if (typeof error === 'string') return error.slice(0, 180);
  return 'UNKNOWN_APPLE_ERROR';
}

async function parseAppleResponse(response: Awaited<ReturnType<typeof fetch>>): Promise<Record<string, unknown>> {
  const text = await response.text();
  if (!text.trim()) return {};
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return { error: text.slice(0, 180) };
  }
}

async function exchangeAppleAuthorizationCode(authorizationCode: string): Promise<string> {
  const clientId = requireAppleEnv('APPLE_CLIENT_ID');
  const clientSecret = buildAppleClientSecret();
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: 'authorization_code',
  });

  const response = await fetch('https://appleid.apple.com/auth/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  const data = await parseAppleResponse(response);

  if (!response.ok) {
    const appleError = typeof data.error === 'string' ? data.error : `HTTP_${response.status}`;
    throw new Error(`APPLE_TOKEN_EXCHANGE_FAILED:${appleError}`);
  }

  const refreshToken = typeof data.refresh_token === 'string'
    ? data.refresh_token.trim()
    : '';
  if (!refreshToken) {
    throw new Error('APPLE_REFRESH_TOKEN_MISSING');
  }

  return refreshToken;
}

async function revokeAppleRefreshToken(refreshToken: string): Promise<void> {
  const clientId = requireAppleEnv('APPLE_CLIENT_ID');
  const clientSecret = buildAppleClientSecret();
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: 'refresh_token',
  });

  const response = await fetch('https://appleid.apple.com/auth/revoke', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  if (!response.ok) {
    const data = await parseAppleResponse(response);
    const appleError = typeof data.error === 'string' ? data.error : `HTTP_${response.status}`;
    throw new Error(`APPLE_REVOKE_FAILED:${appleError}`);
  }
}

async function revokeAppleAuthorizationForUid(uid: string): Promise<AppleRevokeResult> {
  const appleAuthRef = db.collection('apple_auth').doc(uid);
  const appleAuthSnap = await appleAuthRef.get();
  const refreshToken = typeof appleAuthSnap.get('refreshToken') === 'string'
    ? String(appleAuthSnap.get('refreshToken')).trim()
    : '';

  if (!refreshToken) {
    return {
      attempted: false,
      success: false,
      errorCode: 'APPLE_REFRESH_TOKEN_NOT_FOUND',
    };
  }

  try {
    await revokeAppleRefreshToken(refreshToken);
    await appleAuthRef.delete();
    logger.info('apple revoke ok', { uid });
    return { attempted: true, success: true };
  } catch (error) {
    await appleAuthRef.delete().catch((deleteError) => {
      logger.warn('apple_auth cleanup after revoke failure failed', {
        uid,
        error: safeAppleError(deleteError),
      });
    });
    logger.error('apple revoke failed', {
      uid,
      error: safeAppleError(error),
    });
    return {
      attempted: true,
      success: false,
      errorCode: safeAppleError(error),
    };
  }
}

async function callerIsAdmin(uid: string, token: Record<string, unknown> | undefined): Promise<boolean> {
  if (token?.admin === true) return true;

  const adminSnap = await db.collection('admins').doc(uid).get();
  if (!adminSnap.exists) return false;

  const data = adminSnap.data() ?? {};
  return data.active !== false && data.disabled !== true;
}

async function deleteQueryDocuments(
  collectionPath: string,
  fieldName: string,
  uid: string,
): Promise<number> {
  let deleted = 0;

  while (true) {
    const snap = await db
      .collection(collectionPath)
      .where(fieldName, '==', uid)
      .limit(400)
      .get();

    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
      deleted += 1;
    }
    await batch.commit();

    if (snap.size < 400) break;
  }

  return deleted;
}

async function deleteStoragePrefixes(uid: string): Promise<string[]> {
  const prefixes = [
    `audio/${uid}/`,
    `coffee/${uid}/`,
    `palmistry/${uid}/`,
    `share/${uid}/`,
    `temp/${uid}/`,
    `users/${uid}/`,
  ];
  const deletedPrefixes: string[] = [];

  for (const prefix of prefixes) {
    try {
      await storage.bucket().deleteFiles({ prefix, force: true });
      deletedPrefixes.push(prefix);
    } catch (error) {
      logger.warn('deleteStoragePrefixes failed for prefix', { uid, prefix, error });
    }
  }

  return deletedPrefixes;
}

async function deleteUserArtifacts(uid: string): Promise<{
  userDocExisted: boolean;
  targetEmail?: string;
  deletedNotificationDeviceDocs: number;
  deletedStoragePrefixes: string[];
}> {
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() as Partial<UserDoc> | undefined;
  const targetEmail = typeof userData?.email === 'string' ? userData.email : undefined;

  await Promise.allSettled([
    db.recursiveDelete(userRef),
    db.recursiveDelete(db.collection('apple_auth').doc(uid)),
    db.recursiveDelete(db.collection('notificationPreferences').doc(uid)),
    db.recursiveDelete(db.collection('userNotificationPreferences').doc(uid)),
  ]);

  const deletedByUserId = await deleteQueryDocuments('notificationDevices', 'userId', uid);
  const deletedByUid = await deleteQueryDocuments('notificationDevices', 'uid', uid);
  const deletedStoragePrefixes = await deleteStoragePrefixes(uid);

  return {
    userDocExisted: userSnap.exists,
    targetEmail,
    deletedNotificationDeviceDocs: deletedByUserId + deletedByUid,
    deletedStoragePrefixes,
  };
}

async function deleteAuthUserIfExists(uid: string): Promise<boolean> {
  try {
    await getAuth().deleteUser(uid);
    return true;
  } catch (error) {
    if (errorCode(error) === 'auth/user-not-found') {
      return false;
    }
    throw error;
  }
}

function sanitizeShortText(value: unknown, maxLength: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\s+/g, ' ').slice(0, maxLength);
}

function sanitizeBase64Image(value: unknown, maxChars: number): string {
  if (typeof value !== 'string') return '';
  return value.replace(/\s+/g, '').slice(0, maxChars);
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

const ARIS_STORED_MESSAGE_LIMIT = 48;
const ARIS_PROMPT_MESSAGE_LIMIT = 6;

function newArisSessionId(): string {
  const stamp = Date.now().toString(36);
  const rand = Math.random().toString(36).slice(2, 8);
  return `aris_${stamp}_${rand}`.slice(0, 48);
}

function shouldUseSoftPersonalization(message?: string): boolean {
  if (!message) return true;
  const normalized = message.trim().toLowerCase();
  return !/\b(genel yorum|genel bir yorum|baskasi icin|başkası için|arkadasim icin|arkadaşım için|general reading|for someone else|for my friend)\b/i
    .test(normalized);
}

function buildArisProfileContext(
  user: UserDoc & Record<string, unknown>,
  options: { includeSoftPersonalization?: boolean } = {}
): string[] {
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

  if (user.personalizationEnabled === false || options.includeSoftPersonalization === false) {
    return context;
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
  cardNames?: string[];
  lang: string;
}): { systemPrompt: string; userPrompt: string } {
  const spread = Array.isArray(input.cardNames) ? input.cardNames.filter(Boolean) : [];
  const isSpread = spread.length > 1;
  const cardsLine = isSpread
    ? `Selected tarot cards (${spread.length}): ${spread.join(', ')}`
    : `Daily card: ${input.cardName}`;

  return {
    systemPrompt: [
      arisSpreadSystemRules(input.lang),
      isSpread
        ? 'Keep the response between 180 and 260 words.'
        : 'Keep the response between 100 and 140 words.'
    ].join(' '),
    userPrompt: [
      isSpread
        ? 'Create the opening spread interpretation for this user.'
        : 'Create the opening daily-card reflection for this user.',
      ...buildArisProfileContext(input.user),
      cardsLine,
      isSpread
        ? 'Interpret ONLY these cards together. For EACH selected card, write 2-3 sentences on its specific meaning in this spread (name the card explicitly). Then add a synthesis paragraph on how the cards interact (tension, harmony, shared theme). End with one grounded practical reflection for today.'
        : 'Focus on what this single card invites the user to notice today. Give layered meaning, not a one-line summary.',
      'Do not answer unrelated life topics. Do not use generic filler.'
    ].join('\n')
  };
}

function buildArisFallbackOpening(input: {
  user: UserDoc & Record<string, unknown>;
  cardName: string;
  cardNames?: string[];
  lang: string;
}): string {
  const spread = Array.isArray(input.cardNames) ? input.cardNames.filter(Boolean) : [];
  const cardsLabel = spread.length > 0 ? spread.join(', ') : input.cardName;
  const name = resolveUserDisplayName(input.user);
  const address = name && name !== 'Seeker' ? `${name}, ` : '';

  if (input.lang === 'tr') {
    if (spread.length > 1) {
      return [
        `${address}sectigin kartlar ${cardsLabel} birlikte tek bir hikaye anlatiyor.`,
        'Bu yayilim acele karar yerine netlik ve ic dengenin yeniden kurulmasini cagiriyor.',
        'Her kartin sesini ayri ayri dinle; sonra bugun icin tek bir nazik adim sec.'
      ].join(' ');
    }
    return [
      `${address}${input.cardName} karti bugun sana daha sakin ama daha duru bir bakis cagrisinda bulunuyor.`,
      'Bu kart, aceleyle cevap aramak yerine icinden gecen isareti fark etmeni ister.',
      'Bugun bir adim atmadan once kendine sunu sor: Beni gercekten hafifleten secim hangisi?'
    ].join(' ');
  }

  if (spread.length > 1) {
    return [
      `${address}your spread ${cardsLabel} speaks as one story.`,
      'Together these cards invite clarity and emotional balance instead of haste.',
      'Listen to each card, then choose one gentle step for today.'
    ].join(' ');
  }

  return [
    `${address}${input.cardName} invites you to slow down and notice what is becoming clearer today.`,
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
  cardNames?: string[];
  openingMessage: string;
  recentMessages: Array<{ role: 'user' | 'assistant'; text: string }>;
  userMessage: string;
  lang: string;
}): { systemPrompt: string; userPrompt: string } {
  const spread = Array.isArray(input.cardNames) ? input.cardNames.filter(Boolean) : [];
  const cardsLine = spread.length > 0
    ? `Selected tarot cards: ${spread.join(', ')}`
    : `Daily card: ${input.cardName}`;
  const transcript = input.recentMessages
    .slice(-6)
    .map((message) => `${message.role === 'user' ? 'User' : 'Aris'}: ${message.text}`)
    .join('\n');

  return {
    systemPrompt: [
      arisSpreadSystemRules(input.lang),
      'If the user asks about known profile facts, answer directly from profile context first.',
      'If the user only thanks you or greets you, answer briefly in one or two sentences.',
      'Keep the response between 85 and 140 words unless it is a short acknowledgement.'
    ].join(' '),
    userPrompt: [
      ...buildArisProfileContext(input.user, {
        includeSoftPersonalization: shouldUseSoftPersonalization(input.userMessage)
      }),
      cardsLine,
      `Opening reflection: ${input.openingMessage}`,
      transcript ? `Recent conversation:\n${transcript}` : '',
      `User: ${input.userMessage}`,
      'Answer ONLY through this spread. Reference at least one selected card by exact name. Refuse unrelated topics.'
    ].filter(Boolean).join('\n')
  };
}

function buildCoffeeArisConversationPrompt(input: {
  user: UserDoc & Record<string, unknown>;
  openingMessage: string;
  recentMessages: Array<{ role: 'user' | 'assistant'; text: string }>;
  userMessage: string;
  lang: string;
}): { systemPrompt: string; userPrompt: string } {
  const transcript = input.recentMessages
    .slice(-8)
    .map((message) => `${message.role === 'user' ? 'User' : 'Madam Aris'}: ${message.text}`)
    .join('\n');

  const systemPrompt = input.lang === 'tr'
    ? [
      'Sen Madam Aris adli zarif, mistik ve bilge bir kahve fali rehberisin.',
      'Kullanicinin yukledigi fincan ici, fincan tabagi ve fincan dis gorunumu yorumuna dayanarak sohbet edersin.',
      'AI, yapay zeka, model veya sistem oldugunu soyleme; Madam Aris olarak kendi agzindan konus.',
      'Tibbi, finansal, hukuki tavsiye verme ve kesin gelecek iddiasi kurma.',
      'Cevaplarin sicak, sezgisel, premium ve korkutmayan bir tonda olsun.',
      '85-140 kelime arasinda yanit ver; kullanici sadece tesekkur ederse kisa ve yumusak cevap ver.'
    ].join(' ')
    : [
      'You are Madam Aris, an elegant, mystical, and wise Turkish coffee reading guide.',
      'You continue the conversation from the user\'s uploaded cup-inside, saucer, and outer-cup reading.',
      'Do not say you are AI, a model, or a system; speak in-character as Madam Aris.',
      'Do not give medical, financial, legal advice, or certain future predictions.',
      'Keep the tone warm, intuitive, premium, and non-frightening.',
      'Answer in 85-140 words unless the user only thanks you.'
    ].join(' ');

  return {
    systemPrompt,
    userPrompt: [
      ...buildArisProfileContext(input.user, {
        includeSoftPersonalization: shouldUseSoftPersonalization(input.userMessage)
      }),
      `Opening coffee greeting: ${input.openingMessage}`,
      transcript ? `Recent coffee conversation:\n${transcript}` : '',
      `User: ${input.userMessage}`,
      input.lang === 'tr'
        ? 'Fincan yorumundaki sembolik dili koruyarak Madam Aris olarak cevap ver.'
        : 'Answer as Madam Aris while preserving the symbolic language of the coffee reading.'
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
  const providers = (user.providerData ?? [])
    .map((provider) => provider.providerId)
    .filter(Boolean);
  const hasSocialProvider = providers.some((providerId) => providerId === 'google.com' || providerId === 'apple.com');
  const hasPasswordProvider = providers.includes('password') || providers.length === 0;
  const emailVerified = Boolean(user.emailVerified || hasSocialProvider);
  const accountStatus = emailVerified ? 'pending_onboarding' : 'pending_email_verification';
  const snap = await userRef.get();
  if (snap.exists) {
    const existing = snap.data() as Partial<UserDoc>;
    const existingName = typeof existing.displayName === 'string' && existing.displayName.trim()
      ? existing.displayName.trim()
      : typeof existing.name === 'string'
        ? existing.name.trim()
        : '';
    const existingBirthDate = typeof existing.birthDate === 'string' ? existing.birthDate.trim() : '';
    const existingProfileComplete = existing.isProfileComplete === true &&
      existing.onboardingCompleted === true &&
      Boolean(existingName) &&
      Boolean(existingBirthDate);
    await userRef.set({
      ...(user.email ? { email: user.email } : {}),
      ...(user.displayName ? { name: user.displayName, displayName: user.displayName } : {}),
      provider: hasSocialProvider ? providers.find((providerId) => providerId === 'google.com' || providerId === 'apple.com') : 'password',
      providers: providers.length ? providers : ['password'],
      emailVerified,
      providerVerified: hasSocialProvider,
      cleanupEligible: !emailVerified && hasPasswordProvider,
      accountStatus: existingProfileComplete ? 'active' : accountStatus,
      onboardingCompleted: existingProfileComplete,
      isProfileComplete: existingProfileComplete,
      ...(!existing.wallet || typeof existing.wallet.credits !== 'number' ? {
        wallet: {
          credits: initialFreeCredits,
          isFirstFreeUsed: false
        },
      } : {}),
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    return;
  }

  const payload: UserDoc = {
    uid: user.uid,
    isProfileComplete: false,
    onboardingCompleted: false,
    accountStatus,
    emailVerified,
    providerVerified: hasSocialProvider,
    provider: hasSocialProvider ? providers.find((providerId) => providerId === 'google.com' || providerId === 'apple.com') : 'password',
    providers: providers.length ? providers : ['password'],
    cleanupEligible: !emailVerified && hasPasswordProvider,
    ...(user.email ? { email: user.email } : {}),
    ...(user.displayName ? { name: user.displayName, displayName: user.displayName } : {}),
    wallet: {
      credits: initialFreeCredits,
      isFirstFreeUsed: false
    },
    settings: {
      lang: 'tr',
      selectedPersonaId: 'emilia'
    },
    createdAt: FieldValue.serverTimestamp(),
    ...(!emailVerified ? { verificationResendCount: 0 } : {}),
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

export const handleUserDocumentDeleted = onDocumentDeleted(
  { document: 'users/{uid}', region: 'us-central1', secrets: appleAuthSecretNames },
  async (event) => {
  const uid = event.params.uid;
  if (!uid) return;

  const deletedData = event.data?.data() as Partial<UserDoc> | undefined;
  const deletedEmail = typeof deletedData?.email === 'string' ? deletedData.email : undefined;

  try {
    const appleRevoke = await revokeAppleAuthorizationForUid(uid);
    const authDeleted = await deleteAuthUserIfExists(uid);
    const cleanup = await deleteUserArtifacts(uid);

    await db.collection('adminLogs').add({
      action: 'handleUserDocumentDeleted',
      targetUid: uid,
      actorUid: 'firestore-user-delete-trigger',
      targetEmail: deletedEmail ?? cleanup.targetEmail ?? null,
      authDeleted,
      appleRevokeAttempted: appleRevoke.attempted,
      appleRevoked: appleRevoke.success,
      appleRevokeError: appleRevoke.errorCode ?? null,
      userDocExisted: cleanup.userDocExisted,
      deletedNotificationDeviceDocs: cleanup.deletedNotificationDeviceDocs,
      deletedStoragePrefixes: cleanup.deletedStoragePrefixes,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info('handleUserDocumentDeleted completed', {
      uid,
      authDeleted,
      appleRevokeAttempted: appleRevoke.attempted,
      appleRevoked: appleRevoke.success,
      userDocExisted: cleanup.userDocExisted,
    });
  } catch (error) {
    logger.error('handleUserDocumentDeleted failed', { uid, error });
  }
});

export const registerAppleAuthorization = onCall(
  { region: 'us-central1', enforceAppCheck: false, secrets: appleAuthSecretNames },
  async (request) => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
      }

      const authorizationCode = typeof request.data?.authorizationCode === 'string'
        ? request.data.authorizationCode.trim()
        : '';
      if (!authorizationCode) {
        throw new HttpsError('invalid-argument', 'APPLE_AUTHORIZATION_CODE_REQUIRED');
      }

      const refreshToken = await exchangeAppleAuthorizationCode(authorizationCode);
      await db.collection('apple_auth').doc(request.auth.uid).set({
        refreshToken,
        provider: 'apple.com',
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      logger.info('registerAppleAuthorization completed', {
        uid: request.auth.uid,
        refreshTokenStored: true,
      });

      return { success: true, refreshTokenStored: true };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error('registerAppleAuthorization failed', {
        uid: request.auth?.uid ?? null,
        error: safeAppleError(err),
      });
      throw new HttpsError('internal', 'APPLE_AUTHORIZATION_REGISTER_FAILED');
    }
  },
);

export const deleteUserCompletely = onCall({ enforceAppCheck: false, secrets: appleAuthSecretNames }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const adminUid = request.auth.uid;
    const token = request.auth.token as Record<string, unknown> | undefined;
    const isAdmin = await callerIsAdmin(adminUid, token);
    if (!isAdmin) {
      throw new HttpsError('permission-denied', 'ADMIN_REQUIRED');
    }

    const targetUid = typeof request.data?.uid === 'string'
      ? request.data.uid.trim()
      : '';
    if (!targetUid) {
      throw new HttpsError('invalid-argument', 'UID_REQUIRED');
    }

    if (targetUid === adminUid) {
      throw new HttpsError('failed-precondition', 'CANNOT_DELETE_SELF_WITH_ADMIN_FUNCTION');
    }

    const targetSnap = await db.collection('users').doc(targetUid).get();
    const targetData = targetSnap.data() as Partial<UserDoc> | undefined;
    const targetEmail = typeof targetData?.email === 'string' ? targetData.email : undefined;

    const appleRevoke = await revokeAppleAuthorizationForUid(targetUid);
    const authDeleted = await deleteAuthUserIfExists(targetUid);
    const cleanup = await deleteUserArtifacts(targetUid);

    await db.collection('adminLogs').add({
      action: 'deleteUserCompletely',
      targetUid,
      adminUid,
      targetEmail: targetEmail ?? cleanup.targetEmail ?? null,
      authDeleted,
      appleRevokeAttempted: appleRevoke.attempted,
      appleRevoked: appleRevoke.success,
      appleRevokeError: appleRevoke.errorCode ?? null,
      userDocExisted: cleanup.userDocExisted,
      deletedNotificationDeviceDocs: cleanup.deletedNotificationDeviceDocs,
      deletedStoragePrefixes: cleanup.deletedStoragePrefixes,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info('deleteUserCompletely completed', {
      targetUid,
      adminUid,
      authDeleted,
      appleRevokeAttempted: appleRevoke.attempted,
      appleRevoked: appleRevoke.success,
      userDocExisted: cleanup.userDocExisted,
    });

    return { success: true, authDeleted, appleRevoked: appleRevoke.success };
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    logger.error('deleteUserCompletely failed', {
      callerUid: request.auth?.uid ?? null,
      targetUid: request.data?.uid ?? null,
      err,
    });
    throw new HttpsError('internal', 'DELETE_USER_FAILED');
  }
});

export const deleteCurrentUserCompletely = onCall({ enforceAppCheck: false, secrets: appleAuthSecretNames }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    if (request.data?.confirm !== true) {
      throw new HttpsError('invalid-argument', 'CONFIRM_REQUIRED');
    }

    const uid = request.auth.uid;
    const userSnap = await db.collection('users').doc(uid).get();
    const userData = userSnap.data() as Partial<UserDoc> | undefined;
    const targetEmail = typeof userData?.email === 'string' ? userData.email : undefined;

    const appleRevoke = await revokeAppleAuthorizationForUid(uid);
    const authDeleted = await deleteAuthUserIfExists(uid);
    const cleanup = await deleteUserArtifacts(uid);

    await db.collection('adminLogs').add({
      action: 'deleteCurrentUserCompletely',
      targetUid: uid,
      actorUid: uid,
      targetEmail: targetEmail ?? cleanup.targetEmail ?? null,
      authDeleted,
      appleRevokeAttempted: appleRevoke.attempted,
      appleRevoked: appleRevoke.success,
      appleRevokeError: appleRevoke.errorCode ?? null,
      userDocExisted: cleanup.userDocExisted,
      deletedNotificationDeviceDocs: cleanup.deletedNotificationDeviceDocs,
      deletedStoragePrefixes: cleanup.deletedStoragePrefixes,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info('deleteCurrentUserCompletely completed', {
      uid,
      authDeleted,
      appleRevokeAttempted: appleRevoke.attempted,
      appleRevoked: appleRevoke.success,
      userDocExisted: cleanup.userDocExisted,
    });

    return { success: true, authDeleted, appleRevoked: appleRevoke.success };
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    logger.error('deleteCurrentUserCompletely failed', {
      uid: request.auth?.uid ?? null,
      err,
    });
    throw new HttpsError('internal', 'DELETE_CURRENT_USER_FAILED');
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

      const user = userSnap.data() as UserDoc & {
        readingThrottle?: {
          windowStartedAtMs?: number;
          windowCount?: number;
          dayKey?: string;
          dayCount?: number;
        };
      };
      const profile = user.profile;
      if (!user.isProfileComplete || !profile?.name || !profile.birthDate) {
        throw new Error('PROFILE_INCOMPLETE');
      }

      const nowMs = Date.now();
      const throttle = checkAndBumpThrottle({
        throttle: user.readingThrottle,
        nowMs,
        windowMs: readingThrottleWindowMs,
        windowLimit: readingWindowLimit,
        dailyLimit: readingDailyLimit,
        dayKey: coffeeDayKey(nowMs),
      });
      if (!throttle.allowed) {
        throw new HttpsError('resource-exhausted', 'RATE_LIMITED');
      }

      if (user.wallet.credits <= 0) {
        throw new Error('INSUFFICIENT_CREDITS');
      }

      previousCredits = user.wallet.credits;
      tx.update(userRef, {
        'wallet.credits': previousCredits - 1,
        readingThrottle: throttle.next,
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
        maxOutputTokens: 500
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

function parseCoffeeImageRefs(uid: string, rawRefs: unknown): {
  imageRefs: CoffeeImageRefs;
  uploadId: string;
} {
  if (!rawRefs || typeof rawRefs !== 'object' || Array.isArray(rawRefs)) {
    throw new HttpsError('invalid-argument', 'INVALID_COFFEE_INPUT');
  }

  const input = rawRefs as Record<string, unknown>;
  const parsed = {} as CoffeeImageRefs;
  let uploadId = '';
  const seenPaths = new Set<string>();

  for (const step of coffeeRequiredSteps) {
    const path = typeof input[step] === 'string' ? input[step].trim() : '';
    const match = path.match(/^coffee\/([^/]+)\/(coffee_[0-9]+)\/(cupInside|saucer|cupSide)\.jpg$/);
    if (!match || match[1] !== uid || match[3] !== step || seenPaths.has(path)) {
      throw new HttpsError('invalid-argument', 'INVALID_COFFEE_IMAGE_REF');
    }
    if (uploadId && uploadId !== match[2]) {
      throw new HttpsError('invalid-argument', 'INVALID_COFFEE_IMAGE_REF');
    }
    uploadId = match[2];
    parsed[step] = path;
    seenPaths.add(path);
  }

  return { imageRefs: parsed, uploadId };
}

function validateLocalCoffeeSummary(rawSummary: unknown) {
  if (!rawSummary || typeof rawSummary !== 'object' || Array.isArray(rawSummary)) {
    throw new HttpsError('invalid-argument', 'INVALID_COFFEE_LOCAL_VALIDATION');
  }
  const summary = rawSummary as Record<string, unknown>;
  for (const step of coffeeRequiredSteps) {
    const stepSummary = summary[step];
    if (!stepSummary || typeof stepSummary !== 'object' || Array.isArray(stepSummary)) {
      throw new HttpsError('invalid-argument', 'INVALID_COFFEE_LOCAL_VALIDATION');
    }
    if ((stepSummary as Record<string, unknown>).isValid !== true) {
      throw new HttpsError('failed-precondition', 'INVALID_COFFEE_LOCAL_VALIDATION');
    }
  }
}

async function deleteCoffeeImages(imageRefs: Partial<CoffeeImageRefs>) {
  await Promise.all(
    Object.values(imageRefs).map(async (path) => {
      if (!path) return;
      try {
        await storage.bucket().file(path).delete({ ignoreNotFound: true });
      } catch (error) {
        logger.warn('Coffee image cleanup failed', {
          path,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    })
  );
}

async function loadCoffeeImages(imageRefs: CoffeeImageRefs) {
  const images: Array<{ step: string; mimeType: string; base64: string }> = [];
  for (const step of coffeeRequiredSteps) {
    const file = storage.bucket().file(imageRefs[step]);
    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    if (metadata.contentType !== 'image/jpeg' || size <= 0 || size > coffeeMaxImageBytes) {
      throw new HttpsError('invalid-argument', 'INVALID_COFFEE_IMAGE_METADATA');
    }
    const [buffer] = await file.download();
    images.push({
      step,
      mimeType: 'image/jpeg',
      base64: buffer.toString('base64'),
    });
  }
  return images;
}

function coffeeDayKey(nowMs: number) {
  return new Date(nowMs).toISOString().slice(0, 10);
}

function coffeeResultWithoutInternalFields(data: FirebaseFirestore.DocumentData) {
  const {
    status: _status,
    createdAt: _createdAt,
    updatedAt: _updatedAt,
    ...result
  } = data;
  return result;
}

async function reserveCoffeeCredits(input: {
  uid: string;
  idemKey: string;
  userRef: FirebaseFirestore.DocumentReference;
  idempotencyRef: FirebaseFirestore.DocumentReference;
  reservationRef: FirebaseFirestore.DocumentReference;
}) {
  const nowMs = Date.now();
  let cachedResult: FirebaseFirestore.DocumentData | null = null;

  await db.runTransaction(async (tx) => {
    const [userSnap, idempotencySnap] = await Promise.all([
      tx.get(input.userRef),
      tx.get(input.idempotencyRef),
    ]);
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'USER_NOT_FOUND');
    }

    if (idempotencySnap.exists) {
      const data = idempotencySnap.data() ?? {};
      if (data.status === 'processing') {
        throw new Error('COFFEE_ANALYSIS_IN_PROGRESS');
      }
      if (data.status === 'completed' || typeof data.success === 'boolean') {
        cachedResult = coffeeResultWithoutInternalFields(data);
        return;
      }
    }

    const user = userSnap.data() as UserDoc & {
      coffeeAnalysis?: CoffeeAnalysisState;
    };
    const wallet = user.wallet ?? { credits: 0, isFirstFreeUsed: false };
    const analysis = user.coffeeAnalysis ?? {};
    const activeReservationId = analysis.activeReservationId ?? null;
    const activeExpiresAtMs = Number(analysis.activeReservationExpiresAtMs ?? 0);
    const activeAmount = Number(analysis.activeReservationAmount ?? 0);
    let reservedCredits = Number(wallet.coffeeReservedCredits ?? 0);

    if (activeReservationId && activeExpiresAtMs > nowMs) {
      throw new Error('COFFEE_ANALYSIS_IN_PROGRESS');
    }
    if (activeReservationId && activeExpiresAtMs <= nowMs) {
      reservedCredits = Math.max(0, reservedCredits - activeAmount);
      tx.set(
        input.userRef.collection('coffee_reservations').doc(activeReservationId),
        {
          status: 'expired',
          expiresAtMs: null,
          releasedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    const dayKey = coffeeDayKey(nowMs);
    const throttle = checkAndBumpThrottle({
      throttle: analysis,
      nowMs,
      windowMs: coffeeReservationTtlMs,
      windowLimit: coffeeTenMinuteAttemptLimit,
      dailyLimit: coffeeDailyAttemptLimit,
      dayKey,
    });
    if (!throttle.allowed) {
      throw new Error('COFFEE_RATE_LIMITED');
    }

    const credits = Number(wallet.credits ?? 0);
    if (credits - reservedCredits < coffeeReadingCost) {
      throw new Error('INSUFFICIENT_CREDITS');
    }

    const expiresAtMs = nowMs + coffeeReservationTtlMs;
    tx.update(input.userRef, {
      'wallet.coffeeReservedCredits': reservedCredits + coffeeReadingCost,
      coffeeAnalysis: {
        activeReservationId: input.idemKey,
        activeReservationExpiresAtMs: expiresAtMs,
        activeReservationAmount: coffeeReadingCost,
        windowStartedAtMs: throttle.next.windowStartedAtMs,
        windowCount: throttle.next.windowCount,
        dayKey: throttle.next.dayKey,
        dayCount: throttle.next.dayCount,
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(input.reservationRef, {
      uid: input.uid,
      idempotencyKey: input.idemKey,
      amount: coffeeReadingCost,
      status: 'processing',
      expiresAtMs,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(input.idempotencyRef, {
      status: 'processing',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return cachedResult;
}

async function releaseCoffeeReservation(input: {
  userRef: FirebaseFirestore.DocumentReference;
  idempotencyRef: FirebaseFirestore.DocumentReference;
  reservationRef: FirebaseFirestore.DocumentReference;
  result?: Record<string, unknown>;
}) {
  await db.runTransaction(async (tx) => {
    const [userSnap, reservationSnap] = await Promise.all([
      tx.get(input.userRef),
      tx.get(input.reservationRef),
    ]);
    if (!userSnap.exists || !reservationSnap.exists) return;

    const reservation = reservationSnap.data() as CoffeeReservationDoc;
    if (reservation.status !== 'processing') return;

    const user = userSnap.data() as UserDoc & { coffeeAnalysis?: CoffeeAnalysisState };
    const analysis = user.coffeeAnalysis ?? {};
    const reservedCredits = Math.max(
      0,
      Number(user.wallet?.coffeeReservedCredits ?? 0) - Number(reservation.amount ?? 0)
    );
    const updates: Record<string, unknown> = {
      'wallet.coffeeReservedCredits': reservedCredits,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (analysis.activeReservationId === reservation.idempotencyKey) {
      updates['coffeeAnalysis.activeReservationId'] = null;
      updates['coffeeAnalysis.activeReservationExpiresAtMs'] = null;
      updates['coffeeAnalysis.activeReservationAmount'] = null;
    }
    tx.update(input.userRef, updates);
    tx.update(input.reservationRef, {
      status: 'released',
      expiresAtMs: null,
      releasedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      input.idempotencyRef,
      input.result
        ? {
          ...input.result,
          status: 'completed',
          updatedAt: FieldValue.serverTimestamp(),
        }
        : {
          status: 'failed',
          updatedAt: FieldValue.serverTimestamp(),
        },
      { merge: true }
    );
  });
}

export const analyzeCoffeeReading = onCall(
  {
    enforceAppCheck: false,
    secrets: ['GEMINI_API_KEY'],
    maxInstances: 3,
    concurrency: 2,
    timeoutSeconds: 60,
  },
  async (request) => {
    let imageRefs: CoffeeImageRefs | null = null;
    let reservationStarted = false;
    let completed = false;
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
      }

      const uid = request.auth.uid;
      requireAppCheckIfEnabled(request);
      logger.info('Coffee App Check telemetry', {
        hasAppCheck: Boolean(request.app),
      });

      const idemKey = requireIdempotencyKey(request.data?.idempotencyKey);
      const languageCode = resolveLanguage(request.data?.languageCode);
      const mood = sanitizeShortText(request.data?.mood, 320);
      const parsedRefs = parseCoffeeImageRefs(uid, request.data?.imageRefs);
      imageRefs = parsedRefs.imageRefs;
      validateLocalCoffeeSummary(request.data?.localValidation);

      const userRef = db.collection('users').doc(uid);
      const idempotencyRef = userRef.collection('idempotency').doc(`coffee_${idemKey}`);
      const reservationRef = userRef.collection('coffee_reservations').doc(idemKey);
      const cachedResult = await reserveCoffeeCredits({
        uid,
        idemKey,
        userRef,
        idempotencyRef,
        reservationRef,
      });
      if (cachedResult) {
        completed = true;
        return cachedResult;
      }
      reservationStarted = true;

      const images = await loadCoffeeImages(imageRefs);
      const aiPayload = await createCoffeeReadingWithVision({
        languageCode,
        images,
        mood,
      });

      if (!aiPayload.validation.isValid || !aiPayload.reading) {
        const userSnap = await userRef.get();
        const invalidResult = {
          success: false,
          chargedCredits: 0,
          remainingCredits: Number((userSnap.data() as Partial<UserDoc> | undefined)?.wallet?.credits ?? 0),
          readingId: '',
          validation: aiPayload.validation,
          reading: null,
        };
        await releaseCoffeeReservation({
          userRef,
          idempotencyRef,
          reservationRef,
          result: invalidResult,
        });
        await deleteCoffeeImages(imageRefs);
        completed = true;
        return invalidResult;
      }

      const readingRef = userRef.collection('coffee_readings').doc();
      const retentionExpiresAtMs = Date.now() + coffeeRetentionMs;
      let remainingCredits = 0;
      const successResult = {
        success: true,
        chargedCredits: coffeeReadingCost,
        remainingCredits,
        readingId: readingRef.id,
        validation: aiPayload.validation,
        reading: aiPayload.reading,
      };

      await db.runTransaction(async (tx) => {
        const [userSnap, reservationSnap] = await Promise.all([
          tx.get(userRef),
          tx.get(reservationRef),
        ]);
        if (!userSnap.exists) {
          throw new HttpsError('not-found', 'USER_NOT_FOUND');
        }
        if (!reservationSnap.exists) {
          throw new Error('COFFEE_RESERVATION_MISSING');
        }
        const reservation = reservationSnap.data() as CoffeeReservationDoc;
        if (reservation.status !== 'processing') {
          throw new Error('COFFEE_RESERVATION_INVALID');
        }

        const user = userSnap.data() as UserDoc;
        const credits = Number(user.wallet?.credits ?? 0);
        const reservedCredits = Number(user.wallet?.coffeeReservedCredits ?? 0);
        if (credits < coffeeReadingCost || reservedCredits < coffeeReadingCost) {
          throw new Error('INSUFFICIENT_CREDITS');
        }
        remainingCredits = credits - coffeeReadingCost;
        successResult.remainingCredits = remainingCredits;

        tx.update(userRef, {
          'wallet.credits': remainingCredits,
          'wallet.coffeeReservedCredits': Math.max(0, reservedCredits - coffeeReadingCost),
          'coffeeAnalysis.activeReservationId': null,
          'coffeeAnalysis.activeReservationExpiresAtMs': null,
          'coffeeAnalysis.activeReservationAmount': null,
          lastCoffeeReadingAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.update(reservationRef, {
          status: 'charged',
          expiresAtMs: null,
          chargedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.set(userRef.collection('credit_ledger').doc(), {
          type: 'debit',
          amount: -coffeeReadingCost,
          reason: 'coffee_reading',
          idempotencyKey: idemKey,
          createdAt: FieldValue.serverTimestamp(),
        });
        tx.set(readingRef, {
          uid,
          languageCode,
          uploadId: parsedRefs.uploadId,
          imageRefs,
          validation: aiPayload.validation,
          reading: aiPayload.reading,
          status: 'succeeded',
          idempotencyKey: idemKey,
          retentionExpiresAtMs,
          imagesDeletedAt: null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.set(idempotencyRef, {
          ...successResult,
          status: 'completed',
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      });

      await Promise.all(Object.values(imageRefs).map(async (path) => {
        try {
          await storage.bucket().file(path).setMetadata({
            metadata: {
              coffeeReadingId: readingRef.id,
              coffeeRetentionUntil: new Date(retentionExpiresAtMs).toISOString(),
            },
          });
        } catch (error) {
          logger.warn('Coffee retention metadata update failed', {
            path,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }));
      completed = true;
      return successResult;
    } catch (err) {
      if (reservationStarted && !completed && request.auth?.uid) {
        const idemKey = requireIdempotencyKey(request.data?.idempotencyKey);
        const userRef = db.collection('users').doc(request.auth.uid);
        await releaseCoffeeReservation({
          userRef,
          idempotencyRef: userRef.collection('idempotency').doc(`coffee_${idemKey}`),
          reservationRef: userRef.collection('coffee_reservations').doc(idemKey),
        });
      }
      if (!completed && imageRefs) {
        await deleteCoffeeImages(imageRefs);
      }
      throw mapError(err);
    }
  }
);

export const deleteCoffeeReadingPhotos = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }
    requireAppCheckIfEnabled(request);
    const uid = request.auth.uid;
    const readingId = String(request.data?.readingId ?? '').trim();
    if (!readingId) {
      throw new HttpsError('invalid-argument', 'INVALID_READING_ID');
    }

    const readingRef = db.collection('users').doc(uid).collection('coffee_readings').doc(readingId);
    const readingSnap = await readingRef.get();
    if (!readingSnap.exists) {
      throw new HttpsError('not-found', 'READING_NOT_FOUND');
    }
    const reading = readingSnap.data() as { imageRefs?: unknown };
    const { imageRefs } = parseCoffeeImageRefs(uid, reading.imageRefs);
    await deleteCoffeeImages(imageRefs);
    await readingRef.update({
      imagesDeletedAt: FieldValue.serverTimestamp(),
      retentionExpiresAtMs: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
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
      comment = buildBirthFrequencyFallback({ birthDate, day, lang });
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
    const requestedCost = Number(request.data?.cost ?? homeCardDrawCost);
    const drawCost = Number.isFinite(requestedCost) &&
      requestedCost >= homeCardDrawCost &&
      requestedCost <= homeCardDrawCost * 7 &&
      requestedCost % homeCardDrawCost === 0
      ? requestedCost
      : homeCardDrawCost;

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError('not-found', 'USER_NOT_FOUND');
      }

      const user = userSnap.data() as UserDoc;
      const currentCredits = Number(user.wallet.credits ?? 0);
      if (currentCredits < drawCost) {
        throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDITS');
      }

      remainingCredits = currentCredits - drawCost;
      tx.update(userRef, {
        'wallet.credits': remainingCredits,
        updatedAt: FieldValue.serverTimestamp()
      });

      tx.set(userRef.collection('credit_ledger').doc(), {
        type: 'debit',
        amount: -drawCost,
        reason: 'home_card_draw',
        createdAt: FieldValue.serverTimestamp()
      });
    });

    return {
      ok: true,
      drawCost,
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
    let cardNamesInput = Array.isArray(request.data?.cardNames)
      ? request.data.cardNames.map((item: unknown) => sanitizeShortText(item, 80)).filter(Boolean).slice(0, 7)
      : [];
    const singleCardName = sanitizeShortText(request.data?.cardName, 80);
    if (cardNamesInput.length === 0 && singleCardName.includes(',')) {
      cardNamesInput = singleCardName
        .split(',')
        .map((item) => sanitizeShortText(item, 80))
        .filter(Boolean)
        .slice(0, 7);
    }
    const cardName = cardNamesInput.length > 0
      ? cardNamesInput.join(', ')
      : singleCardName;
    const cardImageUrl = sanitizeShortText(request.data?.cardImageUrl, 500);
    const day = sanitizeShortText(request.data?.day, 10) || localDateKey();
    const sessionId = sanitizeShortText(request.data?.sessionId, 48) || newArisSessionId();
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
    const sessionRef = userRef.collection('aris_sessions').doc(sessionId);
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
          sessionId,
          openingMessage,
          cardName,
          cardImageUrl: existing.cardImageUrl ?? cardImageUrl,
          cached: true
        };
      }
    }

    const prompts = buildArisOpeningPrompt({
      user,
      cardName,
      cardNames: cardNamesInput.length > 0 ? cardNamesInput : undefined,
      lang
    });
    let openingMessage = '';
    let source: 'ai' | 'fallback' = 'ai';
    try {
      openingMessage = (await createReadingText({
        ...prompts,
        maxOutputTokens: cardNamesInput.length > 1 ? 640 : 320,
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
      openingMessage = buildArisFallbackOpening({
        user,
        cardName,
        cardNames: cardNamesInput.length > 0 ? cardNamesInput : undefined,
        lang
      });
    }
    openingMessage = cleanArisPersonaText(openingMessage);

    await sessionRef.set({
      uid,
      day,
      lang,
      cardName,
      cardNames: cardNamesInput.length > 0 ? cardNamesInput : [cardName],
      cardImageUrl,
      openingMessage,
      openingSource: source,
      recentMessages: [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    return {
      sessionId,
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

export const listArisSessions = onCall({ enforceAppCheck: false }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    const snap = await db.collection('users').doc(uid).collection('aris_sessions').limit(80).get();
    const sessions = snap.docs
      .map((doc) => {
        const data = doc.data() as Record<string, unknown>;
        const updatedAt = data.updatedAt as FirebaseFirestore.Timestamp | undefined;
        const createdAt = data.createdAt as FirebaseFirestore.Timestamp | undefined;
        const timestamp = updatedAt ?? createdAt;
        return {
          sessionId: doc.id,
          cardName: typeof data.cardName === 'string' ? data.cardName : '',
          cardNames: Array.isArray(data.cardNames) ? data.cardNames : [],
          openingMessage: typeof data.openingMessage === 'string' ? data.openingMessage : '',
          recentMessages: Array.isArray(data.recentMessages) ? data.recentMessages : [],
          day: typeof data.day === 'string' ? data.day : '',
          updatedAtMs: timestamp?.toMillis?.() ?? 0
        };
      })
      .filter((session) => {
        const opening = String(session.openingMessage).trim();
        const recent = Array.isArray(session.recentMessages) ? session.recentMessages : [];
        return opening.length > 0 || recent.length > 0;
      })
      .sort((a, b) => b.updatedAtMs - a.updatedAtMs)
      .slice(0, 80);

    return { sessions };
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
    const sessionId = sanitizeShortText(request.data?.sessionId, 48);
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
      cardNames?: string[];
      openingMessage?: string;
      lang?: string;
      mode?: string;
      persona?: string;
      recentMessages?: Array<{ role?: string; text?: string }>;
    };
    const isCoffeeSession = session.mode === 'coffeeReading' || session.persona === 'madamAris';
    const cardName = session.cardName?.trim();
    const cardNames = Array.isArray(session.cardNames)
      ? session.cardNames.map((item) => sanitizeShortText(item, 80)).filter(Boolean)
      : [];
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
        .slice(-ARIS_STORED_MESSAGE_LIMIT)
      : [];
    const lang = resolveArisLanguage({
      requestedLang: request.data?.lang,
      message,
      sessionLang: session.lang,
      user
    });
    const currentCredits = Number((user as UserDoc).wallet.credits ?? 0);
    const restrictedReply = restrictedArisReply({ message, lang });
    const offTopicReply = !restrictedReply && !isCoffeeSession && isOffTopicArisMessage(message)
      ? offTopicArisReply(lang)
      : null;
    if (restrictedReply || offTopicReply) {
      const guardReply = restrictedReply ?? offTopicReply!;
      const updatedMessages = [
        ...recentMessages,
        { role: 'user' as const, text: message },
        { role: 'assistant' as const, text: guardReply }
      ].slice(-ARIS_STORED_MESSAGE_LIMIT);
      const result = {
        reply: guardReply,
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
    const quickReply = isCoffeeSession ? null : quickArisReply({ message, lang, user });
    if (quickReply) {
      const updatedMessages = [
        ...recentMessages,
        { role: 'user' as const, text: message },
        { role: 'assistant' as const, text: quickReply }
      ].slice(-ARIS_STORED_MESSAGE_LIMIT);
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
        : isCoffeeSession
          ? buildCoffeeArisConversationPrompt({
            user,
            openingMessage,
            recentMessages,
            userMessage: message,
            lang
          })
          : buildArisConversationPrompt({
            user,
            cardName,
            cardNames: cardNames.length > 0 ? cardNames : undefined,
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
      ].slice(-ARIS_STORED_MESSAGE_LIMIT);
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
    const safeTransactionId = transactionId || idemKey;
    const transactionRef = userRef.collection('iap_transactions').doc(safeTransactionId);
    const idemSnap = await idemRef.get();
    if (idemSnap.exists) {
      return idemSnap.data();
    }

    const validation = await validateAppleReceipt({ transactionId, productId, receiptData });
    if (!validation.isValid || validation.productType === 'unknown') {
      throw new HttpsError('failed-precondition', 'PURCHASE_INVALID');
    }

    let remainingCredits = 0;
    let premiumActive = false;
    await db.runTransaction(async (tx) => {
      const txSnap = await tx.get(transactionRef);
      if (txSnap.exists) {
        remainingCredits = Number((txSnap.data() as { remainingCredits?: number }).remainingCredits ?? 0);
        premiumActive = Boolean((txSnap.data() as { premiumActive?: boolean }).premiumActive ?? false);
        return;
      }

      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError('not-found', 'USER_NOT_FOUND');
      }

      const user = userSnap.data() as UserDoc;
      const currentCredits = Number(user.wallet.credits ?? 0);
      const creditsToGrant = validation.productType === 'monthly_premium'
        ? validation.premiumBonusCredits
        : validation.creditsToGrant;
      remainingCredits = currentCredits + creditsToGrant;
      premiumActive = validation.productType === 'monthly_premium';

      const updates: Record<string, unknown> = {
        'wallet.credits': remainingCredits,
        updatedAt: FieldValue.serverTimestamp()
      };

      if (validation.productType === 'monthly_premium') {
        updates['entitlements.premium.active'] = true;
        updates['entitlements.premium.productId'] = productId;
        updates['entitlements.premium.originalTransactionId'] = safeTransactionId;
        updates['entitlements.premium.willRenew'] = true;
        updates['entitlements.premium.lastVerifiedAt'] = FieldValue.serverTimestamp();
        // TODO: Store App Store Server API expiration/period values here:
        // entitlements.premium.expiresAt, currentSubscriptionPeriodId.
      }

      tx.update(userRef, updates);

      tx.set(userRef.collection('credit_ledger').doc(), {
        type: 'credit',
        amount: creditsToGrant,
        reason: validation.productType === 'monthly_premium'
          ? 'ios_premium_period_bonus'
          : 'ios_purchase',
        productId,
        transactionId: safeTransactionId,
        idempotencyKey: idemKey,
        createdAt: FieldValue.serverTimestamp()
      });
      tx.set(transactionRef, {
        productId,
        transactionId: safeTransactionId,
        productType: validation.productType,
        creditsGranted: creditsToGrant,
        remainingCredits,
        premiumActive,
        createdAt: FieldValue.serverTimestamp()
      });
    });

    const result = {
      success: true,
      creditedAmount: validation.productType === 'monthly_premium'
        ? validation.premiumBonusCredits
        : validation.creditsToGrant,
      remainingCredits,
      entitlements: {
        premium: {
          active: premiumActive,
          productId: premiumActive ? productId : null,
          willRenew: premiumActive ? true : null
        },
        credits: {
          balance: remainingCredits
        }
      }
    };

    await idemRef.set({ ...result, createdAt: FieldValue.serverTimestamp() });
    return result;
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
        onboardingCompleted: true,
        accountStatus: 'active',
        cleanupEligible: false,
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

export const onWalletCreditsChanged = onDocumentUpdated('users/{uid}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const beforeCredits = Number(before.wallet?.credits ?? 0);
  const afterCredits = Number(after.wallet?.credits ?? 0);
  if (beforeCredits === afterCredits) return;

  const prefs = after.notificationPrefs;
  if (!prefs || prefs.enabled === false || prefs.walletOffers?.enabled === false) return;

  const uid = event.params.uid;
  const userRef = db.collection('users').doc(uid);

  if (afterCredits < walletLowThreshold) {
    if (after.walletLowNotified === true) return;

    const lang = resolveUserLang(after);
    const vars = buildNotifVars(after, lang);
    const category = Math.random() < 0.5 ? 'wallet_low' : 'wallet_offer';
    const variant = pickNotification(lang, category, {
      ...vars,
      credits: afterCredits,
    });

    const result = await sendNotificationToUser({
      uid,
      title: variant.title,
      body: variant.body,
      data: {
        type: 'wallet_low',
        route: '/shop',
      },
    });

    await userRef.set(
      {
        walletLowNotified: true,
        walletLowNotifiedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info('wallet low notification sent', {
      uid,
      afterCredits,
      category,
      tokenCount: result.tokenCount,
    });
  } else if (after.walletLowNotified) {
    await userRef.set(
      {
        walletLowNotified: false,
      },
      { merge: true }
    );
  }
});

export const sendDailyCardNudges = onSchedule(
  {
    schedule: 'every 1 hours',
    timeZone: 'Etc/UTC',
    timeoutSeconds: 300,
  },
  async () => {
    let scanned = 0;
    let sent = 0;
    let skipped = 0;
    let failed = 0;
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    const now = new Date();

    while (true) {
      let query = db
        .collection('users')
        .where('isProfileComplete', '==', true)
        .orderBy(FieldPath.documentId())
        .limit(400);

      if (cursor) {
        query = query.startAfter(cursor);
      }

      const snap = await query.get();
      if (snap.empty) break;

      for (const userDoc of snap.docs) {
        scanned += 1;
        try {
          const data = userDoc.data() as Record<string, any>;
          const timezone =
            typeof data.timezone === 'string' && data.timezone.trim()
              ? data.timezone.trim()
              : null;
          if (!timezone) {
            skipped += 1;
            continue;
          }

          const prefs = data.notificationPrefs;
          if (!prefs || prefs.enabled === false) {
            skipped += 1;
            continue;
          }

          let localHour: number;
          let localDate: string;
          try {
            const parts = new Intl.DateTimeFormat('en-CA', {
              timeZone: timezone,
              hourCycle: 'h23',
              year: 'numeric',
              month: '2-digit',
              day: '2-digit',
              hour: '2-digit',
            }).formatToParts(now);
            const get = (type: string) =>
              parts.find((part) => part.type === type)?.value ?? '';

            localHour = Number(get('hour'));
            localDate = `${get('year')}-${get('month')}-${get('day')}`;
          } catch {
            skipped += 1;
            continue;
          }

          const lang = resolveUserLang(data);
          const vars = buildNotifVars(data, lang);
          const nowMs = now.getTime();
          const followupPrefs = prefs.coffeePalmFollowup;
          if (followupPrefs && followupPrefs.enabled !== false && localHour >= 10 && localHour <= 21) {
            const lastCoffee = timestampToMillis(data.lastCoffeeReadingAt);
            const lastCoffeeFollowup = timestampToMillis(data.lastCoffeeFollowupAt);
            if (
              lastCoffee &&
              nowMs - lastCoffee >= readingFollowupMs &&
              (!lastCoffeeFollowup || lastCoffeeFollowup < lastCoffee)
            ) {
              const variant = pickNotification(lang, 'coffee_followup', vars);
              const result = await sendNotificationToUser({
                uid: userDoc.id,
                title: variant.title,
                body: variant.body,
                data: {
                  type: 'coffee_followup',
                  route: '/coffee',
                },
              });

              if (result.tokenCount > 0) {
                await userDoc.ref.set(
                  {
                    lastCoffeeFollowupAt: FieldValue.serverTimestamp(),
                    updatedAt: FieldValue.serverTimestamp(),
                  },
                  { merge: true }
                );
                sent += 1;
              }
            }

            const lastPalm = timestampToMillis(data.lastPalmReadingAt);
            const lastPalmFollowup = timestampToMillis(data.lastPalmFollowupAt);
            if (
              lastPalm &&
              nowMs - lastPalm >= readingFollowupMs &&
              (!lastPalmFollowup || lastPalmFollowup < lastPalm)
            ) {
              const variant = pickNotification(lang, 'palm_followup', vars);
              const result = await sendNotificationToUser({
                uid: userDoc.id,
                title: variant.title,
                body: variant.body,
                data: {
                  type: 'palm_followup',
                  route: '/palm',
                },
              });

              if (result.tokenCount > 0) {
                await userDoc.ref.set(
                  {
                    lastPalmFollowupAt: FieldValue.serverTimestamp(),
                    updatedAt: FieldValue.serverTimestamp(),
                  },
                  { merge: true }
                );
                sent += 1;
              }
            }
          }

          const dailyCard = prefs.dailyCard;
          if (!dailyCard || dailyCard.enabled === false) {
            skipped += 1;
            continue;
          }

          const hourLocal = Number.isInteger(dailyCard.hourLocal)
            ? dailyCard.hourLocal
            : 9;

          if (localHour !== hourLocal) {
            skipped += 1;
            continue;
          }

          if (data.lastDailyCardSent === localDate) {
            skipped += 1;
            continue;
          }

          const variant = pickNotification(lang, 'daily_card', vars);

          const result = await sendNotificationToUser({
            uid: userDoc.id,
            title: variant.title,
            body: variant.body,
            data: {
              type: 'daily_card',
              route: '/daily',
            },
          });

          if (result.tokenCount > 0) {
            await userDoc.ref.set(
              {
                lastDailyCardSent: localDate,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
            sent += 1;
          } else {
            skipped += 1;
          }
        } catch (error) {
          failed += 1;
          logger.warn('sendDailyCardNudges failed for user', {
            uid: userDoc.id,
            error,
          });
        }
      }

      cursor = snap.docs[snap.docs.length - 1];
    }

    logger.info('sendDailyCardNudges completed', {
      scanned,
      sent,
      skipped,
      failed,
    });
  }
);

export const cleanupUnverifiedAccounts = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: process.env.DAILY_NUDGE_TIMEZONE ?? 'Europe/Istanbul',
    timeoutSeconds: 300,
  },
  async () => {
    const nowMs = Date.now();
    const ttlMs = Math.max(1, unverifiedAccountTtlHours) * 60 * 60 * 1000;
    let deleted = 0;
    let skipped = 0;
    let failed = 0;

    const pendingSnap = await db
      .collection('users')
      .where('accountStatus', '==', 'pending_email_verification')
      .where('cleanupEligible', '==', true)
      .where('emailVerified', '==', false)
      .where('provider', '==', 'password')
      .limit(250)
      .get();

    for (const userSnap of pendingSnap.docs) {
      const data = userSnap.data() as UserDoc & Record<string, unknown>;
      const uid = String(data.uid || userSnap.id);
      const createdAtMs = timestampToMillis(data.createdAt);
      const deadlineMs = timestampToMillis(data.verificationDeadlineAt)
        ?? (createdAtMs !== null ? createdAtMs + ttlMs : null);

      if (deadlineMs === null || deadlineMs > nowMs) {
        skipped += 1;
        continue;
      }

      try {
        let authEmailVerified = false;
        try {
          const authUser = await getAuth().getUser(uid);
          authEmailVerified = authUser.emailVerified === true;
        } catch (error: unknown) {
          if (errorCode(error) !== 'auth/user-not-found') {
            throw error;
          }
        }

        if (authEmailVerified) {
          await userSnap.ref.set({
            emailVerified: true,
            accountStatus: 'pending_onboarding',
            cleanupEligible: false,
            emailVerifiedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, { merge: true });
          skipped += 1;
          continue;
        }

        await userSnap.ref.set({
          accountStatus: 'deleted',
          deletedReason: 'email_verification_timeout',
          deletedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        await deleteAuthUserIfExists(uid);
        await db.recursiveDelete(userSnap.ref);
        deleted += 1;
      } catch (error) {
        failed += 1;
        logger.warn('cleanupUnverifiedAccounts failed for user', { uid, error });
      }
    }

    logger.info('cleanupUnverifiedAccounts completed', {
      deleted,
      skipped,
      failed,
    });
  }
);

export const cleanupCoffeeArtifacts = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: process.env.DAILY_NUDGE_TIMEZONE ?? 'Europe/Istanbul',
    timeoutSeconds: 300,
  },
  async () => {
    const nowMs = Date.now();
    let releasedReservations = 0;
    let deletedExpiredReadingImages = 0;
    let deletedOrphanImages = 0;

    const expiredReservations = await db
      .collectionGroup('coffee_reservations')
      .where('expiresAtMs', '<=', nowMs)
      .limit(250)
      .get();
    for (const reservationSnap of expiredReservations.docs) {
      const reservation = reservationSnap.data() as CoffeeReservationDoc;
      if (reservation.status !== 'processing') {
        await reservationSnap.ref.set({
          expiresAtMs: null,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        continue;
      }
      const userRef = reservationSnap.ref.parent.parent;
      if (!userRef) continue;
      await releaseCoffeeReservation({
        userRef,
        reservationRef: reservationSnap.ref,
        idempotencyRef: userRef.collection('idempotency').doc(`coffee_${reservation.idempotencyKey}`),
      });
      await reservationSnap.ref.set({
        status: 'expired',
        expiresAtMs: null,
        releasedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      releasedReservations += 1;
    }

    const expiredReadings = await db
      .collectionGroup('coffee_readings')
      .where('retentionExpiresAtMs', '<=', nowMs)
      .limit(250)
      .get();
    for (const readingSnap of expiredReadings.docs) {
      const reading = readingSnap.data() as {
        uid?: string;
        imageRefs?: Partial<CoffeeImageRefs>;
        imagesDeletedAt?: unknown;
        retentionExpiresAtMs?: unknown;
      };
      if (reading.imagesDeletedAt || !reading.imageRefs) {
        await readingSnap.ref.update({
          retentionExpiresAtMs: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
        continue;
      }
      await deleteCoffeeImages(reading.imageRefs);
      await readingSnap.ref.update({
        imagesDeletedAt: FieldValue.serverTimestamp(),
        retentionExpiresAtMs: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      deletedExpiredReadingImages += 1;
    }

    const [coffeeFiles] = await storage.bucket().getFiles({
      prefix: 'coffee/',
      maxResults: 500,
    });
    for (const file of coffeeFiles) {
      const match = file.name.match(/^coffee\/([^/]+)\/(coffee_[0-9]+)\/(cupInside|saucer|cupSide)\.jpg$/);
      if (!match) continue;
      const [metadata] = await file.getMetadata();
      const createdAtMs = Date.parse(String(metadata.timeCreated ?? ''));
      const retentionUntilMs = Date.parse(String(metadata.metadata?.coffeeRetentionUntil ?? ''));
      if (Number.isFinite(retentionUntilMs) && retentionUntilMs <= nowMs) {
        await file.delete({ ignoreNotFound: true });
        deletedExpiredReadingImages += 1;
        continue;
      }
      if (!Number.isFinite(createdAtMs) || nowMs - createdAtMs < coffeeOrphanGraceMs) {
        continue;
      }

      const ownerReading = await db
        .collection('users')
        .doc(match[1])
        .collection('coffee_readings')
        .where('uploadId', '==', match[2])
        .limit(1)
        .get();
      if (ownerReading.empty) {
        await file.delete({ ignoreNotFound: true });
        deletedOrphanImages += 1;
      }
    }

    logger.info('cleanupCoffeeArtifacts completed', {
      releasedReservations,
      deletedExpiredReadingImages,
      deletedOrphanImages,
    });
  }
);

export const analyzePalmReading = onCall({ enforceAppCheck: false, secrets: ['GEMINI_API_KEY'] }, async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const uid = request.auth.uid;
    requireAppCheckIfEnabled(request);
    const imageBase64 = sanitizeBase64Image(request.data?.imageBase64, 6_000_000);
    if (!imageBase64 || imageBase64.length < 100) {
      throw new HttpsError('invalid-argument', 'INVALID_PALM_IMAGE_INPUT');
    }

    let buffer: Buffer;
    try {
      buffer = Buffer.from(imageBase64, 'base64');
    } catch {
      throw new HttpsError('invalid-argument', 'INVALID_PALM_IMAGE_INPUT');
    }
    if (buffer.length > 4 * 1024 * 1024) {
      throw new HttpsError('invalid-argument', 'PALM_IMAGE_TOO_LARGE');
    }
    if (buffer.length < 4_000) {
      throw new HttpsError('invalid-argument', 'PALM_IMAGE_TOO_SMALL');
    }

    const lang = resolveLanguage(request.data?.lang);
    const mimeType = sanitizeShortText(request.data?.mimeType, 32) || 'image/jpeg';
    const preValidated = request.data?.preValidated === true;
    const userRef = db.collection('users').doc(uid);
    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError('not-found', 'USER_NOT_FOUND');
      }
      const user = userSnap.data() as UserDoc & {
        palmThrottle?: {
          windowStartedAtMs?: number;
          windowCount?: number;
          dayKey?: string;
          dayCount?: number;
        };
      };
      const nowMs = Date.now();
      const throttle = checkAndBumpThrottle({
        throttle: user.palmThrottle,
        nowMs,
        windowMs: readingThrottleWindowMs,
        windowLimit: readingWindowLimit,
        dailyLimit: readingDailyLimit,
        dayKey: coffeeDayKey(nowMs),
      });
      if (!throttle.allowed) {
        throw new HttpsError('resource-exhausted', 'RATE_LIMITED');
      }
      tx.update(userRef, {
        palmThrottle: throttle.next,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const analysis = await analyzePalmWithGemini({
      imageBase64,
      mimeType,
      lang,
      preValidated
    });

    if (!analysis.isValid || !analysis.reading) {
      throw new HttpsError(
        'failed-precondition',
        analysis.rejectionCode ?? 'NOT_A_PALM'
      );
    }

    await userRef.set(
      {
        lastPalmReadingAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      isValid: true,
      reading: analysis.reading
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
