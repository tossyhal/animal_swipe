/**
 * CORS は利用する Hosting origin だけに絞る。
 *
 * - `*` は使わない。許可時のみ要求 origin を完全一致でエコーする。
 * - `Vary: Origin` を必ず付ける（CDN が origin 別に正しくキャッシュするため）。
 * - CORS は認証の代替ではない。ブラウザ以外からの呼び出しは CORS では防げないため、
 *   将来的にレート制限・App Check・認証を併用する。
 */
export const ALLOWED_ORIGINS: readonly string[] = ['https://animal-swipe-596cc.web.app'];

const ALLOWED_ORIGIN_SET = new Set(ALLOWED_ORIGINS);

export function isAllowedOrigin(origin: string | undefined): boolean {
  if (origin === undefined) return false;
  return ALLOWED_ORIGIN_SET.has(origin);
}

/** 要求 origin に応じた CORS ヘッダーを返す。許可外なら CORS ヘッダーを付けない。 */
export function corsHeaders(origin: string | undefined): Record<string, string> {
  const headers: Record<string, string> = { Vary: 'Origin' };
  if (!isAllowedOrigin(origin)) return headers;

  headers['Access-Control-Allow-Origin'] = origin as string;
  headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS';
  headers['Access-Control-Allow-Headers'] = 'Content-Type';
  headers['Access-Control-Max-Age'] = '3600';
  return headers;
}
