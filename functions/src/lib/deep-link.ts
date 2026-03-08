export function buildShareDeepLink(readingId: string): string {
  const appLinkBase = process.env.APP_DEEP_LINK_BASE ?? 'https://tarotai.app/readings';
  const appStoreUrl = process.env.APP_STORE_URL ?? 'https://apps.apple.com/app/id0000000000';
  return `${appLinkBase}/${encodeURIComponent(readingId)}?fallback=${encodeURIComponent(appStoreUrl)}`;
}
