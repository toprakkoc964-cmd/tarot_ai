// Çok dilli bildirim şablonları (sunucu tarafı).
// Bildirimler uygulama kapalıyken Cloud Function'dan gönderildiği için
// metinler burada tutulur ve kullanıcının diline göre seçilir.
export type NotifLang = "tr" | "en" | "de" | "es" | "fr";

export type NotifCategory =
  | "daily_card"
  | "birth_chart_fallback"
  | "coffee_followup"
  | "palm_followup"
  | "wallet_low"
  | "wallet_offer";

export interface NotifVariant {
  title: string;
  body: string;
}

interface NamedNotifVariant {
  withName: NotifVariant;
  noName: NotifVariant;
}

export interface NotifVars {
  name?: string;
  zodiac?: string;
  card?: string;
  credits?: number | string;
}

const DEFAULT_LANG: NotifLang = "en";

type NotifTemplateVariant = NotifVariant | NamedNotifVariant;
type NotifData = Record<NotifLang, Record<NotifCategory, NotifTemplateVariant[]>>;

export const NOTIF_TEMPLATES: NotifData = {
  tr: {
    daily_card: [
      {
        withName: { title: "Günaydın {name} ☀️", body: "Bugünün doğum haritası yorumu ve günün kartı hazır 🔮 Açıp keşfet ✨" },
        noName: { title: "Günaydın ☀️", body: "Bugünün doğum haritası yorumu ve günün kartı hazır 🔮 Açıp keşfet ✨" },
      },
      {
        withName: { title: "Yeni bir gün başladı 🌅", body: "{name}, yıldızların bugün ne fısıldıyor? Doğum haritası yorumun ve günün kartı seni bekliyor 🔮" },
        noName: { title: "Yeni bir gün başladı 🌅", body: "Yıldızların bugün ne fısıldıyor? Doğum haritası yorumun ve günün kartı seni bekliyor 🔮" },
      },
      {
        withName: { title: "Kartların hazır 🃏✨", body: "Günaydın {name}! Bugünün doğum haritası rehberliği ve günün kartı seni bekliyor 🌙" },
        noName: { title: "Kartların hazır 🃏✨", body: "Günaydın! Bugünün doğum haritası rehberliği ve günün kartı seni bekliyor 🌙" },
      },
    ],
    birth_chart_fallback: [
      { title: "Yıldızların bugünkü mesajı 🌙", body: "{zodiac} burcu için bugün özel bir gün. Yorumunu gör." },
      { title: "{zodiac} için günlük gök haritası ✨", body: "Gezegenler bugün senin lehine hizalanıyor, {name}. Detaylara bak." },
      { title: "Bugün gökyüzü senin için konuşuyor 🌌", body: "{name}, {zodiac} burcunun günlük yorumu hazır." },
      { title: "Evrenin {zodiac} için planı 🔭", body: "{name}, bugün seni neler bekliyor? Doğum haritası yorumuna göz at." },
      { title: "Yıldız haritan güncellendi ⭐", body: "{name}, {zodiac} enerjisi bugün güçlü. Yorumunu kaçırma." },
    ],
    coffee_followup: [
      { title: "Bir fincan daha? ☕", body: "{name}, telve yeni bir hikâye anlatmaya hazır. Canın isterse tekrar bakalım ✨" },
      { title: "Fincan seni özledi ☕", body: "{name}, yeni bir kahve falına ne dersin? Acelesi yok, sen hazır olunca 🔮" },
      { title: "Telve fısıldıyor ☕", body: "{name}, içinden geldiğinde yeni bir fala birlikte bakabiliriz 🌙" },
    ],
    palm_followup: [
      { title: "Avuçların yeni bir şey saklıyor ✋", body: "{name}, canın isterse yeni bir el falına bakabiliriz ✨" },
      { title: "Çizgilerin değişiyor olabilir 🤚", body: "{name}, tekrar el falına bakmak ister misin? Sen hazır olunca 🌙" },
    ],
    wallet_low: [
      { title: "Jetonların azalıyor ⚡", body: "{name}, {credits} jetonun kaldı. Falların yarıda kalmasın." },
      { title: "Kozmik cüzdanın boşalıyor 🪙", body: "{name}, sadece {credits} jeton kaldı. Yeniden doldur." },
      { title: "Son jetonların ⚡", body: "{name}, {credits} jetonla bir fal daha çekebilirsin. Devamı için doldur." },
      { title: "Enerjin tükenmek üzere 🔋", body: "{name}, {credits} jetonun var. Falların kesintisiz olsun." },
    ],
    wallet_offer: [
      { title: "Sana özel ✨", body: "{name}, kozmik cüzdanını doldur — jeton paketlerindeki fırsatları kaçırma." },
      { title: "Kozmik fırsat seni bekliyor 🌠", body: "{name}, jeton paketlerinde sana özel avantajlar var." },
      { title: "Daha fazla fal, daha fazla cevap 🔮", body: "{name}, jeton paketine göz at ve falların hiç bitmesin." },
      { title: "Yıldızlar cömert bugün ⭐", body: "{name}, jeton paketlerindeki tekliflere bir bak." },
    ],
  },
  en: {
    daily_card: [
      {
        withName: { title: "Good morning {name} ☀️", body: "Your daily birth chart reading and card of the day are ready 🔮 Tap to explore ✨" },
        noName: { title: "Good morning ☀️", body: "Your daily birth chart reading and card of the day are ready 🔮 Tap to explore ✨" },
      },
      {
        withName: { title: "A new day begins 🌅", body: "{name}, what are the stars whispering today? Your birth chart reading and daily card await 🔮" },
        noName: { title: "A new day begins 🌅", body: "What are the stars whispering today? Your birth chart reading and daily card await 🔮" },
      },
      {
        withName: { title: "Your cards are ready 🃏✨", body: "Good morning {name}! Today's birth chart guidance and card of the day are waiting 🌙" },
        noName: { title: "Your cards are ready 🃏✨", body: "Good morning! Today's birth chart guidance and card of the day are waiting 🌙" },
      },
    ],
    birth_chart_fallback: [
      { title: "Today's message from the stars 🌙", body: "It's a special day for {zodiac}. See your reading." },
      { title: "Daily chart for {zodiac} ✨", body: "The planets align in your favor today, {name}. Take a look." },
      { title: "The sky is speaking for you today 🌌", body: "{name}, your daily {zodiac} reading is ready." },
      { title: "The universe's plan for {zodiac} 🔭", body: "{name}, what awaits you today? Check your birth chart reading." },
      { title: "Your star chart is updated ⭐", body: "{name}, {zodiac} energy is strong today. Don't miss your reading." },
    ],
    coffee_followup: [
      { title: "One more cup? ☕", body: "{name}, the grounds have a new story. Shall we look again whenever you feel like it? ✨" },
      { title: "Your cup misses you ☕", body: "{name}, fancy a new coffee reading? No rush — whenever you're ready 🔮" },
      { title: "The grounds are whispering ☕", body: "{name}, we can explore a fresh reading whenever you feel like it 🌙" },
    ],
    palm_followup: [
      { title: "Your palms hold something new ✋", body: "{name}, we can explore a new palm reading whenever you like ✨" },
      { title: "Your lines may be shifting 🤚", body: "{name}, fancy another palm reading? Whenever you're ready 🌙" },
    ],
    wallet_low: [
      { title: "Your tokens are running low ⚡", body: "{name}, you have {credits} tokens left. Don't let your readings stop." },
      { title: "Your cosmic wallet is emptying 🪙", body: "{name}, only {credits} tokens left. Top it up." },
      { title: "Your last tokens ⚡", body: "{name}, you can draw one more reading with {credits} tokens. Refill to continue." },
      { title: "Your energy is about to run out 🔋", body: "{name}, you have {credits} tokens. Keep your readings flowing." },
    ],
    wallet_offer: [
      { title: "Just for you ✨", body: "{name}, top up your cosmic wallet — don't miss the token pack deals." },
      { title: "A cosmic deal awaits 🌠", body: "{name}, there are special perks on token packs for you." },
      { title: "More readings, more answers 🔮", body: "{name}, check out a token pack and never run out." },
      { title: "The stars are generous today ⭐", body: "{name}, take a look at the offers on token packs." },
    ],
  },
  de: {
    daily_card: [
      {
        withName: { title: "Guten Morgen {name} ☀️", body: "Deine tägliche Geburtshoroskop-Deutung und die Tageskarte sind da 🔮 Zum Entdecken tippen ✨" },
        noName: { title: "Guten Morgen ☀️", body: "Deine tägliche Geburtshoroskop-Deutung und die Tageskarte sind da 🔮 Zum Entdecken tippen ✨" },
      },
      {
        withName: { title: "Ein neuer Tag beginnt 🌅", body: "{name}, was flüstern dir die Sterne heute? Deine Geburtshoroskop-Deutung und die Tageskarte warten 🔮" },
        noName: { title: "Ein neuer Tag beginnt 🌅", body: "Was flüstern dir die Sterne heute? Deine Geburtshoroskop-Deutung und die Tageskarte warten 🔮" },
      },
      {
        withName: { title: "Deine Karten sind bereit 🃏✨", body: "Guten Morgen {name}! Die heutige Geburtshoroskop-Deutung und die Tageskarte warten auf dich 🌙" },
        noName: { title: "Deine Karten sind bereit 🃏✨", body: "Guten Morgen! Die heutige Geburtshoroskop-Deutung und die Tageskarte warten auf dich 🌙" },
      },
    ],
    birth_chart_fallback: [
      { title: "Die heutige Botschaft der Sterne 🌙", body: "Ein besonderer Tag für {zodiac}. Sieh dir deine Deutung an." },
      { title: "Tageshoroskop für {zodiac} ✨", body: "Die Planeten stehen heute günstig für dich, {name}. Schau mal rein." },
      { title: "Der Himmel spricht heute für dich 🌌", body: "{name}, deine tägliche {zodiac}-Deutung ist bereit." },
      { title: "Der Plan des Universums für {zodiac} 🔭", body: "{name}, was erwartet dich heute? Sieh dir deine Geburtshoroskop-Deutung an." },
      { title: "Deine Sternenkarte ist aktualisiert ⭐", body: "{name}, die {zodiac}-Energie ist heute stark. Verpasse deine Deutung nicht." },
    ],
    coffee_followup: [
      { title: "Noch eine Tasse? ☕", body: "{name}, der Satz hat eine neue Geschichte. Schauen wir wieder, wann immer dir danach ist ✨" },
      { title: "Deine Tasse vermisst dich ☕", body: "{name}, Lust auf eine neue Kaffeesatzdeutung? Kein Stress — wann du bereit bist 🔮" },
      { title: "Der Satz flüstert ☕", body: "{name}, wir können jederzeit eine frische Deutung machen 🌙" },
    ],
    palm_followup: [
      { title: "Deine Hände bergen Neues ✋", body: "{name}, wir können jederzeit eine neue Handlesung machen ✨" },
      { title: "Deine Linien verändern sich vielleicht 🤚", body: "{name}, Lust auf eine neue Handlesung? Wann du bereit bist 🌙" },
    ],
    wallet_low: [
      { title: "Deine Token werden knapp ⚡", body: "{name}, du hast noch {credits} Token. Lass deine Deutungen nicht stoppen." },
      { title: "Dein kosmisches Wallet leert sich 🪙", body: "{name}, nur noch {credits} Token. Lade es auf." },
      { title: "Deine letzten Token ⚡", body: "{name}, mit {credits} Token kannst du noch eine Deutung ziehen. Lade auf, um fortzufahren." },
      { title: "Deine Energie geht zur Neige 🔋", body: "{name}, du hast {credits} Token. Halte deine Deutungen am Laufen." },
    ],
    wallet_offer: [
      { title: "Nur für dich ✨", body: "{name}, lade dein kosmisches Wallet auf — verpasse die Token-Angebote nicht." },
      { title: "Ein kosmisches Angebot wartet 🌠", body: "{name}, es gibt besondere Vorteile bei den Token-Paketen für dich." },
      { title: "Mehr Deutungen, mehr Antworten 🔮", body: "{name}, sieh dir ein Token-Paket an und dir geht nie etwas aus." },
      { title: "Die Sterne sind heute großzügig ⭐", body: "{name}, wirf einen Blick auf die Angebote der Token-Pakete." },
    ],
  },
  es: {
    daily_card: [
      {
        withName: { title: "Buenos días {name} ☀️", body: "Tu lectura diaria de carta astral y la carta del día están listas 🔮 Toca para explorar ✨" },
        noName: { title: "Buenos días ☀️", body: "Tu lectura diaria de carta astral y la carta del día están listas 🔮 Toca para explorar ✨" },
      },
      {
        withName: { title: "Comienza un nuevo día 🌅", body: "{name}, ¿qué te susurran hoy las estrellas? Tu lectura de carta astral y la carta del día te esperan 🔮" },
        noName: { title: "Comienza un nuevo día 🌅", body: "¿Qué te susurran hoy las estrellas? Tu lectura de carta astral y la carta del día te esperan 🔮" },
      },
      {
        withName: { title: "Tus cartas están listas 🃏✨", body: "¡Buenos días {name}! La guía de tu carta astral de hoy y la carta del día te esperan 🌙" },
        noName: { title: "Tus cartas están listas 🃏✨", body: "¡Buenos días! La guía de tu carta astral de hoy y la carta del día te esperan 🌙" },
      },
    ],
    birth_chart_fallback: [
      { title: "El mensaje de hoy de las estrellas 🌙", body: "Es un día especial para {zodiac}. Mira tu lectura." },
      { title: "Carta diaria para {zodiac} ✨", body: "Los planetas se alinean a tu favor hoy, {name}. Échale un vistazo." },
      { title: "El cielo habla por ti hoy 🌌", body: "{name}, tu lectura diaria de {zodiac} está lista." },
      { title: "El plan del universo para {zodiac} 🔭", body: "{name}, ¿qué te espera hoy? Mira la lectura de tu carta natal." },
      { title: "Tu carta astral se ha actualizado ⭐", body: "{name}, la energía de {zodiac} es fuerte hoy. No te pierdas tu lectura." },
    ],
    coffee_followup: [
      { title: "¿Otra taza? ☕", body: "{name}, los posos tienen una nueva historia. Miremos otra vez cuando te apetezca ✨" },
      { title: "Tu taza te extraña ☕", body: "{name}, ¿te apetece una nueva lectura del café? Sin prisa, cuando quieras 🔮" },
      { title: "Los posos susurran ☕", body: "{name}, podemos explorar una nueva lectura cuando quieras 🌙" },
    ],
    palm_followup: [
      { title: "Tus palmas guardan algo nuevo ✋", body: "{name}, podemos explorar una nueva lectura de la palma cuando quieras ✨" },
      { title: "Tus líneas podrían cambiar 🤚", body: "{name}, ¿te apetece otra lectura de la palma? Cuando estés listo 🌙" },
    ],
    wallet_low: [
      { title: "Tus fichas se están agotando ⚡", body: "{name}, te quedan {credits} fichas. Que no se detengan tus lecturas." },
      { title: "Tu cartera cósmica se vacía 🪙", body: "{name}, solo quedan {credits} fichas. Recárgala." },
      { title: "Tus últimas fichas ⚡", body: "{name}, puedes sacar una lectura más con {credits} fichas. Recarga para continuar." },
      { title: "Tu energía está por agotarse 🔋", body: "{name}, tienes {credits} fichas. Mantén tus lecturas en marcha." },
    ],
    wallet_offer: [
      { title: "Solo para ti ✨", body: "{name}, recarga tu cartera cósmica — no te pierdas las ofertas de fichas." },
      { title: "Una oferta cósmica te espera 🌠", body: "{name}, hay ventajas especiales en los paquetes de fichas para ti." },
      { title: "Más lecturas, más respuestas 🔮", body: "{name}, mira un paquete de fichas y que nunca se te acaben." },
      { title: "Las estrellas son generosas hoy ⭐", body: "{name}, echa un vistazo a las ofertas de los paquetes de fichas." },
    ],
  },
  fr: {
    daily_card: [
      {
        withName: { title: "Bonjour {name} ☀️", body: "Ta lecture quotidienne de thème astral et la carte du jour sont prêtes 🔮 Touche pour explorer ✨" },
        noName: { title: "Bonjour ☀️", body: "Ta lecture quotidienne de thème astral et la carte du jour sont prêtes 🔮 Touche pour explorer ✨" },
      },
      {
        withName: { title: "Un nouveau jour commence 🌅", body: "{name}, que te murmurent les étoiles aujourd'hui ? Ta lecture de thème astral et la carte du jour t'attendent 🔮" },
        noName: { title: "Un nouveau jour commence 🌅", body: "Que te murmurent les étoiles aujourd'hui ? Ta lecture de thème astral et la carte du jour t'attendent 🔮" },
      },
      {
        withName: { title: "Tes cartes sont prêtes 🃏✨", body: "Bonjour {name} ! Les conseils de ton thème astral du jour et la carte du jour t'attendent 🌙" },
        noName: { title: "Tes cartes sont prêtes 🃏✨", body: "Bonjour ! Les conseils de ton thème astral du jour et la carte du jour t'attendent 🌙" },
      },
    ],
    birth_chart_fallback: [
      { title: "Le message des étoiles aujourd'hui 🌙", body: "C'est un jour spécial pour {zodiac}. Vois ta lecture." },
      { title: "Carte du jour pour {zodiac} ✨", body: "Les planètes s'alignent en ta faveur aujourd'hui, {name}. Jette un œil." },
      { title: "Le ciel parle pour toi aujourd'hui 🌌", body: "{name}, ta lecture quotidienne {zodiac} est prête." },
      { title: "Le plan de l'univers pour {zodiac} 🔭", body: "{name}, qu'est-ce qui t'attend aujourd'hui ? Consulte ta lecture du thème natal." },
      { title: "Ta carte du ciel est mise à jour ⭐", body: "{name}, l'énergie {zodiac} est forte aujourd'hui. Ne manque pas ta lecture." },
    ],
    coffee_followup: [
      { title: "Encore une tasse ? ☕", body: "{name}, le marc a une nouvelle histoire. On regarde à nouveau quand tu veux ✨" },
      { title: "Ta tasse te réclame ☕", body: "{name}, envie d'une nouvelle lecture du café ? Pas de précipitation, quand tu es prêt 🔮" },
      { title: "Le marc murmure ☕", body: "{name}, on peut explorer une nouvelle lecture quand tu veux 🌙" },
    ],
    palm_followup: [
      { title: "Tes paumes cachent du nouveau ✋", body: "{name}, on peut explorer une nouvelle lecture de la main quand tu veux ✨" },
      { title: "Tes lignes changent peut-être 🤚", body: "{name}, envie d'une nouvelle lecture de la main ? Quand tu es prêt 🌙" },
    ],
    wallet_low: [
      { title: "Tes jetons s'épuisent ⚡", body: "{name}, il te reste {credits} jetons. Ne laisse pas tes lectures s'arrêter." },
      { title: "Ton portefeuille cosmique se vide 🪙", body: "{name}, il ne reste que {credits} jetons. Recharge-le." },
      { title: "Tes derniers jetons ⚡", body: "{name}, tu peux tirer une lecture de plus avec {credits} jetons. Recharge pour continuer." },
      { title: "Ton énergie touche à sa fin 🔋", body: "{name}, tu as {credits} jetons. Garde tes lectures en mouvement." },
    ],
    wallet_offer: [
      { title: "Rien que pour toi ✨", body: "{name}, recharge ton portefeuille cosmique — ne manque pas les offres de jetons." },
      { title: "Une offre cosmique t'attend 🌠", body: "{name}, il y a des avantages spéciaux sur les packs de jetons pour toi." },
      { title: "Plus de lectures, plus de réponses 🔮", body: "{name}, regarde un pack de jetons et n'en manque jamais." },
      { title: "Les étoiles sont généreuses aujourd'hui ⭐", body: "{name}, jette un œil aux offres sur les packs de jetons." },
    ],
  },
};

function interpolate(text: string, vars: NotifVars): string {
  return text.replace(/{(\w+)}/g, (_match, key: string) => {
    const value = (vars as Record<string, unknown>)[key];
    return value === undefined || value === null ? "" : String(value);
  });
}

function resolveVariant(
  variant: NotifTemplateVariant,
  vars: NotifVars,
): NotifVariant {
  if ("withName" in variant) {
    const name = vars.name?.toString().trim();
    return name ? variant.withName : variant.noName;
  }

  return variant;
}

export function normalizeLang(lang?: string): NotifLang {
  const code = (lang ?? "").trim().toLowerCase().split(/[-_]/)[0];
  return (["tr", "en", "de", "es", "fr"] as const).includes(code as NotifLang)
    ? (code as NotifLang)
    : DEFAULT_LANG;
}

/** Bir kategoriden rastgele varyant seçer ve değişkenleri yerleştirir. */
export function pickNotification(
  lang: string | undefined,
  category: NotifCategory,
  vars: NotifVars = {},
): NotifVariant {
  const normalizedLang = normalizeLang(lang);
  const variants =
    NOTIF_TEMPLATES[normalizedLang][category] ??
    NOTIF_TEMPLATES[DEFAULT_LANG][category];
  const chosen = variants[Math.floor(Math.random() * variants.length)];
  const variant = resolveVariant(chosen, vars);
  return {
    title: interpolate(variant.title, vars),
    body: interpolate(variant.body, vars),
  };
}
