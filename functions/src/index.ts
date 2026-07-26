import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onRequest, type Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';

import { createFirestoreCacheStore } from './cache/firestoreStore';
import { handleRequest, type HttpRequestLike } from './http/handler';
import type { AggregateDeps } from './core/aggregate';
import type { FetchLike } from './core/types';

/**
 * コスト上限のガード。
 * - maxInstances: 暴走・攻撃時の水平スケールを抑え、想定外の課金を防ぐ。
 * - concurrency: 1 インスタンスで複数リクエストを捌き、インスタンス数を抑える。
 * - timeoutSeconds: 外部 API のタイムアウト(3s) × 再試行 を十分に上回る短い値。
 */
setGlobalOptions({
  region: 'asia-northeast1',
  maxInstances: 5,
  concurrency: 40,
  memory: '256MiB',
  timeoutSeconds: 20,
});

if (getApps().length === 0) {
  initializeApp();
}

/** Node 22 のグローバル fetch を FetchLike に適合させる。 */
const nodeFetch: FetchLike = (input, init) =>
  fetch(input, init as RequestInit) as unknown as ReturnType<FetchLike>;

function buildDeps(): AggregateDeps {
  return {
    fetch: nodeFetch,
    store: createFirestoreCacheStore(getFirestore()),
    now: () => Date.now(),
  };
}

export const api = onRequest(async (req: Request, res: Response) => {
  const request: HttpRequestLike = {
    method: req.method,
    // Hosting rewrite 経由では req.path が `/api/v1/...` を保持する。
    // 関数を直接呼ぶ場合に備え、originalUrl も見て解決する。
    path: resolvePath(req),
    // 値の形は保証しない（オブジェクト・ネスト配列も来る）。検証は core 側で行う。
    query: req.query as Record<string, unknown>,
    headers: req.headers as Record<string, string | undefined>,
  };

  const result = await handleRequest(request, buildDeps());

  for (const [name, value] of Object.entries(result.headers)) {
    res.setHeader(name, value);
  }

  if (result.body === null) {
    res.status(result.status).end();
    return;
  }
  res.status(result.status).json(result.body);
});

/**
 * `/api/v1/animals` に正規化する。
 * Hosting rewrite（`/api/**` → 関数）では path が既に `/api/...` になるが、
 * 関数 URL 直叩き（`https://<region>-<project>.cloudfunctions.net/api/v1/animals`）では
 * `/v1/animals` になることがあるため補う。
 */
function resolvePath(req: Request): string {
  const raw = (req.path || '/').split('?')[0];
  if (raw.startsWith('/api/')) return raw;
  if (raw.startsWith('/v1/')) return `/api${raw}`;
  return raw;
}
