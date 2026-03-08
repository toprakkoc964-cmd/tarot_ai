import { describe, expect, it } from 'vitest';
import { zodiacFromBirthDate } from '../src/lib/zodiac';

describe('zodiacFromBirthDate', () => {
  it('returns Taurus for boundary date', () => {
    expect(zodiacFromBirthDate('1995-04-20')).toBe('Taurus');
  });

  it('returns Capricorn for january date', () => {
    expect(zodiacFromBirthDate('1990-01-15')).toBe('Capricorn');
  });

  it('throws on malformed date', () => {
    expect(() => zodiacFromBirthDate('wrong')).toThrowError('INVALID_BIRTH_DATE');
  });
});
