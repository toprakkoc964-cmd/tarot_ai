export function buildBirthFrequencyFallback(input: {
  birthDate: string;
  day: string;
  lang: string;
}): string {
  const month = Number(input.birthDate.slice(5, 7));
  const birthDay = Number(input.birthDate.slice(8, 10));
  const targetDayMs = Date.parse(`${input.day}T00:00:00.000Z`);
  const targetDayOffset = Number.isNaN(targetDayMs)
    ? 0
    : Math.floor(targetDayMs / (24 * 60 * 60 * 1000));
  const seasonal = (month + birthDay + targetDayOffset) % 4;

  if (input.lang === 'tr') {
    const comments = [
      'Bugun ic sesin daha net duyuluyor; acele kararlar yerine sakin bir an sec ve kalbinin gercek ihtiyacini dinle.',
      'Bugun enerjin toparlanmaya acik; kucuk bir duzenleme yapmak zihnini hafifletip gunun akisini yumusatabilir.',
      'Bugun duygularin sana yol gosterebilir; bir seyi zorlamak yerine nazikce adim atmak daha iyi hissettirecek.',
      'Bugun ruhun daha sade bir ritim istiyor; kendine alan ac ve seni besleyen tek bir niyete odaklan.'
    ];
    return comments[seasonal];
  }

  const comments = [
    'Your inner voice is clearer today; choose a quiet moment and listen to what your heart truly needs before rushing.',
    'Your energy is ready to settle; one small act of order can soften your mind and make the day feel lighter.',
    'Your feelings can guide you today; instead of forcing an answer, take one gentle step toward what feels honest.',
    'Your spirit wants a simpler rhythm today; make space for yourself and focus on one intention that nourishes you.'
  ];
  return comments[seasonal];
}
