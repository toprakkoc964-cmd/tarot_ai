const fallbackComments: Record<string, string[]> = {
  tr: [
    'Bugün iç sesin her zamankinden net; acele bir karar yerine sakin bir an seçip kalbinin gerçekte ne istediğini dinle.',
    'Enerjin bugün toparlanmaya hazır; küçük bir düzen değişikliği zihnini hafifletip günün akışını yumuşatabilir.',
    'Duyguların bugün sana yön gösterebilir; bir şeyi zorlamak yerine nazik bir adım atmak daha iyi hissettirecek.',
    'Ruhun bugün daha sade bir ritim istiyor; kendine alan aç ve seni besleyen tek bir niyete odaklan.',
    'Bugün sezgilerin güçlü; içine doğan ilk hissi küçümseme, çoğu zaman doğru yolu o gösterir.',
    'Bugün dengeyi aramak sana iyi gelecek; vermek ile almak arasında nazik bir orta nokta bul.',
    'Bugün bir kapıyı kapatmak yeni bir başlangıcın işareti olabilir; bırakmaktan korkma, yerine daha hafif bir şey gelir.',
    'Bugün sabır senin lehine; tohumlar hemen filizlenmese de doğru yönde ilerliyorsun.',
    'Bugün ilişkilerinde içtenlik öne çıkıyor; söylemek istediğin o küçük şeyi içinde tutma, paylaşmak rahatlatır.',
    'Bugün zihnin ve bedenin dinlenmek isteyebilir; kendine nazik davranmak tembellik değil, bilgeliktir.',
    'Bugün küçük bir cesaret büyük bir kapı aralayabilir; uzun süredir ertelediğin o tek adımı at.',
    'Bugün şükran enerjini yükseltir; sahip olduğun sade bir güzelliği fark etmek tüm günü değiştirir.'
  ],
  en: [
    'Your inner voice is clearer than usual today; choose a calm moment and listen to what your heart truly needs before deciding.',
    "Your energy is ready to settle today; one small act of order can lighten your mind and soften the day's flow.",
    'Your feelings can guide you today; instead of forcing anything, take one gentle step and it will feel better.',
    'Your spirit wants a simpler rhythm today; make space for yourself and focus on one nourishing intention.',
    "Your intuition is strong today; don't dismiss the first feeling that arises, it often points the right way.",
    'Seeking balance will serve you today; find a gentle middle ground between giving and receiving.',
    "Closing one door today may signal a new beginning; don't fear letting go, something lighter will take its place.",
    "Patience is on your side today; even if seeds don't sprout at once, you are moving in the right direction.",
    "Sincerity stands out in your relationships today; don't hold back that small thing you want to say, sharing eases the heart.",
    'Your mind and body may want rest today; being gentle with yourself is not laziness, it is wisdom.',
    "A small act of courage can open a big door today; take that one step you've long postponed.",
    'Gratitude lifts your energy today; noticing one simple beauty you already have can change the whole day.'
  ],
  de: [
    'Deine innere Stimme ist heute klarer als sonst; wähle einen ruhigen Moment und höre auf das, was dein Herz wirklich braucht, bevor du entscheidest.',
    'Deine Energie ist heute bereit, zur Ruhe zu kommen; eine kleine Ordnung kann deinen Geist erleichtern und den Tag sanfter machen.',
    'Deine Gefühle können dich heute leiten; statt etwas zu erzwingen, mach einen sanften Schritt, und es wird sich besser anfühlen.',
    'Deine Seele wünscht sich heute einen einfacheren Rhythmus; schaffe Raum für dich und konzentriere dich auf eine nährende Absicht.',
    'Deine Intuition ist heute stark; übergehe nicht das erste Gefühl, das aufsteigt, oft weist es den richtigen Weg.',
    'Das Streben nach Gleichgewicht tut dir heute gut; finde eine sanfte Mitte zwischen Geben und Nehmen.',
    'Eine Tür heute zu schließen kann ein neuer Anfang sein; fürchte das Loslassen nicht, etwas Leichteres nimmt seinen Platz ein.',
    'Geduld ist heute auf deiner Seite; auch wenn die Samen nicht sofort sprießen, gehst du in die richtige Richtung.',
    'Aufrichtigkeit prägt heute deine Beziehungen; behalte die kleine Sache, die du sagen möchtest, nicht für dich, Teilen erleichtert das Herz.',
    'Dein Geist und dein Körper möchten heute vielleicht ruhen; sanft zu dir zu sein ist keine Faulheit, sondern Weisheit.',
    'Ein kleiner Mut kann heute eine große Tür öffnen; mach den einen Schritt, den du lange aufgeschoben hast.',
    'Dankbarkeit hebt heute deine Energie; eine einfache Schönheit zu bemerken, die du schon hast, kann den ganzen Tag verändern.'
  ],
  es: [
    'Hoy tu voz interior es más clara que de costumbre; elige un momento de calma y escucha lo que tu corazón realmente necesita antes de decidir.',
    'Hoy tu energía está lista para asentarse; un pequeño gesto de orden puede aligerar tu mente y suavizar el día.',
    'Hoy tus sentimientos pueden guiarte; en lugar de forzar algo, da un paso suave y te sentirás mejor.',
    'Hoy tu espíritu desea un ritmo más sencillo; hazte espacio y concéntrate en una sola intención que te nutra.',
    'Hoy tu intuición está fuerte; no descartes la primera sensación que surja, a menudo señala el buen camino.',
    'Hoy buscar el equilibrio te hará bien; encuentra un punto medio amable entre dar y recibir.',
    'Cerrar una puerta hoy puede ser señal de un nuevo comienzo; no temas soltar, algo más ligero ocupará su lugar.',
    'Hoy la paciencia está de tu lado; aunque las semillas no broten enseguida, vas en la dirección correcta.',
    'Hoy la sinceridad destaca en tus relaciones; no guardes esa pequeña cosa que quieres decir, compartir alivia el corazón.',
    'Hoy tu mente y tu cuerpo quizá quieran descansar; ser amable contigo no es pereza, es sabiduría.',
    'Hoy un pequeño acto de valentía puede abrir una gran puerta; da ese paso que llevas tiempo posponiendo.',
    'Hoy la gratitud eleva tu energía; notar una sencilla belleza que ya tienes puede cambiar todo el día.'
  ],
  fr: [
    "Aujourd'hui ta voix intérieure est plus claire que d'habitude; choisis un moment calme et écoute ce dont ton cœur a vraiment besoin avant de décider.",
    "Aujourd'hui ton énergie est prête à s'apaiser; un petit geste d'ordre peut alléger ton esprit et adoucir la journée.",
    "Aujourd'hui tes émotions peuvent te guider; au lieu de forcer, fais un pas doux et tu te sentiras mieux.",
    "Aujourd'hui ton âme désire un rythme plus simple; fais-toi de la place et concentre-toi sur une seule intention qui te nourrit.",
    "Aujourd'hui ton intuition est forte; ne néglige pas le premier ressenti qui surgit, il indique souvent le bon chemin.",
    "Aujourd'hui chercher l'équilibre te fera du bien; trouve un juste milieu doux entre donner et recevoir.",
    "Fermer une porte aujourd'hui peut annoncer un nouveau départ; n'aie pas peur de lâcher prise, quelque chose de plus léger prendra sa place.",
    "Aujourd'hui la patience est de ton côté; même si les graines ne germent pas tout de suite, tu avances dans la bonne direction.",
    "Aujourd'hui la sincérité ressort dans tes relations; ne garde pas pour toi cette petite chose à dire, partager apaise le cœur.",
    "Aujourd'hui ton esprit et ton corps ont peut-être besoin de repos; être doux avec toi-même n'est pas de la paresse, c'est de la sagesse.",
    "Aujourd'hui un petit acte de courage peut ouvrir une grande porte; fais ce pas que tu remets depuis longtemps.",
    "Aujourd'hui la gratitude élève ton énergie; remarquer une beauté simple que tu possèdes déjà peut changer toute la journée."
  ],
  it: [
    'Oggi la tua voce interiore è più chiara del solito; scegli un momento di calma e ascolta ciò di cui il tuo cuore ha davvero bisogno prima di decidere.',
    "Oggi la tua energia è pronta a posarsi; un piccolo gesto d'ordine può alleggerire la mente e ammorbidire la giornata.",
    'Oggi i tuoi sentimenti possono guidarti; invece di forzare, fai un passo gentile e ti sentirai meglio.',
    "Oggi il tuo spirito desidera un ritmo più semplice; fatti spazio e concentrati su un'unica intenzione che ti nutre.",
    'Oggi la tua intuizione è forte; non ignorare la prima sensazione che affiora, spesso indica la via giusta.',
    "Oggi cercare l'equilibrio ti farà bene; trova una via di mezzo gentile tra dare e ricevere.",
    'Chiudere una porta oggi può essere segno di un nuovo inizio; non temere di lasciar andare, qualcosa di più leggero prenderà il suo posto.',
    'Oggi la pazienza è dalla tua parte; anche se i semi non germogliano subito, stai andando nella direzione giusta.',
    'Oggi la sincerità risalta nelle tue relazioni; non trattenere quella piccola cosa che vuoi dire, condividere alleggerisce il cuore.',
    'Oggi mente e corpo potrebbero voler riposare; essere gentile con te stesso non è pigrizia, è saggezza.',
    'Oggi un piccolo atto di coraggio può aprire una grande porta; fai quel passo che rimandi da tempo.',
    "Oggi la gratitudine solleva la tua energia; notare una semplice bellezza che già possiedi può cambiare l'intera giornata."
  ],
  pt: [
    'Hoje a tua voz interior está mais clara que o habitual; escolhe um momento calmo e ouve o que o teu coração realmente precisa antes de decidir.',
    'Hoje a tua energia está pronta para assentar; um pequeno gesto de ordem pode aliviar a mente e suavizar o dia.',
    'Hoje os teus sentimentos podem guiar-te; em vez de forçar, dá um passo suave e vais sentir-te melhor.',
    'Hoje o teu espírito deseja um ritmo mais simples; abre espaço para ti e foca-te numa única intenção que te nutre.',
    'Hoje a tua intuição está forte; não descartes a primeira sensação que surge, muitas vezes aponta o caminho certo.',
    'Hoje procurar o equilíbrio vai fazer-te bem; encontra um meio-termo gentil entre dar e receber.',
    'Fechar uma porta hoje pode ser sinal de um novo começo; não temas largar, algo mais leve ocupará o seu lugar.',
    'Hoje a paciência está do teu lado; mesmo que as sementes não brotem já, estás a seguir na direção certa.',
    'Hoje a sinceridade destaca-se nas tuas relações; não guardes aquela pequena coisa que queres dizer, partilhar alivia o coração.',
    'Hoje a tua mente e o teu corpo podem querer descansar; ser gentil contigo não é preguiça, é sabedoria.',
    'Hoje um pequeno ato de coragem pode abrir uma grande porta; dá aquele passo que adias há muito tempo.',
    'Hoje a gratidão eleva a tua energia; notar uma beleza simples que já tens pode mudar o dia inteiro.'
  ]
};

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
  const list = fallbackComments[input.lang] ?? fallbackComments.en;
  const idx = ((month + birthDay + targetDayOffset) % list.length + list.length) % list.length;
  return list[idx];
}
