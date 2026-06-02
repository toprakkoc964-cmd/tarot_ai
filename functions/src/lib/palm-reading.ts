import { getGenerativeModelForVision } from './gemini';

export type PalmReadingPayload = {
  mindLine: string;
  heartLine: string;
  lifeEnergy: string;
};

export type PalmVisionAnalysis = {
  isValid: boolean;
  rejectionCode?: 'NOT_A_PALM' | 'IMAGE_UNREADABLE' | 'PALM_PARTIAL';
  reading?: PalmReadingPayload;
};

function extractJsonObject(raw: string): Record<string, unknown> {
  const trimmed = raw.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced?.[1]?.trim() ?? trimmed;
  const start = candidate.indexOf('{');
  const end = candidate.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw new Error('PALM_JSON_PARSE_FAILED');
  }
  return JSON.parse(candidate.slice(start, end + 1)) as Record<string, unknown>;
}

function sanitizeLine(value: unknown, maxLength: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\s+/g, ' ').slice(0, maxLength);
}

function normalizeAnalysis(raw: Record<string, unknown>): PalmVisionAnalysis {
  const isValid = raw.isValid === true;
  const rejectionCode = typeof raw.rejectionCode === 'string'
    ? raw.rejectionCode.trim().toUpperCase()
    : '';

  if (!isValid) {
    const code =
      rejectionCode === 'NOT_A_PALM' ||
      rejectionCode === 'IMAGE_UNREADABLE' ||
      rejectionCode === 'PALM_PARTIAL'
        ? rejectionCode
        : 'NOT_A_PALM';
    return { isValid: false, rejectionCode: code as PalmVisionAnalysis['rejectionCode'] };
  }

  const readingRaw = raw.reading;
  const readingMap =
    readingRaw && typeof readingRaw === 'object'
      ? (readingRaw as Record<string, unknown>)
      : {};

  const reading: PalmReadingPayload = {
    mindLine: sanitizeLine(readingMap.mindLine, 420),
    heartLine: sanitizeLine(readingMap.heartLine, 420),
    lifeEnergy: sanitizeLine(readingMap.lifeEnergy, 320)
  };

  if (!reading.mindLine || !reading.heartLine || !reading.lifeEnergy) {
    return { isValid: false, rejectionCode: 'IMAGE_UNREADABLE' };
  }

  return { isValid: true, reading };
}

export async function analyzePalmWithGemini(input: {
  imageBase64: string;
  mimeType: string;
  lang: string;
}): Promise<PalmVisionAnalysis> {
  const model = getGenerativeModelForVision({
    modelName: process.env.GEMINI_PALM_MODEL ?? process.env.GEMINI_MODEL ?? 'gemini-2.5-flash',
    maxOutputTokens: 720
  });

  const lang = input.lang.trim().toLowerCase();
  const systemPrompt = [
    'You are a mystical palm-reading guide for an entertainment app.',
    'Analyze ONLY the uploaded photo.',
    'If the photo is not a human palm (inner surface with lines), set isValid to false.',
    'If the palm is too blurry, dark, cropped, or lines are not visible, set isValid to false with rejectionCode IMAGE_UNREADABLE.',
    'If only fingers or back of hand is shown, set isValid to false with rejectionCode NOT_A_PALM.',
    'Never invent medical, legal, or deterministic predictions.',
    'No markdown. Respond with JSON only.',
    `Write reading text strictly in language: ${lang}.`
  ].join(' ');

  const userPrompt = [
    'Return JSON exactly in this shape:',
    '{"isValid":boolean,"rejectionCode":"NOT_A_PALM"|"IMAGE_UNREADABLE"|"PALM_PARTIAL"|null,',
    '"reading":{"mindLine":string,"heartLine":string,"lifeEnergy":string}|null}',
    'When isValid is true, provide 3-5 sentences for mindLine and heartLine each, and 2-3 sentences for lifeEnergy.',
    'Ground interpretations in visible palm lines; do not use generic horoscope filler.'
  ].join(' ');

  let text = '';
  try {
    const result = await model.generateContent([
      { text: `${systemPrompt}\n\n${userPrompt}` },
      {
        inlineData: {
          mimeType: input.mimeType,
          data: input.imageBase64
        }
      }
    ]);
    text = result.response.text().trim();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`GEMINI_REQUEST_FAILED:${message}`);
  }

  if (!text) {
    return { isValid: false, rejectionCode: 'IMAGE_UNREADABLE' };
  }

  try {
    return normalizeAnalysis(extractJsonObject(text));
  } catch {
    return { isValid: false, rejectionCode: 'IMAGE_UNREADABLE' };
  }
}
