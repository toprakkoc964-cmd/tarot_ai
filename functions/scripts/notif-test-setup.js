const fs = require('fs');
const os = require('os');
const path = require('path');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'tarot-ai-dev-8f9a0' });

const db = admin.firestore();

const PROJECT_ID = 'tarot-ai-dev-8f9a0';
const UID = '4CRymf3YjYQ8vU2WUTLOwPQqcIn1';
const TZ = 'Europe/Istanbul';
const threeDaysAgo = admin.firestore.Timestamp.fromMillis(
  Date.now() - 3 * 864e5
);

const istHour = Number(
  new Intl.DateTimeFormat('en-CA', {
    timeZone: TZ,
    hour: '2-digit',
    hourCycle: 'h23',
  })
    .formatToParts(new Date())
    .find((part) => part.type === 'hour').value
);

(async () => {
  try {
    await setupWithAdminSdk();
  } catch (error) {
    if (!String(error?.message ?? error).includes('default credentials')) {
      throw error;
    }

    console.warn('Admin SDK credentials yok; Firebase CLI token fallback kullaniliyor.');
    await setupWithFirestoreRest();
  }

  process.exit(0);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});

async function setupWithAdminSdk() {
  const ref = db.collection('users').doc(UID);
  const snap = await ref.get();
  const data = snap.data() || {};

  const inline = Array.isArray(data.fcmTokens) ? data.fcmTokens.length : 0;
  const sub = (await ref.collection('fcm_tokens').get()).size;
  console.log(
    'FCM tokens -> inline:',
    inline,
    'subcollection:',
    sub,
    '| istHour:',
    istHour
  );

  await ref.set(
    {
      timezone: TZ,
      notificationPrefs: {
        enabled: true,
        dailyCard: { enabled: true, hourLocal: istHour },
        coffeePalmFollowup: { enabled: true },
        walletOffers: { enabled: true },
      },
      lastCoffeeReadingAt: threeDaysAgo,
      lastPalmReadingAt: threeDaysAgo,
      lastCoffeeFollowupAt: admin.firestore.FieldValue.delete(),
      lastPalmFollowupAt: admin.firestore.FieldValue.delete(),
      lastDailyCardSent: admin.firestore.FieldValue.delete(),
      walletLowNotified: false,
    },
    { merge: true }
  );

  const cur = Number(data.wallet?.credits ?? 0);
  const target = cur === 5 ? 4 : 5;
  await ref.update({ 'wallet.credits': target });

  console.log('Kurulum tamam. credits:', cur, '->', target);
}

async function setupWithFirestoreRest() {
  const accessToken = readFirebaseCliAccessToken();
  const doc = await firestoreRequest(accessToken, documentUrl());
  const fields = doc.fields || {};
  const data = decodeFirestoreFields(fields);

  const inline = Array.isArray(data.fcmTokens) ? data.fcmTokens.length : 0;
  const tokensList = await firestoreRequest(
    accessToken,
    `${documentUrl()}/fcm_tokens`
  ).catch(() => ({ documents: [] }));
  const sub = Array.isArray(tokensList.documents) ? tokensList.documents.length : 0;
  console.log(
    'FCM tokens -> inline:',
    inline,
    'subcollection:',
    sub,
    '| istHour:',
    istHour
  );

  await firestorePatch(
    accessToken,
    documentUrl(),
    {
      timezone: stringValue(TZ),
      notificationPrefs: mapValue({
        enabled: booleanValue(true),
        dailyCard: mapValue({
          enabled: booleanValue(true),
          hourLocal: integerValue(istHour),
        }),
        coffeePalmFollowup: mapValue({ enabled: booleanValue(true) }),
        walletOffers: mapValue({ enabled: booleanValue(true) }),
      }),
      lastCoffeeReadingAt: timestampValue(threeDaysAgo.toDate().toISOString()),
      lastPalmReadingAt: timestampValue(threeDaysAgo.toDate().toISOString()),
      walletLowNotified: booleanValue(false),
    },
    [
      'timezone',
      'notificationPrefs',
      'lastCoffeeReadingAt',
      'lastPalmReadingAt',
      'lastCoffeeFollowupAt',
      'lastPalmFollowupAt',
      'lastDailyCardSent',
      'walletLowNotified',
    ]
  );

  const cur = Number(data.wallet?.credits ?? 0);
  const target = cur === 5 ? 4 : 5;
  await firestorePatch(
    accessToken,
    documentUrl(),
    {
      wallet: mapValue({
        credits: integerValue(target),
      }),
    },
    ['wallet.credits']
  );

  console.log('Kurulum tamam. credits:', cur, '->', target);
}

function readFirebaseCliAccessToken() {
  const configPath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json'
  );
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = config.tokens?.access_token;
  if (!token) {
    throw new Error('Firebase CLI access token bulunamadi.');
  }
  return token;
}

function documentUrl() {
  return `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${UID}`;
}

async function firestoreRequest(accessToken, url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Firestore REST hata ${response.status}: ${body}`);
  }

  return response.json();
}

async function firestorePatch(accessToken, url, fields, updateMask) {
  const params = new URLSearchParams();
  updateMask.forEach((fieldPath) => params.append('updateMask.fieldPaths', fieldPath));
  return firestoreRequest(accessToken, `${url}?${params.toString()}`, {
    method: 'PATCH',
    body: JSON.stringify({ fields }),
  });
}

function decodeFirestoreFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeFirestoreValue(value)])
  );
}

function decodeFirestoreValue(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(decodeFirestoreValue);
  }
  if ('mapValue' in value) {
    return decodeFirestoreFields(value.mapValue.fields || {});
  }
  if ('nullValue' in value) return null;
  return undefined;
}

function stringValue(value) {
  return { stringValue: value };
}

function integerValue(value) {
  return { integerValue: String(value) };
}

function booleanValue(value) {
  return { booleanValue: value };
}

function timestampValue(value) {
  return { timestampValue: value };
}

function mapValue(fields) {
  return { mapValue: { fields } };
}
