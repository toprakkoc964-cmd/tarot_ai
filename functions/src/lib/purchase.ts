export async function validateAppleReceipt(input: {
  transactionId: string;
  productId: string;
  receiptData: string;
}): Promise<{
  isValid: boolean;
  productType: 'consumable_credit' | 'monthly_premium' | 'unknown';
  creditsToGrant: number;
  premiumBonusCredits: number;
}> {
  // Placeholder validation contract for App Store Server API integration.
  // TODO: In production, verify App Store signed transaction / receipt with
  // Apple's App Store Server API before returning isValid=true.
  // Never grant entitlements from Flutter-side purchase state alone.
  if (!input.transactionId || !input.productId || !input.receiptData) {
    return {
      isValid: false,
      productType: 'unknown',
      creditsToGrant: 0,
      premiumBonusCredits: 0
    };
  }

  const productCreditsMap: Record<string, number> = {
    'tarotai.jeton.50': 50,
    'tarotai.credits.250': 250,
    'tarotai.credits.1000': 1000
  };

  if (input.productId === 'tarotai.premium.monthly') {
    return {
      isValid: true,
      productType: 'monthly_premium',
      creditsToGrant: 0,
      premiumBonusCredits: 200
    };
  }

  const credits = productCreditsMap[input.productId] ?? 0;

  return {
    isValid: credits > 0,
    productType: credits > 0 ? 'consumable_credit' : 'unknown',
    creditsToGrant: credits,
    premiumBonusCredits: 0
  };
}
