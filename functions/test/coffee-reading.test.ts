import { describe, expect, it } from 'vitest';
import { parseCoffeeAiPayload } from '../src/lib/coffee-reading';

const validPayload = {
  validation: {
    isValid: true,
    confidence: 0.86,
    failureStep: null,
    failureReason: null,
    userMessage: null,
    detectedIssues: [],
    stepResults: {
      cupInside: { isValid: true, reason: 'residue_visible' },
      saucer: { isValid: true, reason: 'saucer_visible' },
      cupSide: { isValid: true, reason: 'cup_visible' },
    },
  },
  reading: {
    generalEnergy: 'energy',
    symbols: 'symbols',
    saucerSigns: 'saucer',
    outerCupMessage: 'outer',
    pastTrace: 'past',
    presentMood: 'present',
    nearFutureMessage: 'future',
    advice: 'advice',
    disclaimer: 'disclaimer',
  },
};

describe('parseCoffeeAiPayload', () => {
  it('accepts a complete structured reading', () => {
    expect(parseCoffeeAiPayload(JSON.stringify(validPayload))).toEqual(validPayload);
  });

  it('rejects a valid response when a reading section is empty', () => {
    const payload = structuredClone(validPayload);
    payload.reading.symbols = '';
    expect(() => parseCoffeeAiPayload(JSON.stringify(payload))).toThrow(
      'COFFEE_AI_INVALID_READING'
    );
  });

  it('requires reading to be null for invalid photos', () => {
    const payload = structuredClone(validPayload);
    payload.validation.isValid = false;
    expect(() => parseCoffeeAiPayload(JSON.stringify(payload))).toThrow(
      'COFFEE_AI_UNEXPECTED_READING'
    );
  });
});
