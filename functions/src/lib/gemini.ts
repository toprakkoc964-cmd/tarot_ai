import {
  GenerativeModel,
  GoogleGenerativeAI
} from '@google/generative-ai';
import { logger } from 'firebase-functions';

let client: GoogleGenerativeAI | null = null;

function getClient(): GoogleGenerativeAI {
  if (client) return client;

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY_MISSING');
  }

  client = new GoogleGenerativeAI(apiKey);
  return client;
}

export async function createReadingText(input: {
  systemPrompt: string;
  userPrompt: string;
  maxOutputTokens?: number;
  modelName?: string;
}): Promise<string> {
  try {
    const modelName =
      input.modelName ??
      process.env.GEMINI_TEXT_MODEL ??
      process.env.GEMINI_MODEL ??
      'gemini-2.5-flash-lite';
    logger.info('gemini_model_resolved', { fn: 'text', modelName });
    const model = getClient().getGenerativeModel({
      model: modelName,
      systemInstruction: input.systemPrompt,
      generationConfig: input.maxOutputTokens
        ? { maxOutputTokens: input.maxOutputTokens }
        : undefined,
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
