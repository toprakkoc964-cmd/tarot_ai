import { GoogleGenerativeAI, SchemaType, type Schema } from '@google/generative-ai';

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
      input.modelName ?? process.env.GEMINI_MODEL ?? 'gemini-2.5-flash-lite';
    const model = getClient().getGenerativeModel({
      model: modelName,
      systemInstruction: input.systemPrompt,
      generationConfig: input.maxOutputTokens
        ? { maxOutputTokens: input.maxOutputTokens }
        : undefined,
    });

    const result = await model.generateContent(input.userPrompt);
    const text = result.response.text().trim();
    return text || 'The cards suggest reflection and steady action.';
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`GEMINI_REQUEST_FAILED:${message}`);
  }
}

export type CoffeeAiPayload = {
  validation: {
    isValid: boolean;
    confidence: number;
    failureStep?: string | null;
    failureReason?: string | null;
    userMessage?: string | null;
    detectedIssues: string[];
    stepResults: Record<string, { isValid: boolean; reason: string }>;
  };
  reading: Record<string, string> | null;
};

const coffeeReadingFields = [
  'generalEnergy',
  'symbols',
  'saucerSigns',
  'outerCupMessage',
  'pastTrace',
  'presentMood',
  'nearFutureMessage',
  'advice',
  'disclaimer',
] as const;

const coffeeSteps = ['cupInside', 'saucer', 'cupSide'] as const;

const coffeeResponseSchema: Schema = {
  type: SchemaType.OBJECT,
  properties: {
    validation: {
      type: SchemaType.OBJECT,
      properties: {
        isValid: { type: SchemaType.BOOLEAN },
        confidence: { type: SchemaType.NUMBER },
        failureStep: { type: SchemaType.STRING, nullable: true },
        failureReason: { type: SchemaType.STRING, nullable: true },
        userMessage: { type: SchemaType.STRING, nullable: true },
        detectedIssues: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
        },
        stepResults: {
          type: SchemaType.OBJECT,
          properties: Object.fromEntries(coffeeSteps.map((step) => [
            step,
            {
              type: SchemaType.OBJECT,
              properties: {
                isValid: { type: SchemaType.BOOLEAN },
                reason: { type: SchemaType.STRING },
              },
              required: ['isValid', 'reason'],
            },
          ])),
          required: [...coffeeSteps],
        },
      },
      required: ['isValid', 'confidence', 'detectedIssues', 'stepResults'],
    },
    reading: {
      type: SchemaType.OBJECT,
      nullable: true,
      properties: Object.fromEntries(coffeeReadingFields.map((field) => [
        field,
        { type: SchemaType.STRING },
      ])),
      required: [...coffeeReadingFields],
    },
  },
  required: ['validation', 'reading'],
};

function stripJsonFence(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.startsWith('```')) {
    return trimmed.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  }
  return trimmed;
}

export function parseCoffeeAiPayload(raw: string): CoffeeAiPayload {
  const parsed = JSON.parse(stripJsonFence(raw)) as Partial<CoffeeAiPayload>;
  const validation = parsed?.validation;
  if (!validation || typeof validation.isValid !== 'boolean') {
    throw new Error('COFFEE_AI_INVALID_SCHEMA');
  }
  if (typeof validation.confidence !== 'number' ||
      !Number.isFinite(validation.confidence) ||
      validation.confidence < 0 ||
      validation.confidence > 1) {
    throw new Error('COFFEE_AI_INVALID_SCHEMA');
  }
  if (!Array.isArray(validation.detectedIssues) ||
      !validation.detectedIssues.every((issue) => typeof issue === 'string')) {
    throw new Error('COFFEE_AI_INVALID_SCHEMA');
  }
  if (!validation.stepResults || typeof validation.stepResults !== 'object') {
    throw new Error('COFFEE_AI_INVALID_SCHEMA');
  }
  for (const step of coffeeSteps) {
    const stepResult = validation.stepResults[step];
    if (!stepResult ||
        typeof stepResult.isValid !== 'boolean' ||
        typeof stepResult.reason !== 'string' ||
        stepResult.reason.trim().length === 0) {
      throw new Error('COFFEE_AI_INVALID_SCHEMA');
    }
  }

  if (validation.isValid && !parsed.reading) {
    throw new Error('COFFEE_AI_MISSING_READING');
  }
  if (!validation.isValid && parsed.reading != null) {
    throw new Error('COFFEE_AI_UNEXPECTED_READING');
  }
  if (validation.isValid) {
    for (const field of coffeeReadingFields) {
      const value = parsed.reading?.[field];
      if (typeof value !== 'string' || value.trim().length === 0) {
        throw new Error('COFFEE_AI_INVALID_READING');
      }
    }
  }

  return parsed as CoffeeAiPayload;
}

export async function createCoffeeReadingWithVision(input: {
  languageCode: string;
  images: Array<{ step: string; mimeType: string; base64: string }>;
  mood?: string;
}): Promise<CoffeeAiPayload> {
  const modelName = process.env.GEMINI_COFFEE_MODEL ?? 'gemini-2.5-flash-lite';
  const model = getClient().getGenerativeModel({
    model: modelName,
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: coffeeResponseSchema,
      maxOutputTokens: 1800,
    },
    systemInstruction: [
      'You are Madam Aris, a mystical but grounded Turkish coffee fortune guide.',
      'First validate whether the three images are suitable for coffee fortune reading.',
      'If validation fails, set validation.isValid=false and reading=null.',
      'If validation passes, produce a warm premium reading in the requested language.',
      'Never provide medical, legal, or financial advice.',
      'Never make deterministic predictions about death, illness, pregnancy, betrayal, or accidents.',
      'Do not infer sensitive personal traits.',
      'Return only JSON. No markdown.',
      'JSON shape: {"validation":{"isValid":boolean,"confidence":number,"failureStep":string|null,"failureReason":string|null,"userMessage":string|null,"detectedIssues":string[],"stepResults":{"cupInside":{"isValid":boolean,"reason":string},"saucer":{"isValid":boolean,"reason":string},"cupSide":{"isValid":boolean,"reason":string}}},"reading":object|null}',
      'failureReason must be one of: no_cup_detected, wrong_step_image, no_residue_visible, no_saucer_detected, empty_cup, image_too_blurry, image_too_dark, image_too_bright, screenshot_or_stock, screen_spoofing, duplicate_images, inappropriate_content, low_confidence, unknown',
      'If validation.isValid is true, reading must include generalEnergy, symbols, saucerSigns, outerCupMessage, pastTrace, presentMood, nearFutureMessage, advice, disclaimer as strings.',
    ].join(' '),
  });

  const parts: Array<{ text: string } | { inlineData: { mimeType: string; data: string } }> = [
    {
      text: [
        `Language: ${input.languageCode}`,
        input.mood?.trim()
          ? `User feeling before reading: ${input.mood.trim()}`
          : 'User feeling before reading: not provided.',
        'Evaluate cupInside, saucer, and cupSide images for real physical coffee cup tasseography.',
        'Reject empty cups, stock photos, screenshots, screen spoofing, duplicate images, blurry/dark/bright images, and inappropriate content.',
        'If valid, write reading sections as Madam Aris with entertainment disclaimer.',
      ].join('\n'),
    },
  ];

  for (const image of input.images) {
    parts.push({ text: `Image step: ${image.step}` });
    parts.push({
      inlineData: {
        mimeType: image.mimeType,
        data: image.base64,
      },
    });
  }

  try {
    const result = await model.generateContent(parts);
    const text = result.response.text().trim();
    return parseCoffeeAiPayload(text);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`GEMINI_REQUEST_FAILED:${message}`);
  }
}
