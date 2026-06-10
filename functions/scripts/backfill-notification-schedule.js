const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const admin = require('firebase-admin');

const projectId = process.env.GCLOUD_PROJECT || process.env.PROJECT_ID || 'tarot-ai-dev-8f9a0';
const fallbackTimezone = process.env.DAILY_NUDGE_TIMEZONE || 'Europe/Istanbul';
const defaultDailyHour = 9;
const readingFollowupMs = 48 * 60 * 60 * 1000;

function normalizeDailyHour(value) {
  const numberValue = Number(value);
  return Number.isInteger(numberValue) && numberValue >= 0 && numberValue <= 23
    ? numberValue
    : defaultDailyHour;
}

function resolveTimezone(value) {
  const candidate = typeof value === 'string' && value.trim() ? value.trim() : fallbackTimezone;
  try {
    new Intl.DateTimeFormat('en-CA', { timeZone: candidate }).format(new Date());
    return candidate;
  } catch {
    return fallbackTimezone;
  }
}

function zonedDateParts(instant, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(instant);
  const get = (type) => Number(parts.find((part) => part.type === type)?.value || '0');
  return {
    year: get('year'),
    month: get('month'),
    day: get('day'),
    hour: get('hour'),
    minute: get('minute'),
    second: get('second'),
  };
}

function zonedWallTimeToUtcMs(timeZone, year, month, day, hour, minute = 0, second = 0) {
  const targetLocalMs = Date.UTC(year, month - 1, day, hour, minute, second, 0);
  let guessMs = targetLocalMs;

  for (let i = 0; i < 4; i += 1) {
    const rendered = zonedDateParts(new Date(guessMs), timeZone);
    const renderedLocalMs = Date.UTC(
      rendered.year,
      rendered.month - 1,
      rendered.day,
      rendered.hour,
      rendered.minute,
      rendered.second,
      0
    );
    const delta = renderedLocalMs - targetLocalMs;
    if (delta === 0) break;
    guessMs -= delta;
  }

  return guessMs;
}

function computeNextDailyCardAt(timezone, hourLocal, fromInstant) {
  const timeZone = resolveTimezone(timezone);
  const targetHour = normalizeDailyHour(hourLocal);
  const localNow = zonedDateParts(fromInstant, timeZone);
  let candidateMs = zonedWallTimeToUtcMs(
    timeZone,
    localNow.year,
    localNow.month,
    localNow.day,
    targetHour
  );

  if (candidateMs <= fromInstant.getTime()) {
    candidateMs = zonedWallTimeToUtcMs(
      timeZone,
      localNow.year,
      localNow.month,
      localNow.day + 1,
      targetHour
    );
  }

  return new Date(candidateMs);
}

function readMillis(value) {
  if (!value) return null;
  if (value instanceof Date) return value.getTime();
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function canReceiveScheduledNotifications(data) {
  return data?.isProfileComplete === true;
}

function notificationPrefsEnabled(data) {
  const prefs = data?.notificationPrefs;
  return Boolean(prefs) && prefs.enabled !== false;
}

function dailyCardPrefsEnabled(data) {
  return notificationPrefsEnabled(data) && data.notificationPrefs?.dailyCard?.enabled !== false;
}

function followupPrefsEnabled(data) {
  return notificationPrefsEnabled(data) && data.notificationPrefs?.coffeePalmFollowup?.enabled !== false;
}

function computeSchedule(data, now) {
  const dailyHour = data.notificationPrefs?.dailyCard?.hourLocal;
  const lastCoffeeMs = readMillis(data.lastCoffeeReadingAt);
  const lastPalmMs = readMillis(data.lastPalmReadingAt);

  return {
    nextDailyCardAt:
      canReceiveScheduledNotifications(data) && dailyCardPrefsEnabled(data)
        ? computeNextDailyCardAt(data.timezone, dailyHour, now)
        : null,
    coffeeFollowupAt:
      canReceiveScheduledNotifications(data) && followupPrefsEnabled(data) && lastCoffeeMs
        ? new Date(lastCoffeeMs + readingFollowupMs)
        : null,
    palmFollowupAt:
      canReceiveScheduledNotifications(data) && followupPrefsEnabled(data) && lastPalmMs
        ? new Date(lastPalmMs + readingFollowupMs)
        : null,
  };
}

function loadFirebaseCliToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  try {
    const raw = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    return raw.tokens?.access_token || raw.user?.tokens?.access_token || null;
  } catch {
    return null;
  }
}

async function backfillWithAdminSdk() {
  admin.initializeApp({ projectId });
  const db = admin.firestore();
  let cursor = null;
  let processed = 0;
  let updated = 0;

  while (true) {
    let query = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(300);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      processed += 1;
      const schedule = computeSchedule(doc.data(), new Date());
      batch.set(doc.ref, schedule, { merge: true });
      updated += 1;
    }
    await batch.commit();
    cursor = snap.docs[snap.docs.length - 1];
  }

  return { processed, updated };
}

function decodeFirestoreValue(value) {
  if (!value) return undefined;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('mapValue' in value) {
    const result = {};
    for (const [key, child] of Object.entries(value.mapValue.fields || {})) {
      result[key] = decodeFirestoreValue(child);
    }
    return result;
  }
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(decodeFirestoreValue);
  }
  return undefined;
}

function decodeDocument(doc) {
  const data = {};
  for (const [key, value] of Object.entries(doc.fields || {})) {
    data[key] = decodeFirestoreValue(value);
  }
  return data;
}

function encodeTimestampOrNull(value) {
  return value ? { timestampValue: value.toISOString() } : { nullValue: 'NULL_VALUE' };
}

async function backfillWithRest(accessToken) {
  let pageToken = '';
  let processed = 0;
  let updated = 0;
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users`;

  while (true) {
    const url = new URL(baseUrl);
    url.searchParams.set('pageSize', '300');
    if (pageToken) url.searchParams.set('pageToken', pageToken);

    const listResponse = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!listResponse.ok) {
      throw new Error(`REST list failed: ${listResponse.status} ${await listResponse.text()}`);
    }

    const body = await listResponse.json();
    for (const doc of body.documents || []) {
      processed += 1;
      const schedule = computeSchedule(decodeDocument(doc), new Date());
      const patchUrl = new URL(`https://firestore.googleapis.com/v1/${doc.name}`);
      for (const field of ['nextDailyCardAt', 'coffeeFollowupAt', 'palmFollowupAt']) {
        patchUrl.searchParams.append('updateMask.fieldPaths', field);
      }

      const patchResponse = await fetch(patchUrl, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fields: {
            nextDailyCardAt: encodeTimestampOrNull(schedule.nextDailyCardAt),
            coffeeFollowupAt: encodeTimestampOrNull(schedule.coffeeFollowupAt),
            palmFollowupAt: encodeTimestampOrNull(schedule.palmFollowupAt),
          },
        }),
      });
      if (!patchResponse.ok) {
        throw new Error(`REST patch failed: ${patchResponse.status} ${await patchResponse.text()}`);
      }
      updated += 1;
    }

    pageToken = body.nextPageToken || '';
    if (!pageToken) break;
  }

  return { processed, updated };
}

(async () => {
  try {
    const result = await backfillWithAdminSdk();
    console.log('Notification schedule backfill completed with Admin SDK:', result);
    process.exit(0);
  } catch (error) {
    console.warn('Admin SDK backfill failed, trying Firebase CLI token REST fallback:', error.message);
  }

  const token = loadFirebaseCliToken();
  if (!token) {
    console.error('Firebase CLI access token not found. Run `firebase login` or set ADC credentials.');
    process.exit(1);
  }

  try {
    const result = await backfillWithRest(token);
    console.log('Notification schedule backfill completed with REST fallback:', result);
    process.exit(0);
  } catch (error) {
    console.error('Notification schedule backfill failed:', error);
    process.exit(1);
  }
})();
