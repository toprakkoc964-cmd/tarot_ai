import { describe, expect, it } from 'vitest';
import { requireIdempotencyKey } from '../src/lib/idempotency';

describe('requireIdempotencyKey', () => {
  it('returns trimmed value when valid', () => {
    expect(requireIdempotencyKey('  abcdefghi  ')).toBe('abcdefghi');
  });

  it('throws when short', () => {
    expect(() => requireIdempotencyKey('123')).toThrowError('INVALID_IDEMPOTENCY_KEY');
  });
});
