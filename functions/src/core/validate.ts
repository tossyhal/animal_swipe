import { ApiError } from './errors';
import {
  ALLOWED_ANIMAL_TYPES,
  DEFAULT_LIMIT,
  MAX_LIMIT,
  MIN_LIMIT,
  type AnimalType,
  type NormalizedAnimalsQuery,
} from './types';

const ALLOWED_TYPE_SET = new Set<string>(ALLOWED_ANIMAL_TYPES);

/**
 * クエリ文字列を allowlist 方式で検証し、正規化済みクエリを返す。
 *
 * - `types`: カンマ区切り。ALLOWED_ANIMAL_TYPES に完全一致する値のみ許可。
 *   1 つでも未知の値が混ざれば 400（未知の値を黙って捨てない）。
 *   省略時は全許可種。
 * - `limit`: 10 進整数のみ。範囲外は 400（黙ってクランプしない）。省略時は DEFAULT_LIMIT。
 *
 * この関数を通らない値がプロバイダー呼び出しやキャッシュキーへ届いてはならない。
 */
export function parseAnimalsQuery(raw: { types?: unknown; limit?: unknown }): NormalizedAnimalsQuery {
  return {
    types: parseTypes(scalarValue(raw.types, 'types')),
    limit: parseLimit(scalarValue(raw.limit, 'limit')),
  };
}

/**
 * クエリ値を単一の文字列へ落とす。
 *
 * Express の extended クエリパーサは `?limit[x]=1` や `?types[]=cat&types[][]=dog` に対して
 * オブジェクトやネストした配列を生成する。これらを素通しすると後段の `.trim()` で
 * TypeError になり、契約上 400 であるべき入力が 500 になってしまうため、
 * ここで allowlist 的に「文字列」または「文字列のフラットな配列」だけを受け付ける。
 * 同名パラメータが複数ある場合は先頭のみを採用する。
 */
function scalarValue(value: unknown, field: 'types' | 'limit'): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value === 'string') return value;

  if (Array.isArray(value)) {
    if (value.length === 0) return undefined;
    const first = value[0];
    if (typeof first === 'string') return first;
  }

  throw ApiError.badRequest(
    field === 'types' ? 'INVALID_ANIMAL_TYPE' : 'INVALID_LIMIT',
    `${field} は単一の文字列で指定してください。`,
    field,
  );
}

export function parseTypes(rawTypes: string | undefined): AnimalType[] {
  if (rawTypes === undefined || rawTypes.trim() === '') {
    return [...ALLOWED_ANIMAL_TYPES];
  }

  const parts = rawTypes.split(',').map((p) => p.trim());
  const accepted = new Set<AnimalType>();

  for (const part of parts) {
    if (part === '') {
      throw ApiError.badRequest(
        'INVALID_ANIMAL_TYPE',
        'types に空の要素が含まれています。',
        'types',
      );
    }
    // 完全一致のみ。部分一致・前方一致・URL 等はすべてここで落ちる。
    if (!ALLOWED_TYPE_SET.has(part)) {
      throw ApiError.badRequest(
        'INVALID_ANIMAL_TYPE',
        `types に未対応の値が含まれています。許可値: ${ALLOWED_ANIMAL_TYPES.join(', ')}`,
        'types',
      );
    }
    accepted.add(part as AnimalType);
  }

  // 決定的なキャッシュキーを得るためソートする。
  return [...accepted].sort();
}

export function parseLimit(rawLimit: string | undefined): number {
  if (rawLimit === undefined || rawLimit.trim() === '') {
    return DEFAULT_LIMIT;
  }

  const trimmed = rawLimit.trim();
  // Number() は "0x10" や " 1e3" を通してしまうため、10 進整数の正規表現で縛る。
  if (!/^\d+$/.test(trimmed)) {
    throw ApiError.badRequest('INVALID_LIMIT', 'limit は 10 進の整数で指定してください。', 'limit');
  }

  const value = Number.parseInt(trimmed, 10);
  if (!Number.isSafeInteger(value) || value < MIN_LIMIT || value > MAX_LIMIT) {
    throw ApiError.badRequest(
      'INVALID_LIMIT',
      `limit は ${MIN_LIMIT} 以上 ${MAX_LIMIT} 以下で指定してください。`,
      'limit',
    );
  }

  return value;
}
