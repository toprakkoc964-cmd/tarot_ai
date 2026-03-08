import { getMessaging } from 'firebase-admin/messaging';
import { getFirestore } from 'firebase-admin/firestore';

const db = getFirestore();
const messaging = getMessaging();

export async function sendAudioReadyNotification(input: {
  uid: string;
  readingId: string;
  lang: string;
}) {
  const tokensSnap = await db.collection('users').doc(input.uid).collection('fcm_tokens').get();
  const tokens = tokensSnap.docs.map((d) => d.id).filter((t) => t.length > 8);
  if (tokens.length === 0) return;

  const title = input.lang === 'tr' ? 'Sesli falın hazır' : 'Your audio reading is ready';
  const body =
    input.lang === 'tr'
      ? 'Emilia mesajını seslendirdi. Dinlemek için uygulamayı aç.'
      : 'Emilia has narrated your reading. Open the app to listen.';

  await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      type: 'reading_audio_ready',
      readingId: input.readingId
    }
  });
}

export async function sendDailyNudge(input: {
  uid: string;
  lang: string;
  zodiac: string;
  deepLink: string;
}) {
  const tokensSnap = await db.collection('users').doc(input.uid).collection('fcm_tokens').get();
  const tokens = tokensSnap.docs.map((d) => d.id).filter((t) => t.length > 8);
  if (tokens.length === 0) return;

  const title = input.lang === 'tr' ? 'Gunun karti seni bekliyor' : 'Your daily card is waiting';
  const body =
    input.lang === 'tr'
      ? `${input.zodiac} enerjin icin bugunluk acilim hazir.`
      : `A quick spread is ready for your ${input.zodiac} energy today.`;

  await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      type: 'daily_nudge',
      deeplink: input.deepLink
    }
  });
}
