import { initializeApp, getApps, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

const PROJECT_ID = process.env.GCLOUD_PROJECT ?? 'demo-tarot-iap-test';
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: PROJECT_ID });
process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';

const TEST_UID = 'iap_negative_test_user';
const TEST_EMAIL = 'iap-negative-test@example.com';
const TEST_PASSWORD = 'correct-horse-battery-staple';
const STARTING_CREDITS = 100;

function authEmulatorOrigin(): string {
  return `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099'}`;
}

function functionsEmulatorOrigin(): string {
  return `http://${process.env.FUNCTIONS_EMULATOR_HOST ?? '127.0.0.1:5001'}`;
}

function callableUrl(name: string): string {
  return `${functionsEmulatorOrigin()}/${PROJECT_ID}/us-central1/${name}`;
}

async function deleteCollection(path: string): Promise<void> {
  const snap = await getFirestore().collection(path).get();
  await Promise.all(snap.docs.map((doc) => doc.ref.delete()));
}

async function resetUser(): Promise<void> {
  const db = getFirestore();
  const userRef = db.collection('users').doc(TEST_UID);
  await deleteCollection(`users/${TEST_UID}/iap_transactions`);
  await deleteCollection(`users/${TEST_UID}/credit_ledger`);
  await deleteCollection(`users/${TEST_UID}/idempotency`);
  await userRef.set(
    {
      wallet: {
        credits: STARTING_CREDITS,
        isFirstFreeUsed: false,
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function signInTestUser(): Promise<string> {
  const response = await fetch(
    `${authEmulatorOrigin()}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
        returnSecureToken: true,
      }),
    }
  );
  const payload = await response.json() as { idToken?: string; error?: unknown };
  if (!response.ok || !payload.idToken) {
    throw new Error(`Could not sign in test user: ${JSON.stringify(payload)}`);
  }
  return payload.idToken;
}

async function callFunction(
  name: string,
  idToken: string,
  data: Record<string, unknown>
): Promise<{ status: number; body: any }> {
  const response = await fetch(callableUrl(name), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ data }),
  });
  return {
    status: response.status,
    body: await response.json(),
  };
}

async function assertNoPurchaseWrites(): Promise<void> {
  const db = getFirestore();
  const user = await db.collection('users').doc(TEST_UID).get();
  expect(user.data()?.wallet?.credits).toBe(STARTING_CREDITS);
  const txs = await db
    .collection('users')
    .doc(TEST_UID)
    .collection('iap_transactions')
    .get();
  const ledger = await db
    .collection('users')
    .doc(TEST_UID)
    .collection('credit_ledger')
    .get();
  expect(txs.empty).toBe(true);
  expect(ledger.empty).toBe(true);
}

function expectPurchaseInvalid(result: { status: number; body: any }): void {
  expect(result.status).toBe(400);
  expect(result.body?.error?.status).toBe('FAILED_PRECONDITION');
  expect(result.body?.error?.message).toBe('PURCHASE_INVALID');
}

describe('iOS IAP signed transaction validation', () => {
  let idToken = '';

  beforeAll(async () => {
    const app = initializeApp({ projectId: PROJECT_ID });
    const auth = getAuth(app);
    await auth.deleteUser(TEST_UID).catch(() => undefined);
    await auth.createUser({
      uid: TEST_UID,
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      emailVerified: true,
    });
    idToken = await signInTestUser();
  });

  beforeEach(async () => {
    await resetUser();
  });

  afterAll(async () => {
    await getAuth().deleteUser(TEST_UID).catch(() => undefined);
    await getFirestore().collection('users').doc(TEST_UID).delete().catch(() => undefined);
    await Promise.all(getApps().map((app) => deleteApp(app)));
  });

  it('rejects a forged signedTransaction and does not grant claimed credits', async () => {
    const result = await callFunction('validateIosPurchase', idToken, {
      idempotencyKey: 'iap_test_1',
      signedTransaction: 'BUNU.SAHTE.JWS',
      productId: 'tarotai.credits.1000',
      transactionId: 'fake-123',
    });

    expectPurchaseInvalid(result);
    await assertNoPurchaseWrites();
  });

  it('rejects missing signedTransaction without creating purchase records', async () => {
    const result = await callFunction('validateIosPurchase', idToken, {
      idempotencyKey: 'iap_test_2',
      productId: 'tarotai.credits.1000',
      transactionId: 'fake-456',
    });

    expectPurchaseInvalid(result);
    await assertNoPurchaseWrites();
  });

  it('rejects a malformed three-part JWS-looking value', async () => {
    const result = await callFunction('validateIosPurchase', idToken, {
      idempotencyKey: 'iap_test_3',
      signedTransaction: 'eyJhbGciOiJFUzI1NiJ9.eyJwcm9kdWN0SWQiOiJ0YXJvdGFpLmNyZWRpdHMuMTAwMCJ9.deadbeef',
      productId: 'tarotai.credits.1000',
      transactionId: 'fake-789',
    });

    expectPurchaseInvalid(result);
    await assertNoPurchaseWrites();
  });

  it('ignores client-claimed product and credit fields when the JWS is forged', async () => {
    const result = await callFunction('validateIosPurchase', idToken, {
      idempotencyKey: 'iap_test_4',
      signedTransaction: 'FORGED.CLIENT.CLAIMS',
      productId: 'tarotai.credits.1000',
      transactionId: 'fake-claim',
      creditsToGrant: 1000,
    });

    expectPurchaseInvalid(result);
    await assertNoPurchaseWrites();
  });

  it('skips forged restore items without granting credits', async () => {
    const result = await callFunction('restoreIosPurchases', idToken, {
      purchases: [
        {
          signedTransaction: 'SAHTE',
          productId: 'tarotai.credits.250',
          transactionId: 'fake-r1',
        },
      ],
    });

    expect(result.status).toBe(200);
    expect(result.body?.result?.restoredCredits).toBe(0);
    await assertNoPurchaseWrites();
  });

  it('does not grant credits when a forged restore tries a preexisting transaction id', async () => {
    await getFirestore()
      .collection('users')
      .doc(TEST_UID)
      .collection('iap_transactions')
      .doc('fake-r1')
      .set({
        productId: 'tarotai.credits.250',
        transactionId: 'fake-r1',
        creditsGranted: 250,
      });

    const result = await callFunction('restoreIosPurchases', idToken, {
      purchases: [
        {
          signedTransaction: 'SAHTE',
          productId: 'tarotai.credits.250',
          transactionId: 'fake-r1',
        },
      ],
    });

    expect(result.status).toBe(200);
    expect(result.body?.result?.restoredCredits).toBe(0);
    const user = await getFirestore().collection('users').doc(TEST_UID).get();
    expect(user.data()?.wallet?.credits).toBe(STARTING_CREDITS);
    const ledger = await getFirestore()
      .collection('users')
      .doc(TEST_UID)
      .collection('credit_ledger')
      .get();
    expect(ledger.empty).toBe(true);
  });
});
