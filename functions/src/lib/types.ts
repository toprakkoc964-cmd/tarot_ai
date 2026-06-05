export type UserProfile = {
  name: string;
  birthDate: string;
  birthTime?: string;
  birthCity?: string;
  occupation: string;
};

export type UserConsents = {
  privacyAcceptedAt: FirebaseFirestore.Timestamp;
  termsAcceptedAt: FirebaseFirestore.Timestamp;
  aiProcessingConsentAt: FirebaseFirestore.Timestamp;
  consentVersion: string;
};

export type UserWallet = {
  credits: number;
  isFirstFreeUsed: boolean;
  coffeeReservedCredits?: number;
};

export type UserDoc = {
  uid: string;
  isProfileComplete: boolean;
  onboardingCompleted?: boolean;
  accountStatus?: 'pending_email_verification' | 'pending_onboarding' | 'active' | 'deleted';
  email?: string;
  name?: string;
  displayName?: string;
  photoUrl?: string;
  provider?: string;
  providers?: string[];
  emailVerified?: boolean;
  providerVerified?: boolean;
  cleanupEligible?: boolean;
  verificationDeadlineAt?: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue;
  verificationResendCount?: number;
  lastVerificationResendAt?: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue | null;
  birthDate?: string;
  relationshipStatus?: string;
  lifeSpace?: string;
  interpretationTone?: string;
  focusAreas?: string[];
  personalizationEnabled?: boolean;
  profile?: UserProfile;
  consents?: UserConsents;
  wallet: UserWallet;
  settings: {
    lang: string;
    selectedPersonaId: string;
    notificationsEnabled?: boolean;
  };
  createdAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
};

export type ReadingStatus = 'pending' | 'succeeded_text' | 'succeeded_audio' | 'failed_refunded';

export type AudioStatus = 'pending' | 'processing' | 'ready' | 'failed';

export type AIPersonaDoc = {
  name: string;
  baseSystemPrompt: string;
  tone?: string;
  active: boolean;
  version: string;
};

export type ReadingDoc = {
  uid: string;
  intent: string;
  cards: string[];
  aiResponse?: string;
  audioUrl?: string;
  audioStatus?: AudioStatus;
  shareImageUrl?: string;
  shareDeepLink?: string;
  status: ReadingStatus;
  idempotencyKey: string;
  createdAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
};

export type LedgerType = 'debit' | 'refund' | 'credit';
