import {
  DAILY_PURGE_GRACE_MS,
  dailyCacheKey,
  jstDateString,
  nextJstMidnightMs,
  type CacheStore,
} from '../cache/store';
import { ApiError } from './errors';
import { fetchAnimals, type AggregateDeps } from './aggregate';
import { ALLOWED_ANIMAL_TYPES, type AnimalItem, type Warning } from './types';

/** クライアントへ返す本体（OpenAPI の DailyResponse と 1:1）。 */
export interface DailyResponse {
  /** JST の `YYYY-MM-DD`。 */
  date: string;
  item: AnimalItem;
  warnings: Warning[];
}

/** ハンドラー内部でのみ使う結果。`expiresAt` は Cache-Control の算出に使う。 */
export interface DailyResult extends DailyResponse {
  /** この応答が有効な期限（epoch ms）。返した `date` の JST 深夜 0 時。 */
  expiresAt: number;
}

/**
 * 「今日の1枚」(#35 連携)。
 *
 * JST 日付をキーに 1 日 1 件を固定する。
 * 一度確定したらその日の間はキャッシュから返し、外部 API を再度叩かない。
 *
 * 同時リクエストがそれぞれ別の画像を選んでしまわないよう、保存は create-if-absent で行い、
 * 競合に負けた側は「先に確定した方」の item を返す。
 */
export async function fetchDailyAnimal(deps: AggregateDeps): Promise<DailyResult> {
  const now = deps.now();
  const date = jstDateString(now);
  const expiresAt = nextJstMidnightMs(now);
  const key = dailyCacheKey(date);

  const cached = await safeGet(deps.store, key);
  if (cached !== null && cached.items.length > 0) {
    return { date, item: cached.items[0], warnings: [], expiresAt };
  }

  // 当日分が未確定なら通常の集約経路で候補を取り、1 件を選出して固定する。
  const result = await fetchAnimals({ types: [...ALLOWED_ANIMAL_TYPES], limit: 10 }, deps);

  const candidate = result.items[0];
  if (candidate === undefined) {
    throw ApiError.upstreamUnavailable('今日の1枚を選出できませんでした。');
  }

  let item = candidate;
  try {
    const stored = await deps.store.setIfAbsent(key, {
      items: [candidate],
      fetchedAt: now,
      expiresAt,
      // 日付が変わればキーも変わるので参照されなくなるが、
      // 削除直後の競合を避けて 1 日分の猶予をもって物理削除する。
      purgeAt: expiresAt + DAILY_PURGE_GRACE_MS,
    });
    if (stored.items.length > 0) {
      // 競合に負けた場合は、先に確定した item を返す（全員が同じ 1 枚を見る）。
      item = stored.items[0];
    }
  } catch {
    // 保存に失敗しても当日の応答自体は返す（次回リクエストで再選出される）。
  }

  return { date, item, warnings: result.warnings, expiresAt };
}

async function safeGet(store: CacheStore, key: string) {
  try {
    return await store.get(key);
  } catch {
    return null;
  }
}
