import { Firestore, Timestamp } from 'firebase-admin/firestore';
import type { AnimalItem } from '../core/types';
import type { CacheEntry, CacheStore } from './store';

/**
 * Firestore を使った TTL キャッシュ実装。
 *
 * このファイルだけが firebase-admin に依存する。
 *
 * TTL ポリシーは **`purgeAt`** に設定する（`expiresAt` ではない）。
 * `expiresAt` は「鮮度」の境界で、そこから stale フォールバック期間が始まる。
 * `expiresAt` を TTL 対象にすると、stale として使いたい瞬間に document が
 * 削除対象になり、全滅時のフォールバックが成立しない。
 *
 *   gcloud firestore fields ttls update purgeAt \
 *     --collection-group=api_cache --enable-ttl
 */
export const CACHE_COLLECTION = 'api_cache';

export function createFirestoreCacheStore(db: Firestore): CacheStore {
  const docRef = (key: string) => db.collection(CACHE_COLLECTION).doc(encodeKey(key));

  return {
    async get(key: string): Promise<CacheEntry | null> {
      const snapshot = await docRef(key).get();
      if (!snapshot.exists) return null;
      return decodeEntry(snapshot.data());
    },

    async set(key: string, entry: CacheEntry): Promise<void> {
      await docRef(key).set(encodeEntry(entry));
    },

    /**
     * トランザクションで create-if-absent を行う。
     * 同時に「今日の1枚」を選出した複数リクエストのうち、最初の 1 件だけが確定する。
     */
    async setIfAbsent(key: string, entry: CacheEntry): Promise<CacheEntry> {
      const ref = docRef(key);
      return db.runTransaction(async (tx) => {
        const snapshot = await tx.get(ref);
        if (snapshot.exists) {
          const existing = decodeEntry(snapshot.data());
          // 壊れたデータが入っていた場合のみ上書きする。
          if (existing !== null && existing.items.length > 0) {
            return existing;
          }
        }
        tx.set(ref, encodeEntry(entry));
        return entry;
      });
    },
  };
}

function encodeEntry(entry: CacheEntry): Record<string, unknown> {
  return {
    items: entry.items,
    fetchedAt: Timestamp.fromMillis(entry.fetchedAt),
    expiresAt: Timestamp.fromMillis(entry.expiresAt),
    // TTL ポリシー対象。Timestamp 型でなければ TTL は機能しない。
    purgeAt: Timestamp.fromMillis(entry.purgeAt),
  };
}

/** Firestore の document ID に `/` は使えないため置換する。 */
export function encodeKey(key: string): string {
  return key.replace(/\//g, '_');
}

/** 保存済みデータを検証しつつ CacheEntry へ戻す。壊れていれば null（= cache miss）。 */
export function decodeEntry(data: unknown): CacheEntry | null {
  if (typeof data !== 'object' || data === null) return null;
  const record = data as Record<string, unknown>;

  const fetchedAt = toMillis(record.fetchedAt);
  const expiresAt = toMillis(record.expiresAt);
  if (fetchedAt === null || expiresAt === null) return null;
  if (!Array.isArray(record.items)) return null;

  // purgeAt は後方互換のため任意。欠けていれば expiresAt を流用する。
  const purgeAt = toMillis(record.purgeAt) ?? expiresAt;

  return { items: record.items as AnimalItem[], fetchedAt, expiresAt, purgeAt };
}

function toMillis(value: unknown): number | null {
  if (value instanceof Timestamp) return value.toMillis();
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (
    typeof value === 'object' &&
    value !== null &&
    typeof (value as { toMillis?: unknown }).toMillis === 'function'
  ) {
    return (value as { toMillis: () => number }).toMillis();
  }
  return null;
}
