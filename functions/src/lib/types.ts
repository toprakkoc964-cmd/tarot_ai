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
};

export type UserDoc = {
  uid: string;
  isProfileComplete: boolean;
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
