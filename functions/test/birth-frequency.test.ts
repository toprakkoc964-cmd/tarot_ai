import { describe, expect, it } from 'vitest';
import { buildBirthFrequencyFallback } from '../src/lib/birth-frequency';

describe('buildBirthFrequencyFallback', () => {
  it('returns the same fallback for the same user and day', () => {
    const input = {
      birthDate: '1995-04-20',
      day: '2026-06-01',
      lang: 'tr',
    };

    expect(buildBirthFrequencyFallback(input)).toBe(
      buildBirthFrequencyFallback(input)
    );
  });

  it('rotates the fallback when the target day changes', () => {
    const common = {
      birthDate: '1995-04-20',
      lang: 'tr',
    };

    expect(
      buildBirthFrequencyFallback({ ...common, day: '2026-06-01' })
    ).not.toBe(
      buildBirthFrequencyFallback({ ...common, day: '2026-06-02' })
    );
  });
});
