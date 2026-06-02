export function arisSpreadSystemRules(lang: string): string {
  return [
    'You are Bilge Aris, a mystical but grounded tarot guide.',
    'Your name is exactly Bilge Aris. Never rename yourself or use another persona.',
    'Tarot card names are canonical English labels; do not rename or translate card names.',
    'You MUST ground every answer in the user\'s selected tarot spread only.',
    'Never write generic horoscope text, filler, or vague advice that could apply without these cards.',
    'You MUST mention each selected card by its exact listed name when interpreting the spread.',
    'Do not invent cards that were not selected.',
    'Do not mention that you are an AI.',
    'No markdown, emojis, or bullet lists.',
    'No medical, legal, or financial directives; no deterministic predictions or exact dates.',
    `Response language must be strictly: ${lang}.`
  ].join(' ');
}

export function isOffTopicArisMessage(message: string): boolean {
  const normalized = message.trim().toLowerCase();
  if (normalized.length < 3) return false;

  const tarotAnchored =
    /\b(kart|tarot|yayilim|yayılım|spread|ask|aşk|love|kariyer|career|iliski|ilişki|relationship|para|money|karar|decision|gelecek|future|ruh|spirit|enerji|energy|yorum|reading|hanged|hermit|fool|magician|empress|emperor|hierophant|lovers|chariot|strength|wheel|justice|temperance|devil|tower|star|moon|sun|judgement|world|death)\b/i.test(
      message
    );
  if (tarotAnchored) return false;

  const offTopic =
    /\b(hava durumu|weather|maç|mac skor|futbol|basket|dizi|film oner|film öner|yemek tarifi|recipe|kod yaz|python|javascript|odev|homework|matematik|kimya|borsa analiz|hisse|kripto analiz|siyaset|politik|secim|seçim|unlu|ünlü|dedikodu|gossip|espri|joke|fıkra|fikra|şaka|saka)\b/i.test(
      normalized
    )
    || /\b(write code|fix my code|weather today|football score|movie recommendation|recipe for|stock price|crypto price|politics|election|celebrity gossip)\b/i.test(
      normalized
    );

  return offTopic;
}

export function offTopicArisReply(lang: string): string {
  if (lang === 'tr') {
    return [
      'Bu soru sectigin tarot yayiliminin disinda kaliyor.',
      'Bilge Aris yalnizca sectigin kartlarin isigiyla baglantili konularda eslik edebilir.',
      'Ornegin ask, kariyer, ic yolculuk veya bir karar uzerine, kartlarini merkeze alarak sorabilirsin.'
    ].join(' ');
  }
  return [
    'That question falls outside your selected tarot spread.',
    'Bilge Aris can only respond through the light of the cards you chose.',
    'You may ask about love, career, inner journey, or a decision while keeping the spread at the center.'
  ].join(' ');
}
