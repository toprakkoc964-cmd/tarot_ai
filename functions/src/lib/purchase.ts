import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  Environment,
  SignedDataVerifier
} from '@apple/app-store-server-library';

type AppleProductType = 'consumable_credit' | 'monthly_premium' | 'unknown';

export interface ApplePurchaseValidation {
  isValid: boolean;
  productType: AppleProductType;
  creditsToGrant: number;
  premiumBonusCredits: number;
  verifiedTransactionId?: string;
  verifiedOriginalTransactionId?: string;
  productId?: string;
  expiresDate?: number;
  environment?: string;
}

const iosBundleId = process.env.IOS_BUNDLE_ID ?? 'com.tarotai';
const appAppleId = Number(process.env.APP_APPLE_ID ?? '6760354719');

const productCreditsMap: Record<string, number> = {
  'tarotai.jeton.50': 50,
  'tarotai.credits.250': 250,
  'tarotai.credits.1000': 1000
};

const premiumProductId = 'tarotai.premium.monthly';
const appleRootCertificateFiles = [
  'AppleIncRootCertificate.cer',
  'AppleRootCA-G2.cer',
  'AppleRootCA-G3.cer'
];

let cachedAppleRootCertificates: Buffer[] | null = null;

function appleRootCertificates(): Buffer[] {
  if (cachedAppleRootCertificates) return cachedAppleRootCertificates;
  const certDir = join(process.cwd(), 'certs');
  cachedAppleRootCertificates = appleRootCertificateFiles.map((fileName) =>
    readFileSync(join(certDir, fileName))
  );
  return cachedAppleRootCertificates;
}

function verifiers(): SignedDataVerifier[] {
  const roots = appleRootCertificates();
  return [
    new SignedDataVerifier(
      roots,
      true,
      Environment.PRODUCTION,
      iosBundleId,
      appAppleId
    ),
    new SignedDataVerifier(roots, true, Environment.SANDBOX, iosBundleId)
  ];
}

function invalidValidation(): ApplePurchaseValidation {
  return {
    isValid: false,
    productType: 'unknown',
    creditsToGrant: 0,
    premiumBonusCredits: 0
  };
}

export async function validateAppleReceipt(input: {
  signedTransaction?: string;
  receiptData?: string;
}): Promise<ApplePurchaseValidation> {
  const signedTransaction = String(
    input.signedTransaction || input.receiptData || ''
  ).trim();
  if (!signedTransaction) return invalidValidation();

  for (const verifier of verifiers()) {
    try {
      const payload = await verifier.verifyAndDecodeTransaction(signedTransaction);
      const productId = payload.productId;
      const transactionId = payload.transactionId;
      const originalTransactionId = payload.originalTransactionId;

      if (payload.bundleId !== iosBundleId || !productId || !transactionId) {
        return invalidValidation();
      }

      if (payload.environment !== Environment.PRODUCTION &&
          payload.environment !== Environment.SANDBOX) {
        return invalidValidation();
      }

      if (productId === premiumProductId) {
        return {
          isValid: true,
          productType: 'monthly_premium',
          creditsToGrant: 0,
          premiumBonusCredits: 200,
          verifiedTransactionId: transactionId,
          verifiedOriginalTransactionId: originalTransactionId ?? transactionId,
          productId,
          expiresDate: payload.expiresDate,
          environment: String(payload.environment)
        };
      }

      const credits = productCreditsMap[productId] ?? 0;
      if (credits <= 0) return invalidValidation();

      return {
        isValid: true,
        productType: 'consumable_credit',
        creditsToGrant: credits,
        premiumBonusCredits: 0,
        verifiedTransactionId: transactionId,
        verifiedOriginalTransactionId: originalTransactionId,
        productId,
        environment: String(payload.environment)
      };
    } catch {
      // Try the other App Store environment before rejecting the transaction.
    }
  }

  return invalidValidation();
}
