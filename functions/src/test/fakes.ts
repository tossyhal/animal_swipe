import { vi } from 'vitest';
import type { CacheEntry, CacheStore } from '../cache/store';
import type { AggregateDeps } from '../core/aggregate';
import type { FetchLike, FetchLikeResponse } from '../core/types';

/** テスト用の in-memory CacheStore。Firestore へは一切触れない。 */
export function createMemoryStore(seed: Record<string, CacheEntry> = {}): CacheStore & {
  data: Map<string, CacheEntry>;
} {
  const data = new Map<string, CacheEntry>(Object.entries(seed));
  return {
    data,
    async get(key: string): Promise<CacheEntry | null> {
      return data.get(key) ?? null;
    },
    async set(key: string, entry: CacheEntry): Promise<void> {
      data.set(key, entry);
    },
    async setIfAbsent(key: string, entry: CacheEntry): Promise<CacheEntry> {
      const existing = data.get(key);
      if (existing !== undefined && existing.items.length > 0) return existing;
      data.set(key, entry);
      return entry;
    },
  };
}

export function jsonResponse(body: unknown, status = 200): FetchLikeResponse {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
    text: async () => JSON.stringify(body),
  };
}

export function textResponse(text: string, status = 200): FetchLikeResponse {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => {
      throw new SyntaxError('invalid json');
    },
    text: async () => text,
  };
}

/** タイムアウト（AbortSignal.timeout 相当）を模した拒否。 */
export function abortError(): Error {
  const err = new Error('The operation was aborted due to timeout');
  err.name = 'TimeoutError';
  return err;
}

/** URL 部分一致でレスポンスを決めるルーター型の fake fetch。 */
export function createFakeFetch(
  routes: Array<{ match: string; respond: () => Promise<FetchLikeResponse> }>,
) {
  const calls: string[] = [];
  const fn = vi.fn<FetchLike>(async (url: string) => {
    calls.push(url);
    for (const route of routes) {
      if (url.includes(route.match)) {
        return route.respond();
      }
    }
    throw new Error(`unexpected fetch: ${url}`);
  });
  return Object.assign(fn, { calls });
}

/** 実時間を待たない sleep と決定的な乱数を含む既定の依存一式。 */
export function baseDeps(overrides: Partial<AggregateDeps> = {}): AggregateDeps {
  return {
    fetch: createFakeFetch([]),
    store: createMemoryStore(),
    now: () => 1_700_000_000_000,
    random: () => 0.5,
    sleep: async () => {
      /* テストでは待たない */
    },
    budget: { timeoutMs: 50, maxRetries: 1, backoffBaseMs: 1, maxBackoffMs: 2 },
    ...overrides,
  };
}

export const CATAAS_PAYLOAD = [
  { id: 'cat-1', tags: [] },
  { id: 'cat-2', tags: [] },
  { id: 'cat-3', tags: [] },
];

export const DOGCEO_PAYLOAD = {
  status: 'success',
  message: [
    'https://images.dog.ceo/breeds/hound-afghan/n02088094_1003.jpg',
    'https://images.dog.ceo/breeds/beagle/n02088364_11136.jpg',
    'https://images.dog.ceo/breeds/pug/n02110958_15626.jpg',
  ],
};
