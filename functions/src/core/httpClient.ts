import { ProviderError, isAbortError } from './errors';
import type { FetchLike, FetchLikeResponse } from './types';

/** 外部 API 呼び出しの共通設定。 */
export interface HttpBudget {
  /** 1 試行あたりのタイムアウト（ms）。 */
  timeoutMs: number;
  /** 追加の再試行回数（総試行回数 = maxRetries + 1）。 */
  maxRetries: number;
  /** 初回バックオフ（ms）。試行ごとに 2 倍、上限 maxBackoffMs。 */
  backoffBaseMs: number;
  maxBackoffMs: number;
}

export const DEFAULT_BUDGET: HttpBudget = {
  timeoutMs: 3000,
  maxRetries: 1,
  backoffBaseMs: 200,
  maxBackoffMs: 1000,
};

export interface HttpClientDeps {
  fetch: FetchLike;
  /** テストで実時間を待たないよう差し替え可能にする。 */
  sleep?: (ms: number) => Promise<void>;
  /** バックオフのジッター（0..1）。テストでは固定値を渡す。 */
  random?: () => number;
}

const defaultSleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

/**
 * 冪等な GET のみを対象にしたリトライ付き JSON 取得。
 *
 * - 再試行するのは「ネットワーク／タイムアウト」「5xx」「429」のみ。
 *   4xx（429 を除く）は再試行しても結果が変わらないため即座に諦める。
 * - 再試行回数とバックオフの双方に上限を設ける。
 * - 例外は必ず ProviderError に正規化し、外部レスポンス本文は載せない。
 */
export async function getJson(
  url: string,
  deps: HttpClientDeps,
  budget: HttpBudget = DEFAULT_BUDGET,
): Promise<unknown> {
  const sleep = deps.sleep ?? defaultSleep;
  const random = deps.random ?? Math.random;
  const totalAttempts = budget.maxRetries + 1;

  let lastError: ProviderError = new ProviderError('unavailable', 'リクエストを実行できませんでした。');

  for (let attempt = 0; attempt < totalAttempts; attempt++) {
    if (attempt > 0) {
      const base = Math.min(budget.backoffBaseMs * 2 ** (attempt - 1), budget.maxBackoffMs);
      // フルジッター: 同時失敗時のリトライ集中を避ける。
      await sleep(Math.floor(base * random()));
    }

    let response: FetchLikeResponse;
    try {
      response = await deps.fetch(url, { signal: AbortSignal.timeout(budget.timeoutMs) });
    } catch (err) {
      lastError = isAbortError(err)
        ? new ProviderError('timeout', 'タイムアウトしました。')
        : new ProviderError('unavailable', 'ネットワークエラーが発生しました。');
      continue;
    }

    if (response.ok) {
      try {
        return await response.json();
      } catch (err) {
        // ヘッダーは 200 でも、本文の読み取り中にタイムアウト・切断が起き得る。
        // これらは「壊れた JSON」ではなく一過性の失敗なので再試行対象として扱う。
        if (isAbortError(err)) {
          lastError = new ProviderError('timeout', '本文の受信中にタイムアウトしました。');
          continue;
        }
        if (!(err instanceof SyntaxError)) {
          lastError = new ProviderError('unavailable', '本文の受信に失敗しました。');
          continue;
        }
        // JSON として壊れているレスポンスは再試行しても回復しないため即中断する。
        throw new ProviderError('invalid_response', 'JSON として解釈できないレスポンスです。');
      }
    }

    if (isRetryableStatus(response.status)) {
      lastError = new ProviderError('unavailable', `一時的なエラー応答です (status=${response.status})。`);
      continue;
    }

    // 再試行不可の 4xx。
    throw new ProviderError('unavailable', `エラー応答です (status=${response.status})。`);
  }

  throw lastError;
}

export function isRetryableStatus(status: number): boolean {
  return status === 429 || (status >= 500 && status <= 599);
}
