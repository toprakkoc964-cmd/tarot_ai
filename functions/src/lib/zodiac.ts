export function zodiacFromBirthDate(isoBirthDate: string): string {
  const [year, month, day] = isoBirthDate.split('-').map(Number);
  if (!year || !month || !day) {
    throw new Error('INVALID_BIRTH_DATE');
  }

  const mmdd = month * 100 + day;
  if (mmdd >= 321 && mmdd <= 419) return 'Aries';
  if (mmdd >= 420 && mmdd <= 520) return 'Taurus';
  if (mmdd >= 521 && mmdd <= 620) return 'Gemini';
  if (mmdd >= 621 && mmdd <= 722) return 'Cancer';
  if (mmdd >= 723 && mmdd <= 822) return 'Leo';
  if (mmdd >= 823 && mmdd <= 922) return 'Virgo';
  if (mmdd >= 923 && mmdd <= 1022) return 'Libra';
  if (mmdd >= 1023 && mmdd <= 1121) return 'Scorpio';
  if (mmdd >= 1122 && mmdd <= 1221) return 'Sagittarius';
  if (mmdd >= 1222 || mmdd <= 119) return 'Capricorn';
  if (mmdd >= 120 && mmdd <= 218) return 'Aquarius';
  return 'Pisces';
}
