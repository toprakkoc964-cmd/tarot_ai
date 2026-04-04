import { GoogleGenerativeAI } from '@google/generative-ai';

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
}): Promise<string> {
  try {
    const modelName = process.env.GEMINI_MODEL ?? 'gemini-2.5-flash';
    const model = getClient().getGenerativeModel({
      model: modelName,
      systemInstruction: input.systemPrompt,
    });

    const result = await model.generateContent(input.userPrompt);
    const text = result.response.text().trim();
    return text || 'The cards suggest reflection and steady action.';
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`GEMINI_REQUEST_FAILED:${message}`);
  }
}
