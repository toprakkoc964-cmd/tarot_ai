export function requireIdempotencyKey(key: unknown): string {
  if (typeof key !== 'string' || key.trim().length < 8) {
    throw new Error('INVALID_IDEMPOTENCY_KEY');
  }
  return key.trim();
}
