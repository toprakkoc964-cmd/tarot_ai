import { HttpsError } from 'firebase-functions/v2/https';

export function mapError(err: unknown): HttpsError {
  if (err instanceof HttpsError) return err;

  if (err instanceof Error) {
    if (err.message === 'OPENAI_API_KEY_MISSING') {
      return new HttpsError('failed-precondition', 'OPENAI_API_KEY_MISSING');
    }
    if (err.message.startsWith('OPENAI_REQUEST_FAILED')) {
      return new HttpsError('unavailable', err.message);
    }
    if (err.message === 'EMPTY_BIRTH_FREQUENCY_COMMENT') {
      return new HttpsError('internal', 'EMPTY_BIRTH_FREQUENCY_COMMENT');
    }
    if (err.message === 'PROFILE_INCOMPLETE') {
      return new HttpsError('failed-precondition', 'PROFILE_INCOMPLETE');
    }
    if (err.message === 'INSUFFICIENT_CREDITS') {
      return new HttpsError('failed-precondition', 'INSUFFICIENT_CREDITS');
    }
    if (err.message === 'INVALID_IDEMPOTENCY_KEY') {
      return new HttpsError('invalid-argument', 'INVALID_IDEMPOTENCY_KEY');
    }
    if (err.message === 'APP_CHECK_REQUIRED') {
      return new HttpsError('failed-precondition', 'APP_CHECK_REQUIRED');
    }
  }

  return new HttpsError('internal', 'AI_TEMPORARY_FAILURE');
}
