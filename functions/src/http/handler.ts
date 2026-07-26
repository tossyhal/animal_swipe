import { fetchAnimals, type AggregateDeps } from '../core/aggregate';
import { fetchDailyAnimal } from '../core/daily';
import { ApiError } from '../core/errors';
import { parseAnimalsQuery } from '../core/validate';
import type { ErrorResponse } from '../core/types';
import { corsHeaders } from './cors';

/** フレームワーク非依存のリクエスト表現。テストから直接組み立てられる。 */
export interface HttpRequestLike {
  method: string;
  /** クエリを除いたパス（例: `/api/v1/animals`）。 */
  path: string;
  /**
   * パース済みクエリ。値は信用しない。
   * Express の extended パーサはオブジェクトやネストした配列も生成し得るため、
   * 型は `unknown` のままにして `parseAnimalsQuery` 側で検証する。
   */
  query: Record<string, unknown>;
  headers: Record<string, string | undefined>;
}

export interface HttpResponseLike {
  status: number;
  headers: Record<string, string>;
  body: unknown;
}

/**
 * ルーティング + 表現層。ビジネスロジックは core 側に置き、
 * ここは「ステータスコードとヘッダーの決定」だけを担う。
 */
export async function handleRequest(
  req: HttpRequestLike,
  deps: AggregateDeps,
): Promise<HttpResponseLike> {
  const origin = req.headers.origin ?? req.headers.Origin;
  const base = corsHeaders(typeof origin === 'string' ? origin : undefined);

  if (req.method === 'OPTIONS') {
    return { status: 204, headers: base, body: null };
  }

  if (req.method !== 'GET') {
    return errorResponse(
      base,
      new ApiError(405, 'METHOD_NOT_ALLOWED', 'GET のみ許可されています。'),
      { Allow: 'GET, OPTIONS' },
    );
  }

  try {
    const path = normalizePath(req.path);

    if (path === '/api/v1/animals') {
      const query = parseAnimalsQuery({
        types: req.query.types,
        limit: req.query.limit,
      });
      const result = await fetchAnimals(query, deps);
      // s-maxage は「元の取得時刻から数えた残り寿命」から算出する。
      // 毎回 TTL 満了値を返すと、期限間際のキャッシュヒットのたびに共有キャッシュの
      // 寿命がリセットされ、実効的な鮮度が TTL の 2 倍近くまで伸びてしまう。
      const remainingSec = Math.floor((result.expiresAt - deps.now()) / 1000);
      return {
        status: 200,
        headers: {
          ...base,
          'Content-Type': 'application/json; charset=utf-8',
          // 部分失敗の応答は共有キャッシュへ載せない。
          'Cache-Control':
            result.partial || remainingSec <= 0
              ? 'no-store'
              : `public, max-age=0, s-maxage=${remainingSec}`,
          'X-Cache': result.cacheStatus,
        },
        body: { items: result.items, partial: result.partial, warnings: result.warnings },
      };
    }

    if (path === '/api/v1/animals/daily') {
      const result = await fetchDailyAnimal(deps);
      // s-maxage は「返した date に対応する期限」から算出する。
      // 現在時刻から引き直すと、処理中に JST 深夜 0 時を跨いだ場合に
      // 前日の 1 枚を新しい日付いっぱい共有キャッシュへ載せてしまう。
      const remainingSec = Math.floor((result.expiresAt - deps.now()) / 1000);
      return {
        status: 200,
        headers: {
          ...base,
          'Content-Type': 'application/json; charset=utf-8',
          'Cache-Control':
            remainingSec > 0 ? `public, max-age=0, s-maxage=${remainingSec}` : 'no-store',
        },
        body: { date: result.date, item: result.item, warnings: result.warnings },
      };
    }

    return errorResponse(
      base,
      new ApiError(404, 'NOT_FOUND', '該当するエンドポイントがありません。'),
    );
  } catch (err) {
    if (err instanceof ApiError) {
      return errorResponse(base, err);
    }
    // 想定外の例外は内部詳細を返さない（ログ側で追跡する）。
    return errorResponse(
      base,
      new ApiError(500, 'INTERNAL_ERROR', '内部エラーが発生しました。'),
    );
  }
}

/** 末尾スラッシュを吸収する。クエリはここへは来ない前提。 */
export function normalizePath(path: string): string {
  const withoutQuery = path.split('?')[0];
  if (withoutQuery.length > 1 && withoutQuery.endsWith('/')) {
    return withoutQuery.slice(0, -1);
  }
  return withoutQuery;
}

function errorResponse(
  base: Record<string, string>,
  err: ApiError,
  extra: Record<string, string> = {},
): HttpResponseLike {
  const body: ErrorResponse = {
    error: {
      code: err.code,
      message: err.message,
      ...(err.field !== undefined ? { field: err.field } : {}),
    },
  };
  return {
    status: err.status,
    headers: {
      ...base,
      ...extra,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
    body,
  };
}
