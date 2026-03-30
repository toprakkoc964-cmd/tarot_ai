import OpenAI from 'openai';

let client: OpenAI | null = null;

function getClient(): OpenAI {
  if (client) return client;

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY is missing');
  }

  client = new OpenAI({ apiKey });
  return client;
}

export async function createReadingText(input: {
  systemPrompt: string;
  userPrompt: string;
}): Promise<string> {
  const resp = await getClient().responses.create({
    model: process.env.OPENAI_MODEL ?? 'gpt-4o-mini',
    input: [
      { role: 'system', content: input.systemPrompt },
      { role: 'user', content: input.userPrompt }
    ],
    temperature: Number(process.env.OPENAI_TEMPERATURE ?? '0.8')
  });

  return resp.output_text || 'The cards suggest reflection and steady action.';
}
