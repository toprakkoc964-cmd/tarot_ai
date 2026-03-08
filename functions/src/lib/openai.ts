import OpenAI from 'openai';

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export async function createReadingText(input: {
  systemPrompt: string;
  userPrompt: string;
}): Promise<string> {
  const resp = await client.responses.create({
    model: process.env.OPENAI_MODEL ?? 'gpt-4o-mini',
    input: [
      { role: 'system', content: input.systemPrompt },
      { role: 'user', content: input.userPrompt }
    ],
    temperature: Number(process.env.OPENAI_TEMPERATURE ?? '0.8')
  });

  return resp.output_text || 'The cards suggest reflection and steady action.';
}
