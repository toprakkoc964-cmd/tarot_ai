import {
  GenerativeModel,
  GoogleGenerativeAI
} from '@google/generative-ai';
import { logger } from 'firebase-functions';

let client: GoogleGenerativeAI | null = null;

const languageNames: Record<string, string> = {
  tr: 'Turkish (Türkçe)',
  en: 'English',
  de: 'German (Deutsch)',
  es: 'Spanish (Español)',
  fr: 'French (Français)',
  it: 'Italian (Italiano)',
  pt: 'Portuguese (Português)'
};

function getClient(): GoogleGenerativeAI {
  if (client) return client;

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY_MISSING');
  }

  client = new GoogleGenerativeAI(apiKey);
  return client;
}

function normalizeLanguageCode(lang?: string): string {
  const normalized = (lang ?? 'en').trim().toLowerCase().split(/[-_]/)[0];
  return languageNames[normalized] ? normalized : 'en';
}

export function geminiLanguageName(lang?: string): string {
  return languageNames[normalizeLanguageCode(lang)];
}

export function strictLanguageInstruction(
  lang?: string,
  options: { oneParagraph?: boolean; short?: boolean } = {}
): string {
  const languageName = geminiLanguageName(lang);
  return [
    `Write all user-facing text ONLY in ${languageName}.`,
    'Do not add any other language, translation, bilingual block, or parenthetical equivalent.',
    options.oneParagraph ? 'Use one paragraph only.' : '',
    options.short
      ? 'Prefer 2-3 short clear sentences; avoid repetition; keep the tone mystical but understandable.'
      : ''
  ].filter(Boolean).join(' ');
}

export async function createReadingText(input: {
  systemPrompt: string;
  userPrompt: string;
  maxOutputTokens?: number;
  modelName?: string;
  lang?: string;
  languageLock?: { oneParagraph?: boolean; short?: boolean };
}): Promise<string> {
  try {
    const modelName =
      input.modelName ??
      process.env.GEMINI_TEXT_MODEL ??
      process.env.GEMINI_MODEL ??
      'gemini-2.5-flash-lite';
    logger.info('gemini_model_resolved', { fn: 'text', modelName });
    const systemInstruction = input.lang
      ? [
        input.systemPrompt,
        strictLanguageInstruction(input.lang, input.languageLock ?? {})
      ].join('\n\n')
      : input.systemPrompt;
    const model = getClient().getGenerativeModel({
      model: modelName,
      systemInstruction,
      generationConfig: {
        temperature: 0.25,
        ...(input.maxOutputTokens ? { maxOutputTokens: input.maxOutputTokens } : {})
      },
    });

    const result = await model.generateContent(input.userPrompt);
    const text = result.response.text().trim();
    return text;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`GEMINI_REQUEST_FAILED:${message}`);
  }
}

export function getGenerativeModelForVision(input: {
  modelName?: string;
  maxOutputTokens?: number;
}): GenerativeModel {
  const modelName =
    input.modelName ??
    process.env.GEMINI_VISION_MODEL ??
    process.env.GEMINI_MODEL ??
    'gemini-2.5-flash-lite';
  logger.info('gemini_model_resolved', { fn: 'vision', modelName });
  return getClient().getGenerativeModel({
    model: modelName,
    generationConfig: {
      temperature: 0.35,
      maxOutputTokens: input.maxOutputTokens ?? 600
    }
  });
}
