import { describe, expect, it } from 'vitest';
import { ANIMALS_STALE_MAX_AGE_MS, ANIMALS_TTL_MS, animalsCacheKey } from '../cache/store';
import { dedupeById, fetchAnimals } from './aggregate';
import { ApiError } from './errors';
import {
  CATAAS_PAYLOAD,
  DOGCEO_PAYLOAD,
  abortError,
  baseDeps,
  createFakeFetch,
  createMemoryStore,
  jsonResponse,
} from '../test/fakes';

const NOW = 1_700_000_000_000;
const QUERY = { types: ['cat', 'dog'] as const, limit: 10 };
const query = () => ({ types: [...QUERY.types], limit: QUERY.limit });

function bothOk() {
  return createFakeFetch([
    { match: 'cataas.com', respond: async () => jsonResponse(CATAAS_PAYLOAD) },
    { match: 'dog.ceo', respond: async () => jsonResponse(DOGCEO_PAYLOAD) },
  ]);
}

describe('fetchAnimals: 全成功', () => {
  it('partial=false で両プロバイダーの items を返す', async () => {
    const store = createMemoryStore();
    const result = await fetchAnimals(query(), baseDeps({ fetch: bothOk(), store }));

    expect(result.partial).toBe(false);
    expect(result.warnings).toEqual([]);
    expect(result.cacheStatus).toBe('miss');
    expect(result.items).toHaveLength(6);
    expect(new Set(result.items.map((i) => i.source))).toEqual(new Set(['cataas', 'dogceo']));
  });

  it('limit を超えない', async () => {
    const result = await fetchAnimals(
      { types: ['cat', 'dog'], limit: 2 },
      baseDeps({ fetch: bothOk() }),
    );
    expect(result.items.length).toBeLessThanOrEqual(2);
  });

  it('types で adapter を絞り込む', async () => {
    const fetch = bothOk();
    const result = await fetchAnimals({ types: ['dog'], limit: 10 }, baseDeps({ fetch }));
    expect(fetch.calls.every((u) => u.includes('dog.ceo'))).toBe(true);
    expect(result.items.every((i) => i.type === 'dog')).toBe(true);
  });

  it('成功結果を TTL 付きでキャッシュへ書く', async () => {
    const store = createMemoryStore();
    await fetchAnimals(query(), baseDeps({ fetch: bothOk(), store }));

    const entry = store.data.get(animalsCacheKey(query()));
    expect(entry).toBeDefined();
    expect(entry!.fetchedAt).toBe(NOW);
    expect(entry!.expiresAt).toBe(NOW + ANIMALS_TTL_MS);
    // 物理削除は stale 期間の終わり。expiresAt を TTL 対象にすると
    // stale フォールバックが始まる瞬間に document が消え得る。
    expect(entry!.purgeAt).toBe(NOW + ANIMALS_STALE_MAX_AGE_MS);
    expect(entry!.purgeAt).toBeGreaterThan(entry!.expiresAt);
  });

  it('有効なキャッシュがあれば外部 API を呼ばない', async () => {
    const fetch = bothOk();
    const store = createMemoryStore({
      [animalsCacheKey(query())]: {
        items: [
          {
            id: 'cataas:cached',
            type: 'cat',
            imageUrl: 'https://cataas.com/cat/cached?width=800',
            breed: null,
            source: 'cataas',
          },
        ],
        fetchedAt: NOW - 1000,
        expiresAt: NOW + 1000,
        purgeAt: NOW + ANIMALS_STALE_MAX_AGE_MS,
      },
    });

    const result = await fetchAnimals(query(), baseDeps({ fetch, store }));
    expect(fetch).not.toHaveBeenCalled();
    expect(result.cacheStatus).toBe('hit');
    expect(result.items[0].id).toBe('cataas:cached');
  });
});

describe('fetchAnimals: 部分失敗', () => {
  it('片方失敗でも取得できた items を返し partial=true と warnings を付ける', async () => {
    const fetch = createFakeFetch([
      {
        match: 'cataas.com',
        respond: async () => {
          throw abortError();
        },
      },
      { match: 'dog.ceo', respond: async () => jsonResponse(DOGCEO_PAYLOAD) },
    ]);

    const result = await fetchAnimals(query(), baseDeps({ fetch }));

    expect(result.partial).toBe(true);
    expect(result.items.length).toBeGreaterThan(0);
    expect(result.items.every((i) => i.source === 'dogceo')).toBe(true);
    expect(result.warnings).toEqual([
      { source: 'cataas', code: 'PROVIDER_TIMEOUT', message: expect.any(String) },
    ]);
  });

  it('部分失敗の結果はキャッシュへ書かない', async () => {
    const store = createMemoryStore();
    const fetch = createFakeFetch([
      { match: 'cataas.com', respond: async () => jsonResponse({}, 500) },
      { match: 'dog.ceo', respond: async () => jsonResponse(DOGCEO_PAYLOAD) },
    ]);

    await fetchAnimals(query(), baseDeps({ fetch, store }));
    expect(store.data.size).toBe(0);
  });

  it('契約違反レスポンスは PROVIDER_INVALID_RESPONSE になる', async () => {
    const fetch = createFakeFetch([
      { match: 'cataas.com', respond: async () => jsonResponse({ not: 'an array' }) },
      { match: 'dog.ceo', respond: async () => jsonResponse(DOGCEO_PAYLOAD) },
    ]);
    const result = await fetchAnimals(query(), baseDeps({ fetch }));
    expect(result.warnings[0]).toMatchObject({
      source: 'cataas',
      code: 'PROVIDER_INVALID_RESPONSE',
    });
  });

  it('成功したが 0 件のプロバイダーには INSUFFICIENT_ITEMS を出す', async () => {
    const fetch = createFakeFetch([
      { match: 'cataas.com', respond: async () => jsonResponse([]) },
      { match: 'dog.ceo', respond: async () => jsonResponse(DOGCEO_PAYLOAD) },
    ]);
    const result = await fetchAnimals(query(), baseDeps({ fetch }));
    expect(result.partial).toBe(true);
    expect(result.warnings[0]).toMatchObject({ source: 'cataas', code: 'INSUFFICIENT_ITEMS' });
  });
});

describe('fetchAnimals: 全体失敗', () => {
  it('stale cache が無ければ 502 UPSTREAM_UNAVAILABLE', async () => {
    const fetch = createFakeFetch([
      {
        match: 'cataas.com',
        respond: async () => {
          throw abortError();
        },
      },
      {
        match: 'dog.ceo',
        respond: async () => {
          throw abortError();
        },
      },
    ]);

    await expect(fetchAnimals(query(), baseDeps({ fetch }))).rejects.toMatchObject({
      status: 502,
      code: 'UPSTREAM_UNAVAILABLE',
    });
  });

  it('期限切れでも許容範囲内の stale cache があれば 200 相当で返す', async () => {
    const store = createMemoryStore({
      [animalsCacheKey(query())]: {
        items: [
          {
            id: 'cataas:stale',
            type: 'cat',
            imageUrl: 'https://cataas.com/cat/stale?width=800',
            breed: null,
            source: 'cataas',
          },
        ],
        // TTL(5分) は切れているが stale 上限(60分) 以内
        fetchedAt: NOW - 10 * 60 * 1000,
        expiresAt: NOW - 5 * 60 * 1000,
        purgeAt: NOW + 50 * 60 * 1000,
      },
    });
    const fetch = createFakeFetch([
      {
        match: 'cataas.com',
        respond: async () => {
          throw abortError();
        },
      },
      {
        match: 'dog.ceo',
        respond: async () => {
          throw abortError();
        },
      },
    ]);

    const result = await fetchAnimals(query(), baseDeps({ fetch, store }));
    expect(result.cacheStatus).toBe('stale');
    expect(result.partial).toBe(true);
    expect(result.items[0].id).toBe('cataas:stale');
    expect(result.warnings.some((w) => w.code === 'STALE_CACHE_SERVED')).toBe(true);
  });

  it('stale 上限を超えたキャッシュは使わず 502', async () => {
    const store = createMemoryStore({
      [animalsCacheKey(query())]: {
        items: [
          {
            id: 'cataas:too-old',
            type: 'cat',
            imageUrl: 'https://cataas.com/cat/too-old?width=800',
            breed: null,
            source: 'cataas',
          },
        ],
        fetchedAt: NOW - 3 * 60 * 60 * 1000,
        expiresAt: NOW - 2 * 60 * 60 * 1000,
        purgeAt: NOW - 2 * 60 * 60 * 1000,
      },
    });
    const fetch = createFakeFetch([
      {
        match: 'cataas.com',
        respond: async () => {
          throw abortError();
        },
      },
      {
        match: 'dog.ceo',
        respond: async () => {
          throw abortError();
        },
      },
    ]);

    await expect(fetchAnimals(query(), baseDeps({ fetch, store }))).rejects.toBeInstanceOf(ApiError);
  });

  it('キャッシュストアの障害でリクエスト全体が落ちない', async () => {
    const brokenStore = {
      get: async () => {
        throw new Error('firestore down');
      },
      set: async () => {
        throw new Error('firestore down');
      },
      setIfAbsent: async () => {
        throw new Error('firestore down');
      },
    };
    const result = await fetchAnimals(query(), baseDeps({ fetch: bothOk(), store: brokenStore }));
    expect(result.items.length).toBe(6);
  });
});

describe('dedupeById', () => {
  it('同一 ID を 1 件に畳む', () => {
    const item = {
      id: 'cataas:a',
      type: 'cat' as const,
      imageUrl: 'https://cataas.com/cat/a?width=800',
      breed: null,
      source: 'cataas' as const,
    };
    expect(dedupeById([item, { ...item }, { ...item, id: 'cataas:b' }])).toHaveLength(2);
  });
});
