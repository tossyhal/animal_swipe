/**
 * BFF 全体で共有する型定義。
 * このファイルは firebase-admin / firebase-functions に依存しない（純粋コア）。
 */

/** allowlist で許可する動物種。ここに無い値は 400 で拒否する。 */
export const ALLOWED_ANIMAL_TYPES = ['cat', 'dog'] as const;
export type AnimalType = (typeof ALLOWED_ANIMAL_TYPES)[number];

/** allowlist で許可する取得元プロバイダー識別子。 */
export const ALLOWED_SOURCES = ['cataas', 'dogceo'] as const;
export type SourceId = (typeof ALLOWED_SOURCES)[number];

/** 外部画像 URL として許可するホスト（完全一致のみ）。 */
export const ALLOWED_IMAGE_HOSTS: readonly string[] = ['cataas.com', 'images.dog.ceo'];

/** `limit` の既定値と上限。 */
export const DEFAULT_LIMIT = 10;
export const MAX_LIMIT = 30;
export const MIN_LIMIT = 1;

/** 正規化済みの動物画像 1 件。OpenAPI の `AnimalItem` と 1:1 対応する。 */
export interface AnimalItem {
  /** `"{source}:{providerId}"` 形式の安定 ID。重複排除のキーでもある。 */
  id: string;
  type: AnimalType;
  /** HTTPS かつ許可ホストであることを検証済みの画像 URL。 */
  imageUrl: string;
  /** 品種。取得元が品種を返さない場合は null。 */
  breed: string | null;
  source: SourceId;
}

/** 部分失敗・全体失敗をクライアントへ伝えるための警告。 */
export interface Warning {
  /** 失敗したプロバイダー。プロバイダーに紐づかない警告では null。 */
  source: SourceId | null;
  /** 機械可読なコード。 */
  code: WarningCode;
  /** 人間向けの短い説明。外部レスポンス本文や URL は含めない。 */
  message: string;
}

export type WarningCode =
  | 'PROVIDER_TIMEOUT'
  | 'PROVIDER_UNAVAILABLE'
  | 'PROVIDER_INVALID_RESPONSE'
  | 'STALE_CACHE_SERVED'
  | 'INSUFFICIENT_ITEMS';

/** `GET /api/v1/animals` の成功／部分成功レスポンス。 */
export interface AnimalsResponse {
  items: AnimalItem[];
  /** 1 つ以上のプロバイダーが失敗した、または stale cache を返した場合に true。 */
  partial: boolean;
  warnings: Warning[];
}

/** エラーレスポンス（4xx / 5xx 共通）。 */
export interface ErrorResponse {
  error: {
    code: ErrorCode;
    message: string;
    /** 入力検証エラーで、原因となったクエリパラメータ名。 */
    field?: string;
  };
}

export type ErrorCode =
  | 'INVALID_ANIMAL_TYPE'
  | 'INVALID_LIMIT'
  | 'METHOD_NOT_ALLOWED'
  | 'UPSTREAM_UNAVAILABLE'
  | 'INTERNAL_ERROR'
  | 'NOT_FOUND';

/** 検証を通過した正規化済みクエリ。キャッシュキーはこの値からのみ生成する。 */
export interface NormalizedAnimalsQuery {
  /** 重複排除・ソート済みの動物種リスト（1 件以上）。 */
  types: AnimalType[];
  /** MIN_LIMIT..MAX_LIMIT に収まる整数。全体の返却上限。 */
  limit: number;
}

/** 依存注入用の fetch シグネチャ（テストでは fake を渡す）。 */
export type FetchLike = (
  input: string,
  init?: { signal?: AbortSignal; headers?: Record<string, string> },
) => Promise<FetchLikeResponse>;

export interface FetchLikeResponse {
  ok: boolean;
  status: number;
  json: () => Promise<unknown>;
  text: () => Promise<string>;
}
