import { describe, expect, it } from 'vitest';
import {
  CATAAS_PAYLOAD,
  DOGCEO_PAYLOAD,
  abortError,
  baseDeps,
  createFakeFetch,
  createMemoryStore,
  jsonResponse,
} from '../test/fakes';
import { handleRequest, normalizePath, type HttpRequestLike } from './handler';
import {
  animalsCacheKey,
  dailyCacheKey,
  jstDateString,
  nextJstMidnightMs,
} from '../cache/store';

const ORIGIN = 'https://animal-swipe-596cc.web.app';

function request(overrides: Partial<HttpRequestLike> = {}): HttpRequestLike {
  return {
    method: 'GET',
    path: '/api/v1/animals',
    query: {},
    headers: { origin: ORIGIN },
    ...overrides,
  };
}

function bothOk() {
  return createFakeFetch([
    { match: 'cataas.com', respond: async () => jsonResponse(CATAAS_PAYLOAD) },
    { match: 'dog.ceo', respond: async () => jsonResponse(DOGCEO_PAYLOAD) },
  ]);
}

function bothDown() {
  return createFakeFetch([
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
}

describe('ステータスコード表', () => {
  it('全成功 -> 200 / partial=false', async () => {
    const res = await handleRequest(request(), baseDeps({ fetch: bothOk() }));
    expect(res.status).toBe(200);
    expect((res.body as { partial: boolean }).partial).toBe(false);
    expect(res.headers['Cache-Control']).toContain('s-maxage=300');
  });

  it('期限間際のキャッシュヒットで s-maxage を満了までリセットしない', async () => {
    const now = 1_700_000_000_000;
    const fetch = bothOk();
    // 残り 30 秒のエントリ
    const store = createMemoryStore({
      [animalsCacheKey({ types: ['cat', 'dog'], limit: 10 })]: {
        items: [
          {
            id: 'cataas:aged',
            type: 'cat',
            imageUrl: 'https://cataas.com/cat/aged?width=800',
            breed: null,
            source: 'cataas',
          },
        ],
        fetchedAt: now - 270_000,
        expiresAt: now + 30_000,
        purgeAt: now + 3_330_000,
      },
    });

    const res = await handleRequest(request(), baseDeps({ fetch, store, now: () => now }));

    expect(res.headers['X-Cache']).toBe('hit');
    expect(fetch).toHaveBeenCalledTimes(0);
    // 300 ではなく、元エントリの残り寿命
    expect(res.headers['Cache-Control']).toBe('public, max-age=0, s-maxage=30');
  });

  it('部分成功 -> 200 / partial=true / no-store', async () => {
    const fetch = createFakeFetch([
      {
        match: 'cataas.com',
        respond: async () => {
          throw abortError();
        },
      },
      { match: 'dog.ceo', respond: async () => jsonResponse(DOGCEO_PAYLOAD) },
    ]);
    const res = await handleRequest(request(), baseDeps({ fetch }));
    expect(res.status).toBe(200);
    const body = res.body as { partial: boolean; warnings: unknown[] };
    expect(body.partial).toBe(true);
    expect(body.warnings).toHaveLength(1);
    expect(res.headers['Cache-Control']).toBe('no-store');
  });

  it('全体失敗 + stale なし -> 502 UPSTREAM_UNAVAILABLE', async () => {
    const res = await handleRequest(request(), baseDeps({ fetch: bothDown() }));
    expect(res.status).toBe(502);
    expect(res.body).toEqual({
      error: { code: 'UPSTREAM_UNAVAILABLE', message: expect.any(String) },
    });
  });

  it('不正な types -> 400 かつ外部 API を一切呼ばない', async () => {
    const fetch = bothOk();
    const res = await handleRequest(
      request({ query: { types: 'https://evil.example/x.jpg' } }),
      baseDeps({ fetch }),
    );
    expect(res.status).toBe(400);
    expect((res.body as { error: { code: string } }).error.code).toBe('INVALID_ANIMAL_TYPE');
    // オープンプロキシ化していないことの中核アサーション
    expect(fetch).toHaveBeenCalledTimes(0);
  });

  it('不正な limit -> 400 かつ外部 API を一切呼ばない', async () => {
    const fetch = bothOk();
    const res = await handleRequest(request({ query: { limit: '9999' } }), baseDeps({ fetch }));
    expect(res.status).toBe(400);
    expect((res.body as { error: { code: string } }).error.code).toBe('INVALID_LIMIT');
    expect(fetch).toHaveBeenCalledTimes(0);
  });

  it.each([
    { types: { evil: 'cat' } },
    { types: [['cat']] },
    { limit: { x: '1' } },
    { limit: [['5']] },
  ])('構造化されたクエリ %s -> 400（500 にしない）', async (query) => {
    const fetch = bothOk();
    const res = await handleRequest(request({ query }), baseDeps({ fetch }));
    expect(res.status).toBe(400);
    expect(fetch).toHaveBeenCalledTimes(0);
  });

  it('未知のパス -> 404', async () => {
    const res = await handleRequest(request({ path: '/api/v1/unknown' }), baseDeps());
    expect(res.status).toBe(404);
    expect((res.body as { error: { code: string } }).error.code).toBe('NOT_FOUND');
  });

  it.each(['POST', 'PUT', 'DELETE', 'PATCH'])('%s -> 405', async (method) => {
    const fetch = bothOk();
    const res = await handleRequest(request({ method }), baseDeps({ fetch }));
    expect(res.status).toBe(405);
    expect(res.headers.Allow).toBe('GET, OPTIONS');
    expect(fetch).toHaveBeenCalledTimes(0);
  });

  it('OPTIONS -> 204 プリフライト', async () => {
    const res = await handleRequest(request({ method: 'OPTIONS' }), baseDeps());
    expect(res.status).toBe(204);
    expect(res.headers['Access-Control-Allow-Methods']).toBe('GET, OPTIONS');
  });
});

describe('任意 URL を取得できないこと', () => {
  it.each([
    'https://evil.example/x.jpg',
    'http://169.254.169.254/latest/meta-data/',
    'file:///etc/passwd',
    'cat,https://evil.example',
    '../../etc/passwd',
    'bird',
  ])('types=%s は 400 で、fetch は 0 回', async (value) => {
    const fetch = bothOk();
    const res = await handleRequest(request({ query: { types: value } }), baseDeps({ fetch }));
    expect(res.status).toBe(400);
    expect(fetch).toHaveBeenCalledTimes(0);
  });

  it('url / imageUrl / src といった任意 URL パラメータは無視される', async () => {
    const fetch = bothOk();
    const res = await handleRequest(
      request({
        query: {
          url: 'https://evil.example/x.jpg',
          imageUrl: 'https://evil.example/y.jpg',
          src: 'http://169.254.169.254/',
        },
      }),
      baseDeps({ fetch }),
    );
    expect(res.status).toBe(200);
    // 外部呼び出し先は adapter が組み立てた許可ホストのみ
    for (const call of fetch.calls) {
      const host = new URL(call).hostname;
      expect(['cataas.com', 'dog.ceo']).toContain(host);
    }
  });

  it('プロバイダーが敵対的な URL を返しても items に混入しない', async () => {
    const fetch = createFakeFetch([
      { match: 'cataas.com', respond: async () => jsonResponse([]) },
      {
        match: 'dog.ceo',
        respond: async () =>
          jsonResponse({
            status: 'success',
            message: [
              'http://evil.example/x.jpg',
              'https://evil.example/x.jpg',
              'https://images.dog.ceo.evil.example/x.jpg',
              'https://evilimages.dog.ceo/x.jpg',
              'https://images.dog.ceo/breeds/pug/ok.jpg',
            ],
          }),
      },
    ]);

    const res = await handleRequest(request(), baseDeps({ fetch }));
    expect(res.status).toBe(200);
    const items = (res.body as { items: Array<{ imageUrl: string }> }).items;
    expect(items.map((i) => i.imageUrl)).toEqual(['https://images.dog.ceo/breeds/pug/ok.jpg']);
    for (const item of items) {
      const url = new URL(item.imageUrl);
      expect(url.protocol).toBe('https:');
      expect(['cataas.com', 'images.dog.ceo']).toContain(url.hostname);
    }
  });
});

describe('CORS', () => {
  it('許可 origin は完全一致でエコーする', async () => {
    const res = await handleRequest(request(), baseDeps({ fetch: bothOk() }));
    expect(res.headers['Access-Control-Allow-Origin']).toBe(ORIGIN);
    expect(res.headers.Vary).toBe('Origin');
  });

  it.each([
    'https://evil.example',
    'https://animal-swipe-596cc.web.app.evil.example',
    'http://animal-swipe-596cc.web.app',
    'https://animal-swipe-596cc.firebaseapp.com',
  ])('許可外 origin %s には CORS ヘッダーを付けない', async (origin) => {
    const res = await handleRequest(
      request({ headers: { origin } }),
      baseDeps({ fetch: bothOk() }),
    );
    expect(res.headers['Access-Control-Allow-Origin']).toBeUndefined();
  });

  it('ワイルドカードを返さない', async () => {
    const res = await handleRequest(request(), baseDeps({ fetch: bothOk() }));
    expect(res.headers['Access-Control-Allow-Origin']).not.toBe('*');
  });
});

describe('今日の1枚', () => {
  it('1 日 1 件を選出し、2 回目はキャッシュから返す', async () => {
    const store = createMemoryStore();
    const fetch = bothOk();
    const deps = baseDeps({ fetch, store });

    const first = await handleRequest(request({ path: '/api/v1/animals/daily' }), deps);
    expect(first.status).toBe(200);
    const firstBody = first.body as { date: string; item: { id: string } };
    expect(firstBody.date).toBe(jstDateString(deps.now()));
    expect(store.data.has(dailyCacheKey(firstBody.date))).toBe(true);

    const callsAfterFirst = fetch.mock.calls.length;
    const second = await handleRequest(request({ path: '/api/v1/animals/daily' }), deps);
    expect((second.body as { item: { id: string } }).item.id).toBe(firstBody.item.id);
    expect(fetch.mock.calls.length).toBe(callsAfterFirst);
  });

  it('全体失敗時は 502', async () => {
    const res = await handleRequest(
      request({ path: '/api/v1/animals/daily' }),
      baseDeps({ fetch: bothDown() }),
    );
    expect(res.status).toBe(502);
  });

  it('s-maxage は返した date の JST 深夜 0 時までに収まる', async () => {
    // JST 23:00 = UTC 14:00。残り 1 時間。
    const now = Date.parse('2024-01-01T14:00:00Z');
    const res = await handleRequest(
      request({ path: '/api/v1/animals/daily' }),
      baseDeps({ fetch: bothOk(), now: () => now }),
    );
    expect(res.headers['Cache-Control']).toBe('public, max-age=0, s-maxage=3600');
    expect((res.body as { date: string }).date).toBe('2024-01-01');
  });

  it('処理中に JST 深夜 0 時を跨いでも前日分を丸一日キャッシュさせない', async () => {
    // fetchDailyAnimal 開始時は 2024-01-01 23:59:59 JST。
    // 応答ヘッダー算出時には日付が変わっている状況を模す。
    const start = Date.parse('2024-01-01T14:59:59Z');
    let calls = 0;
    const now = () => {
      calls += 1;
      // 最初の 1 回（fetchDailyAnimal 内の日付決定）以外は 1 分後を返す。
      return calls <= 1 ? start : start + 61_000;
    };

    const res = await handleRequest(
      request({ path: '/api/v1/animals/daily' }),
      baseDeps({ fetch: bothOk(), now }),
    );

    expect((res.body as { date: string }).date).toBe('2024-01-01');
    // 前日の 1 枚を新しい日付いっぱい（〜24時間）キャッシュさせない
    expect(res.headers['Cache-Control']).toBe('no-store');
  });

  it('同時リクエストが競合しても全員が同じ 1 枚を受け取る', async () => {
    const store = createMemoryStore();
    const deps = baseDeps({ fetch: bothOk(), store });

    const results = await Promise.all([
      handleRequest(request({ path: '/api/v1/animals/daily' }), deps),
      handleRequest(request({ path: '/api/v1/animals/daily' }), deps),
      handleRequest(request({ path: '/api/v1/animals/daily' }), deps),
    ]);

    const ids = results.map((r) => (r.body as { item: { id: string } }).item.id);
    expect(new Set(ids).size).toBe(1);
    // 保存されている 1 枚とも一致する
    const stored = store.data.get(dailyCacheKey(jstDateString(deps.now())));
    expect(stored!.items[0].id).toBe(ids[0]);
  });

  it('保存エントリは expiresAt より後に purgeAt を持つ', async () => {
    const store = createMemoryStore();
    const deps = baseDeps({ fetch: bothOk(), store });
    await handleRequest(request({ path: '/api/v1/animals/daily' }), deps);

    const stored = store.data.get(dailyCacheKey(jstDateString(deps.now())))!;
    expect(stored.expiresAt).toBe(nextJstMidnightMs(deps.now()));
    expect(stored.purgeAt).toBeGreaterThan(stored.expiresAt);
  });
});

describe('normalizePath', () => {
  it('末尾スラッシュとクエリを取り除く', () => {
    expect(normalizePath('/api/v1/animals/')).toBe('/api/v1/animals');
    expect(normalizePath('/api/v1/animals?types=cat')).toBe('/api/v1/animals');
    expect(normalizePath('/')).toBe('/');
  });
});
