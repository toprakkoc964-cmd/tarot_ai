import OpenAI from 'openai';

let client: OpenAI | null = null;

function getClient(): OpenAI {
  if (client) return client;

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY_MISSING');
  }

  client = new OpenAI({ apiKey });
  return client;
}

export async function createReadingText(input: {
  systemPrompt: string;
  userPrompt: string;
}): Promise<string> {
  try {
    const resp = await getClient().responses.create({
      model: process.env.OPENAI_MODEL ?? 'gpt-4o-mini',
      input: [
        { role: 'system', content: input.systemPrompt },
        { role: 'user', content: input.userPrompt }
      ],
      temperature: Number(process.env.OPENAI_TEMPERATURE ?? '0.8')
    });

    return resp.output_text || 'The cards suggest reflection and steady action.';
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`OPENAI_REQUEST_FAILED:${message}`);
  }
}
