import type { ErrorCode } from './types';

/**
 * HTTP ステータスと機械可読コードを持つアプリケーションエラー。
 *
 * 外部 API のレスポンス本文をそのままクライアントへ透過させないため、
 * message は必ず自前で組み立てた短い文字列にする。
 */
export class ApiError extends Error {
  readonly status: number;
  readonly code: ErrorCode;
  readonly field?: string;

  constructor(status: number, code: ErrorCode, message: string, field?: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    if (field !== undefined) {
      this.field = field;
    }
  }

  static badRequest(code: ErrorCode, message: string, field?: string): ApiError {
    return new ApiError(400, code, message, field);
  }

  /** 全プロバイダー失敗かつ stale cache も無い場合。5xx は 502 を使う。 */
  static upstreamUnavailable(message: string): ApiError {
    return new ApiError(502, 'UPSTREAM_UNAVAILABLE', message);
  }
}

/** 外部プロバイダー呼び出しの失敗種別。警告コードへ 1:1 で写像する。 */
export type ProviderFailureKind = 'timeout' | 'unavailable' | 'invalid_response';

export class ProviderError extends Error {
  readonly kind: ProviderFailureKind;

  constructor(kind: ProviderFailureKind, message: string) {
    super(message);
    this.name = 'ProviderError';
    this.kind = kind;
  }
}

/** AbortSignal によるタイムアウトかどうかを判定する。 */
export function isAbortError(err: unknown): boolean {
  if (typeof err !== 'object' || err === null) return false;
  const name = (err as { name?: unknown }).name;
  return name === 'AbortError' || name === 'TimeoutError';
}
