import { ALLOWED_IMAGE_HOSTS } from './types';

const ALLOWED_HOST_SET = new Set(ALLOWED_IMAGE_HOSTS);

/**
 * 外部画像 URL が「HTTPS かつ許可ホストに完全一致」であることを検証する。
 *
 * 意図的に `endsWith` / `includes` を使わない。
 * `endsWith('cataas.com')` は `evilcataas.com` を、
 * `includes('images.dog.ceo')` は `https://images.dog.ceo.evil.test/x.jpg` を通してしまう。
 *
 * @returns 正規化された URL 文字列。許可されない場合は null。
 */
export function sanitizeImageUrl(rawUrl: unknown): string | null {
  if (typeof rawUrl !== 'string') return null;

  const trimmed = rawUrl.trim();
  if (trimmed === '') return null;

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return null;
  }

  if (parsed.protocol !== 'https:') return null;
  // 認証情報付き URL（https://user:pass@host/）は拒否する。
  if (parsed.username !== '' || parsed.password !== '') return null;
  // 明示ポートは拒否（443 の既定のみ許可）。
  if (parsed.port !== '') return null;
  if (!ALLOWED_HOST_SET.has(parsed.hostname)) return null;

  return parsed.toString();
}

/** 許可ホストかどうかだけを判定する補助関数。 */
export function isAllowedImageHost(hostname: string): boolean {
  return ALLOWED_HOST_SET.has(hostname);
}
