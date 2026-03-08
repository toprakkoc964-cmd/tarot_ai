import { zodiacFromBirthDate } from './zodiac';
import { AIPersonaDoc, UserProfile } from './types';

export function buildSystemPrompt(
  profile: UserProfile,
  intent: string,
  lang: string,
  persona: AIPersonaDoc
): string {
  const zodiac = zodiacFromBirthDate(profile.birthDate);

  return [
    persona.baseSystemPrompt,
    `Persona: ${persona.name}, tone=${persona.tone ?? 'balanced'}, version=${persona.version}.`,
    `User context: zodiac=${zodiac}, occupation=${profile.occupation}, name=${profile.name}.`,
    `Reading intent: ${intent}.`,
    `Response language must be strictly: ${lang}.`,
    'Use compassionate tone and concrete advice tailored to profession and intent.',
    'Keep output concise, empowering, and avoid deterministic future claims.'
  ].join(' ');
}
