import type { AnimalItem, NormalizedAnimalsQuery } from '../core/types';

/** キャッシュへ保存する 1 エントリ。 */
export interface CacheEntry {
  items: AnimalItem[];
  /** 取得時刻（epoch ms）。 */
  fetchedAt: number;
  /**
   * 鮮度の失効時刻（epoch ms）。これを過ぎた内容は「fresh ではない」が、
   * 全滅時の stale フォールバック候補としてはまだ使える。
   */
  expiresAt: number;
  /**
   * 物理削除の予定時刻（epoch ms）。**Firestore の TTL ポリシー対象はこちら。**
   *
   * `expiresAt` を TTL 対象にすると、stale として使いたい期間の開始と同時に
   * document が削除対象になり、全滅時のフォールバックが成立しなくなる。
   * そのため「鮮度」と「物理削除」を別のタイムスタンプで管理する。
   */
  purgeAt: number;
}

/**
 * TTL キャッシュの抽象。
 * Firestore 実装はこのインターフェースだけを満たす。テストは in-memory 実装を注入する。
 */
export interface CacheStore {
  /** 期限切れを含めて取得する（stale 判定は呼び出し側が expiresAt で行う）。 */
  get(key: string): Promise<CacheEntry | null>;
  set(key: string, entry: CacheEntry): Promise<void>;
  /**
   * 存在しない場合にのみ書き込む（create-if-absent）。
   *
   * 戻り値は「実際に保存されている方」のエントリ。競合したときは既存側が返る。
   * 「今日の1枚」を同時リクエスト間で 1 件に確定させるために使う。
   */
  setIfAbsent(key: string, entry: CacheEntry): Promise<CacheEntry>;
}

/** 何も保存しない no-op 実装（キャッシュ無効化やローカル実行用）。 */
export const nullCacheStore: CacheStore = {
  async get(): Promise<CacheEntry | null> {
    return null;
  },
  async set(): Promise<void> {
    // 何もしない
  },
  async setIfAbsent(_key: string, entry: CacheEntry): Promise<CacheEntry> {
    return entry;
  },
};

/** ランダム一覧の TTL。結果自体がランダムなので長い TTL は体験を損なう。 */
export const ANIMALS_TTL_MS = 5 * 60 * 1000;
/** 全プロバイダー失敗時に stale として再利用してよい上限。 */
export const ANIMALS_STALE_MAX_AGE_MS = 60 * 60 * 1000;
/**
 * 「今日の1枚」の document を物理削除するまでの猶予。
 * 日付が変わればキーが変わるため参照されなくなるが、
 * 削除直後に旧日付を読む競合を避けるため 1 日分の余裕を持たせる。
 */
export const DAILY_PURGE_GRACE_MS = 24 * 60 * 60 * 1000;

/**
 * キャッシュキーは「検証・正規化済み」のクエリからのみ生成する。
 * 生のクエリ文字列を混ぜないことでキー汚染（cache poisoning）を防ぐ。
 */
export function animalsCacheKey(query: NormalizedAnimalsQuery): string {
  return `animals:v1:${query.types.join('+')}:${query.limit}`;
}

/** 「今日の1枚」のキャッシュキー。JST の日付で 1 日 1 件に固定する。 */
export function dailyCacheKey(jstDate: string): string {
  return `daily:v1:${jstDate}`;
}

/** epoch ms から JST の `YYYY-MM-DD` を求める。 */
export function jstDateString(nowMs: number): string {
  const jst = new Date(nowMs + 9 * 60 * 60 * 1000);
  const y = jst.getUTCFullYear();
  const m = String(jst.getUTCMonth() + 1).padStart(2, '0');
  const d = String(jst.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** 次の JST 深夜 0 時（= 「今日の1枚」の失効時刻）を epoch ms で返す。 */
export function nextJstMidnightMs(nowMs: number): number {
  const OFFSET = 9 * 60 * 60 * 1000;
  const DAY = 24 * 60 * 60 * 1000;
  const jstMs = nowMs + OFFSET;
  return Math.floor(jstMs / DAY + 1) * DAY - OFFSET;
}
