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

export interface NotifVars {
  name?: string;
  zodiac?: string;
  card?: string;
  credits?: number | string;
}

const DEFAULT_LANG: NotifLang = "en";

type NotifData = Record<NotifLang, Record<NotifCategory, NotifVariant[]>>;

export const NOTIF_TEMPLATES: NotifData = {
  tr: {
    daily_card: [
      { title: "Günaydın {name} 🌅", body: "Bugünün kartı seni bekliyor. Evren sana ne fısıldıyor, bir bak ✨" },
      { title: "Yeni gün, yeni kart 🔮", body: "{name}, bugün hangi enerji seninle? Günün kartını çek." },
      { title: "Kartların hazır ✨", body: "{name}, güne bir rehberlikle başla — günün kartını aç." },
      { title: "Bugün sana ne diyor? 🌙", body: "{name}, günün kartı bir mesaj saklıyor. Açmaya hazır mısın?" },
      { title: "Kahveni al, kartını çek ☕🔮", body: "{name}, güne minik bir kehanetle başla. Günün kartı seni bekliyor." },
    ],
    birth_chart_fallback: [
      { title: "Yıldızların bugünkü mesajı 🌙", body: "{zodiac} burcu için bugün özel bir gün. Yorumunu gör." },
      { title: "{zodiac} için günlük gök haritası ✨", body: "Gezegenler bugün senin lehine hizalanıyor, {name}. Detaylara bak." },
      { title: "Bugün gökyüzü senin için konuşuyor 🌌", body: "{name}, {zodiac} burcunun günlük yorumu hazır." },
      { title: "Evrenin {zodiac} için planı 🔭", body: "{name}, bugün seni neler bekliyor? Doğum haritası yorumuna göz at." },
      { title: "Yıldız haritan güncellendi ⭐", body: "{name}, {zodiac} enerjisi bugün güçlü. Yorumunu kaçırma." },
    ],
    coffee_followup: [
      { title: "Fincanın hâlâ konuşuyor ☕", body: "{name}, kahve falının detaylarına tekrar bak — kaçırdığın bir işaret olabilir." },
      { title: "Telvenin sırrı çözülmeyi bekliyor ☕", body: "{name}, kahve falı yorumunu yeniden oku." },
      { title: "Fincanında bir mesaj kaldı mı? ☕", body: "{name}, kahve falına dönüp bir kez daha bak." },
      { title: "O fincan ne anlatıyordu? ✨", body: "{name}, kahve falı yorumunu tekrar incele, ipuçları derin." },
    ],
    palm_followup: [
      { title: "Avucundaki çizgiler ne diyordu? ✋", body: "{name}, el falı yorumunu yeniden incele." },
      { title: "Elindeki harita seni bekliyor 🤚", body: "{name}, el falının detaylarına tekrar göz at." },
      { title: "Çizgilerin bir şey saklıyor olabilir ✋", body: "{name}, el falı yorumunu yeniden oku." },
      { title: "Kaderin avucunda ✨", body: "{name}, el falı sonucunu tekrar incele, derin bir anlamı var." },
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
      { title: "Good morning {name} 🌅", body: "Today's card is waiting. See what the universe whispers to you ✨" },
      { title: "New day, new card 🔮", body: "{name}, which energy is with you today? Draw your daily card." },
      { title: "Your cards are ready ✨", body: "{name}, start the day with some guidance — reveal today's card." },
      { title: "What does today hold? 🌙", body: "{name}, your daily card hides a message. Ready to open it?" },
      { title: "Grab your coffee, draw your card ☕🔮", body: "{name}, start the day with a little prophecy. Today's card awaits." },
    ],
    birth_chart_fallback: [
      { title: "Today's message from the stars 🌙", body: "It's a special day for {zodiac}. See your reading." },
      { title: "Daily chart for {zodiac} ✨", body: "The planets align in your favor today, {name}. Take a look." },
      { title: "The sky is speaking for you today 🌌", body: "{name}, your daily {zodiac} reading is ready." },
      { title: "The universe's plan for {zodiac} 🔭", body: "{name}, what awaits you today? Check your birth chart reading." },
      { title: "Your star chart is updated ⭐", body: "{name}, {zodiac} energy is strong today. Don't miss your reading." },
    ],
    coffee_followup: [
      { title: "Your cup is still speaking ☕", body: "{name}, revisit your coffee reading — you may have missed a sign." },
      { title: "The grounds still hold a secret ☕", body: "{name}, read your coffee reading again." },
      { title: "Is there a message left in your cup? ☕", body: "{name}, go back and take another look at your coffee reading." },
      { title: "What was that cup telling you? ✨", body: "{name}, review your coffee reading — the clues run deep." },
    ],
    palm_followup: [
      { title: "What did your palm lines say? ✋", body: "{name}, take another look at your palm reading." },
      { title: "The map in your hand awaits 🤚", body: "{name}, revisit the details of your palm reading." },
      { title: "Your lines may be hiding something ✋", body: "{name}, read your palm reading again." },
      { title: "Your destiny is in your hand ✨", body: "{name}, review your palm reading — it holds deeper meaning." },
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
      { title: "Guten Morgen {name} 🌅", body: "Deine Karte des Tages wartet. Sieh, was das Universum dir zuflüstert ✨" },
      { title: "Neuer Tag, neue Karte 🔮", body: "{name}, welche Energie begleitet dich heute? Zieh deine Tageskarte." },
      { title: "Deine Karten sind bereit ✨", body: "{name}, beginne den Tag mit etwas Führung — deck deine Tageskarte auf." },
      { title: "Was hält der Tag bereit? 🌙", body: "{name}, deine Tageskarte verbirgt eine Botschaft. Bereit, sie aufzudecken?" },
      { title: "Schnapp dir deinen Kaffee, zieh deine Karte ☕🔮", body: "{name}, beginne den Tag mit einer kleinen Prophezeiung. Deine Tageskarte wartet." },
    ],
    birth_chart_fallback: [
      { title: "Die heutige Botschaft der Sterne 🌙", body: "Ein besonderer Tag für {zodiac}. Sieh dir deine Deutung an." },
      { title: "Tageshoroskop für {zodiac} ✨", body: "Die Planeten stehen heute günstig für dich, {name}. Schau mal rein." },
      { title: "Der Himmel spricht heute für dich 🌌", body: "{name}, deine tägliche {zodiac}-Deutung ist bereit." },
      { title: "Der Plan des Universums für {zodiac} 🔭", body: "{name}, was erwartet dich heute? Sieh dir deine Geburtshoroskop-Deutung an." },
      { title: "Deine Sternenkarte ist aktualisiert ⭐", body: "{name}, die {zodiac}-Energie ist heute stark. Verpasse deine Deutung nicht." },
    ],
    coffee_followup: [
      { title: "Deine Tasse spricht noch ☕", body: "{name}, sieh dir deine Kaffeesatzdeutung noch einmal an — vielleicht ein übersehenes Zeichen." },
      { title: "Der Satz birgt noch ein Geheimnis ☕", body: "{name}, lies deine Kaffeesatzdeutung erneut." },
      { title: "Ist noch eine Botschaft in deiner Tasse? ☕", body: "{name}, wirf noch einen Blick auf deine Kaffeesatzdeutung." },
      { title: "Was sagte dir diese Tasse? ✨", body: "{name}, sieh dir deine Kaffeesatzdeutung noch einmal an — die Zeichen sind tief." },
    ],
    palm_followup: [
      { title: "Was sagten deine Handlinien? ✋", body: "{name}, wirf noch einen Blick auf deine Handlesung." },
      { title: "Die Karte in deiner Hand wartet 🤚", body: "{name}, sieh dir die Details deiner Handlesung noch einmal an." },
      { title: "Deine Linien verbergen vielleicht etwas ✋", body: "{name}, lies deine Handlesung erneut." },
      { title: "Dein Schicksal liegt in deiner Hand ✨", body: "{name}, sieh dir deine Handlesung noch einmal an — sie hat eine tiefere Bedeutung." },
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
      { title: "Buenos días {name} 🌅", body: "Tu carta del día te espera. Descubre lo que el universo te susurra ✨" },
      { title: "Nuevo día, nueva carta 🔮", body: "{name}, ¿qué energía te acompaña hoy? Saca tu carta del día." },
      { title: "Tus cartas están listas ✨", body: "{name}, empieza el día con una guía — revela tu carta del día." },
      { title: "¿Qué te depara hoy? 🌙", body: "{name}, tu carta del día esconde un mensaje. ¿Quieres abrirla?" },
      { title: "Toma tu café y saca tu carta ☕🔮", body: "{name}, empieza el día con una pequeña profecía. Tu carta del día te espera." },
    ],
    birth_chart_fallback: [
      { title: "El mensaje de hoy de las estrellas 🌙", body: "Es un día especial para {zodiac}. Mira tu lectura." },
      { title: "Carta diaria para {zodiac} ✨", body: "Los planetas se alinean a tu favor hoy, {name}. Échale un vistazo." },
      { title: "El cielo habla por ti hoy 🌌", body: "{name}, tu lectura diaria de {zodiac} está lista." },
      { title: "El plan del universo para {zodiac} 🔭", body: "{name}, ¿qué te espera hoy? Mira la lectura de tu carta natal." },
      { title: "Tu carta astral se ha actualizado ⭐", body: "{name}, la energía de {zodiac} es fuerte hoy. No te pierdas tu lectura." },
    ],
    coffee_followup: [
      { title: "Tu taza aún habla ☕", body: "{name}, vuelve a mirar tu lectura del café — quizá pasaste por alto una señal." },
      { title: "Los posos guardan un secreto ☕", body: "{name}, vuelve a leer tu lectura del café." },
      { title: "¿Queda un mensaje en tu taza? ☕", body: "{name}, regresa y echa otro vistazo a tu lectura del café." },
      { title: "¿Qué te decía esa taza? ✨", body: "{name}, revisa tu lectura del café — las pistas son profundas." },
    ],
    palm_followup: [
      { title: "¿Qué decían las líneas de tu mano? ✋", body: "{name}, vuelve a revisar tu lectura de la palma." },
      { title: "El mapa de tu mano te espera 🤚", body: "{name}, vuelve a mirar los detalles de tu lectura de la palma." },
      { title: "Tus líneas podrían esconder algo ✋", body: "{name}, vuelve a leer tu lectura de la palma." },
      { title: "Tu destino está en tu mano ✨", body: "{name}, revisa tu lectura de la palma — tiene un significado más profundo." },
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
      { title: "Bonjour {name} 🌅", body: "Ta carte du jour t'attend. Découvre ce que l'univers te murmure ✨" },
      { title: "Nouveau jour, nouvelle carte 🔮", body: "{name}, quelle énergie t'accompagne aujourd'hui ? Tire ta carte du jour." },
      { title: "Tes cartes sont prêtes ✨", body: "{name}, commence la journée avec un peu de guidance — révèle ta carte du jour." },
      { title: "Que te réserve aujourd'hui ? 🌙", body: "{name}, ta carte du jour cache un message. Envie de la dévoiler ?" },
      { title: "Prends ton café, tire ta carte ☕🔮", body: "{name}, commence la journée avec une petite prophétie. Ta carte du jour t'attend." },
    ],
    birth_chart_fallback: [
      { title: "Le message des étoiles aujourd'hui 🌙", body: "C'est un jour spécial pour {zodiac}. Vois ta lecture." },
      { title: "Carte du jour pour {zodiac} ✨", body: "Les planètes s'alignent en ta faveur aujourd'hui, {name}. Jette un œil." },
      { title: "Le ciel parle pour toi aujourd'hui 🌌", body: "{name}, ta lecture quotidienne {zodiac} est prête." },
      { title: "Le plan de l'univers pour {zodiac} 🔭", body: "{name}, qu'est-ce qui t'attend aujourd'hui ? Consulte ta lecture du thème natal." },
      { title: "Ta carte du ciel est mise à jour ⭐", body: "{name}, l'énergie {zodiac} est forte aujourd'hui. Ne manque pas ta lecture." },
    ],
    coffee_followup: [
      { title: "Ta tasse parle encore ☕", body: "{name}, reviens sur ta lecture du café — tu as peut-être manqué un signe." },
      { title: "Le marc garde encore un secret ☕", body: "{name}, relis ta lecture du café." },
      { title: "Reste-t-il un message dans ta tasse ? ☕", body: "{name}, reviens jeter un œil à ta lecture du café." },
      { title: "Que te disait cette tasse ? ✨", body: "{name}, revois ta lecture du café — les indices sont profonds." },
    ],
    palm_followup: [
      { title: "Que disaient les lignes de ta main ? ✋", body: "{name}, reviens sur ta lecture des lignes de la main." },
      { title: "La carte de ta main t'attend 🤚", body: "{name}, reviens sur les détails de ta lecture de la main." },
      { title: "Tes lignes cachent peut-être quelque chose ✋", body: "{name}, relis ta lecture de la main." },
      { title: "Ton destin est dans ta main ✨", body: "{name}, revois ta lecture de la main — elle a un sens plus profond." },
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

function normalizeLang(lang?: string): NotifLang {
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
  return {
    title: interpolate(chosen.title, vars),
    body: interpolate(chosen.body, vars),
  };
}
