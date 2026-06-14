import { getFirestore } from "firebase-admin/firestore";
import { zodiacFromBirthDate } from "./zodiac";
import { NotifLang, NotifVars, normalizeLang } from "../notif-templates";

const SUPPORTED_NOTIF_LANGS = new Set(["tr", "en", "de", "es", "fr"]);

const ZODIAC_NAMES: Record<string, Partial<Record<NotifLang, string>>> = {
  Aries: {
    tr: "Koç",
    de: "Widder",
    es: "Aries",
    fr: "Bélier",
  },
  Taurus: {
    tr: "Boğa",
    de: "Stier",
    es: "Tauro",
    fr: "Taureau",
  },
  Gemini: {
    tr: "İkizler",
    de: "Zwillinge",
    es: "Géminis",
    fr: "Gémeaux",
  },
  Cancer: {
    tr: "Yengeç",
    de: "Krebs",
    es: "Cáncer",
    fr: "Cancer",
  },
  Leo: {
    tr: "Aslan",
    de: "Löwe",
    es: "Leo",
    fr: "Lion",
  },
  Virgo: {
    tr: "Başak",
    de: "Jungfrau",
    es: "Virgo",
    fr: "Vierge",
  },
  Libra: {
    tr: "Terazi",
    de: "Waage",
    es: "Libra",
    fr: "Balance",
  },
  Scorpio: {
    tr: "Akrep",
    de: "Skorpion",
    es: "Escorpio",
    fr: "Scorpion",
  },
  Sagittarius: {
    tr: "Yay",
    de: "Schütze",
    es: "Sagitario",
    fr: "Sagittaire",
  },
  Capricorn: {
    tr: "Oğlak",
    de: "Steinbock",
    es: "Capricornio",
    fr: "Capricorne",
  },
  Aquarius: {
    tr: "Kova",
    de: "Wassermann",
    es: "Acuario",
    fr: "Verseau",
  },
  Pisces: {
    tr: "Balık",
    de: "Fische",
    es: "Piscis",
    fr: "Poissons",
  },
};

export interface UserNotifContext {
  exists: boolean;
  lang: NotifLang;
  timezone?: string;
  prefs?: FirebaseFirestore.DocumentData;
  vars: NotifVars;
}

export function localizeZodiac(zodiacEn: string, lang: NotifLang): string {
  if (lang === "en") return zodiacEn;
  return ZODIAC_NAMES[zodiacEn]?.[lang] ?? zodiacEn;
}

export function firstName(name?: string): string {
  return name?.trim().split(/\s+/)[0] ?? "";
}

export function resolveUserLang(
  userData: FirebaseFirestore.DocumentData | undefined,
): NotifLang {
  const settingsLang = userData?.settings?.lang;
  const legacyLang = userData?.language;
  const candidates = [settingsLang, legacyLang]
    .filter((value): value is string => typeof value === "string")
    .map((value) => value.trim().toLowerCase())
    .filter((value) => SUPPORTED_NOTIF_LANGS.has(value));
  const candidate = candidates[0] || "tr";
  return normalizeLang(candidate);
}

export function buildNotifVars(
  userData: FirebaseFirestore.DocumentData | undefined,
  lang: NotifLang,
): NotifVars {
  const vars: NotifVars = {};
  const name = firstName(userData?.name);
  if (name) vars.name = name;

  const birthDate = userData?.birthDate;
  if (typeof birthDate === "string" && birthDate.trim().length > 0) {
    try {
      vars.zodiac = localizeZodiac(zodiacFromBirthDate(birthDate), lang);
    } catch {
      // Invalid or incomplete birth dates should not block notifications.
    }
  }

  const credits = userData?.wallet?.credits;
  if (typeof credits === "number") vars.credits = credits;

  return vars;
}

export async function getUserNotifContext(
  uid: string,
): Promise<UserNotifContext> {
  const snap = await getFirestore().collection("users").doc(uid).get();
  const data = snap.data();
  const lang = resolveUserLang(data);
  const timezone = typeof data?.timezone === "string" ? data.timezone : undefined;
  const prefs =
    data?.notificationPrefs &&
    typeof data.notificationPrefs === "object" &&
    !Array.isArray(data.notificationPrefs)
      ? data.notificationPrefs
      : undefined;

  return {
    exists: snap.exists,
    lang,
    timezone,
    prefs,
    vars: buildNotifVars(data, lang),
  };
}
