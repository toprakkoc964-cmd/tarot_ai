import { createCanvas, GlobalFonts } from '@napi-rs/canvas';

const fontPath = process.env.SHARE_FONT_PATH;
if (fontPath) {
  GlobalFonts.registerFromPath(fontPath, 'ShareFont');
}

export function renderShareImage(params: {
  title: string;
  excerpt: string;
  footer: string;
}): Buffer {
  const width = 1080;
  const height = 1920;
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');

  const gradient = ctx.createLinearGradient(0, 0, width, height);
  gradient.addColorStop(0, '#081c24');
  gradient.addColorStop(1, '#20453f');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);

  ctx.fillStyle = '#f4ebd0';
  ctx.font = 'bold 64px ShareFont, serif';
  ctx.fillText(params.title, 80, 180);

  ctx.font = '42px ShareFont, serif';
  wrapText(ctx, params.excerpt, 80, 320, width - 160, 62);

  ctx.font = '32px ShareFont, serif';
  ctx.fillStyle = '#f5f5f5';
  ctx.fillText(params.footer, 80, height - 120);

  return canvas.toBuffer('image/png');
}

function wrapText(
  ctx: any,
  text: string,
  x: number,
  y: number,
  maxWidth: number,
  lineHeight: number
) {
  const words = text.split(' ');
  let line = '';
  let lineY = y;

  for (const word of words) {
    const testLine = line ? `${line} ${word}` : word;
    const metrics = ctx.measureText(testLine);
    if (metrics.width > maxWidth && line) {
      ctx.fillText(line, x, lineY);
      line = word;
      lineY += lineHeight;
    } else {
      line = testLine;
    }
  }

  if (line) {
    ctx.fillText(line, x, lineY);
  }
}
