import {
  ANIMALS_STALE_MAX_AGE_MS,
  ANIMALS_TTL_MS,
  animalsCacheKey,
  type CacheEntry,
  type CacheStore,
} from '../cache/store';
import { cataasAdapter } from '../adapters/cataas';
import { dogCeoAdapter } from '../adapters/dogceo';
import type { AnimalAdapter } from '../adapters/adapter';
import { ApiError, ProviderError } from './errors';
import type { HttpBudget } from './httpClient';
import type {
  AnimalItem,
  AnimalType,
  AnimalsResponse,
  FetchLike,
  NormalizedAnimalsQuery,
  SourceId,
  Warning,
  WarningCode,
} from './types';

export interface AggregateDeps {
  fetch: FetchLike;
  store: CacheStore;
  /** 現在時刻（epoch ms）。テストで固定する。 */
  now: () => number;
  /** シャッフル・skip 用の乱数。テストで固定する。 */
  random?: () => number;
  sleep?: (ms: number) => Promise<void>;
  budget?: HttpBudget;
  /** テストや将来の差し替え用。既定は cataas / dogceo。 */
  adapters?: AnimalAdapter[];
}

const DEFAULT_ADAPTERS: AnimalAdapter[] = [cataasAdapter, dogCeoAdapter];

const WARNING_CODE_BY_KIND: Record<string, WarningCode> = {
  timeout: 'PROVIDER_TIMEOUT',
  unavailable: 'PROVIDER_UNAVAILABLE',
  invalid_response: 'PROVIDER_INVALID_RESPONSE',
};

/** ハンドラーへ返す集約結果。キャッシュ状態は Cache-Control 決定に使う。 */
export interface AggregateResult extends AnimalsResponse {
  cacheStatus: 'hit' | 'miss' | 'stale';
  /**
   * この内容の鮮度が切れる時刻（epoch ms）。
   *
   * cache hit のときは**元の取得時刻から数えた**期限であり、応答時刻から引き直したものではない。
   * ここを固定しないと、期限間際のキャッシュを返すたびに共有キャッシュの寿命が
   * 満了までリセットされ、実効的な鮮度が TTL の 2 倍近くまで伸びてしまう。
   */
  expiresAt: number;
}

/**
 * 検証済みクエリから複数プロバイダーを並行呼び出しし、共通形式へ集約する。
 *
 * 判定ルール:
 * - 全プロバイダー成功 → 200 / partial=false
 * - 一部成功          → 200 / partial=true + warnings（取得できた items は返す）
 * - 全失敗 + stale あり → 200 / partial=true + STALE_CACHE_SERVED
 * - 全失敗 + stale なし → ApiError(502, UPSTREAM_UNAVAILABLE)
 */
export async function fetchAnimals(
  query: NormalizedAnimalsQuery,
  deps: AggregateDeps,
): Promise<AggregateResult> {
  const now = deps.now();
  const key = animalsCacheKey(query);
  const adapters = selectAdapters(query.types, deps.adapters ?? DEFAULT_ADAPTERS);

  if (adapters.length === 0) {
    // 検証を通っている以上ここへは来ないが、フェイルオープンしないよう明示的に落とす。
    throw ApiError.upstreamUnavailable('対応する取得元がありません。');
  }

  const cached = await safeCacheGet(deps.store, key);
  if (cached !== null && cached.expiresAt > now && cached.items.length > 0) {
    return {
      items: cached.items,
      partial: false,
      warnings: [],
      cacheStatus: 'hit',
      // 元エントリの期限をそのまま使う（応答時刻から数え直さない）。
      expiresAt: cached.expiresAt,
    };
  }

  // 各プロバイダーへは「全体上限 ÷ プロバイダー数」ずつ要求する（切り上げ、最低 1）。
  const perProvider = Math.max(1, Math.ceil(query.limit / adapters.length));

  const settled = await Promise.allSettled(
    adapters.map((adapter) =>
      adapter.fetchItems(perProvider, {
        fetch: deps.fetch,
        ...(deps.sleep ? { sleep: deps.sleep } : {}),
        ...(deps.random ? { random: deps.random } : {}),
        ...(deps.budget ? { budget: deps.budget } : {}),
      }),
    ),
  );

  const collected: AnimalItem[] = [];
  const warnings: Warning[] = [];
  let succeeded = 0;

  settled.forEach((outcome, index) => {
    const source = adapters[index].source;
    if (outcome.status === 'fulfilled') {
      succeeded++;
      collected.push(...outcome.value);
      if (outcome.value.length === 0) {
        warnings.push({
          source,
          code: 'INSUFFICIENT_ITEMS',
          message: '取得元から利用可能な画像を取得できませんでした。',
        });
      }
      return;
    }
    warnings.push(toWarning(source, outcome.reason));
  });

  const items = shuffle(dedupeById(collected), deps.random ?? Math.random).slice(0, query.limit);

  if (succeeded === 0 || items.length === 0) {
    // 全滅。stale cache の利用可否を仕様どおりに判定する。
    if (
      cached !== null &&
      cached.items.length > 0 &&
      now - cached.fetchedAt <= ANIMALS_STALE_MAX_AGE_MS
    ) {
      return {
        items: cached.items,
        partial: true,
        warnings: [
          ...warnings,
          {
            source: null,
            code: 'STALE_CACHE_SERVED',
            message: '全ての取得元が失敗したため、期限切れのキャッシュを返しました。',
          },
        ],
        cacheStatus: 'stale',
        // 既に鮮度切れ。partial=true なので呼び出し側は no-store にする。
        expiresAt: cached.expiresAt,
      };
    }
    throw ApiError.upstreamUnavailable('全ての取得元から画像を取得できませんでした。');
  }

  const partial = warnings.length > 0;
  const expiresAt = now + ANIMALS_TTL_MS;

  // 部分失敗の結果を正規の TTL で焼き付けない（次リクエストで回復を試みる）。
  if (!partial) {
    await safeCacheSet(deps.store, key, {
      items,
      fetchedAt: now,
      // 鮮度は 5 分。ここを過ぎても stale フォールバック候補としては残す。
      expiresAt,
      // 物理削除は stale 期間の終わり。TTL ポリシーはこちらを対象にする。
      purgeAt: now + ANIMALS_STALE_MAX_AGE_MS,
    });
  }

  return { items, partial, warnings, cacheStatus: 'miss', expiresAt };
}

export function selectAdapters(types: AnimalType[], adapters: AnimalAdapter[]): AnimalAdapter[] {
  const wanted = new Set<AnimalType>(types);
  return adapters.filter((a) => wanted.has(a.type));
}

function toWarning(source: SourceId, reason: unknown): Warning {
  if (reason instanceof ProviderError) {
    return {
      source,
      code: WARNING_CODE_BY_KIND[reason.kind] ?? 'PROVIDER_UNAVAILABLE',
      message: reason.message,
    };
  }
  // 想定外の例外の詳細はクライアントへ出さない。
  return {
    source,
    code: 'PROVIDER_UNAVAILABLE',
    message: '取得元の呼び出しに失敗しました。',
  };
}

export function dedupeById(items: AnimalItem[]): AnimalItem[] {
  const seen = new Set<string>();
  const result: AnimalItem[] = [];
  for (const item of items) {
    if (seen.has(item.id)) continue;
    seen.add(item.id);
    result.push(item);
  }
  return result;
}

/** Fisher-Yates。乱数源は注入可能にしてテストを決定的にする。 */
export function shuffle<T>(input: T[], random: () => number): T[] {
  const arr = [...input];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/** キャッシュ障害でリクエスト全体を落とさない（キャッシュはあくまで最適化）。 */
async function safeCacheGet(store: CacheStore, key: string) {
  try {
    return await store.get(key);
  } catch {
    return null;
  }
}

async function safeCacheSet(store: CacheStore, key: string, entry: CacheEntry): Promise<void> {
  try {
    await store.set(key, entry);
  } catch {
    // 書き込み失敗は無視する。
  }
}
