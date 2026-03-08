import { describe, expect, it } from 'vitest';
import { buildSystemPrompt } from '../src/lib/context-builder';

describe('buildSystemPrompt', () => {
  it('embeds zodiac and occupation context', () => {
    const prompt = buildSystemPrompt(
      {
        name: 'Ayse',
        birthDate: '1992-05-01',
        occupation: 'Software Developer'
      },
      'Career',
      'tr',
      {
        name: 'Emilia',
        baseSystemPrompt: 'You are Emilia.',
        active: true,
        version: 'v1'
      }
    );

    expect(prompt).toContain('zodiac=Taurus');
    expect(prompt).toContain('occupation=Software Developer');
    expect(prompt).toContain('Reading intent: Career');
    expect(prompt).toContain('strictly: tr');
  });
});
