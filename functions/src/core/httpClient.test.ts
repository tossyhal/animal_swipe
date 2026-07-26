import { describe, expect, it, vi } from 'vitest';
import { ProviderError } from './errors';
import { getJson, isRetryableStatus } from './httpClient';
import { abortError, jsonResponse, textResponse } from '../test/fakes';

const budget = { timeoutMs: 50, maxRetries: 1, backoffBaseMs: 10, maxBackoffMs: 20 };
const deps = (fetch: ReturnType<typeof vi.fn>) => ({
  fetch: fetch as never,
  sleep: async () => {
    /* テストでは待たない */
  },
  random: () => 0.5,
});

describe('getJson', () => {
  it('成功時に JSON を返す', async () => {
    const fetch = vi.fn(async () => jsonResponse({ ok: true }));
    await expect(getJson('https://cataas.com/api/cats', deps(fetch), budget)).resolves.toEqual({
      ok: true,
    });
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('タイムアウトは再試行し、上限に達したら timeout の ProviderError', async () => {
    const fetch = vi.fn(async () => {
      throw abortError();
    });
    await expect(getJson('https://cataas.com/api/cats', deps(fetch), budget)).rejects.toMatchObject({
      name: 'ProviderError',
      kind: 'timeout',
    });
    // maxRetries=1 なので合計 2 試行。無限リトライしないこと。
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('1 回目タイムアウト・2 回目成功なら結果を返す', async () => {
    const fetch = vi
      .fn()
      .mockRejectedValueOnce(abortError())
      .mockResolvedValueOnce(jsonResponse({ ok: true }));
    await expect(getJson('https://cataas.com/api/cats', deps(fetch), budget)).resolves.toEqual({
      ok: true,
    });
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('5xx は再試行する', async () => {
    const fetch = vi.fn(async () => jsonResponse({}, 503));
    await expect(getJson('https://dog.ceo/api', deps(fetch), budget)).rejects.toBeInstanceOf(
      ProviderError,
    );
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('429 は再試行する', async () => {
    const fetch = vi.fn(async () => jsonResponse({}, 429));
    await expect(getJson('https://dog.ceo/api', deps(fetch), budget)).rejects.toBeInstanceOf(
      ProviderError,
    );
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it.each([400, 403, 404, 422])('再試行不可の %i は 1 回で諦める', async (status) => {
    const fetch = vi.fn(async () => jsonResponse({}, status));
    await expect(getJson('https://dog.ceo/api', deps(fetch), budget)).rejects.toBeInstanceOf(
      ProviderError,
    );
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('壊れた JSON は再試行せず invalid_response', async () => {
    const fetch = vi.fn(async () => textResponse('<html>maintenance</html>'));
    await expect(getJson('https://dog.ceo/api', deps(fetch), budget)).rejects.toMatchObject({
      kind: 'invalid_response',
    });
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('本文読み取り中のタイムアウトは再試行し timeout として扱う', async () => {
    // ヘッダーは 200 だが body の消費中に abort する状況
    const fetch = vi.fn(async () => ({
      ok: true,
      status: 200,
      json: async () => {
        throw abortError();
      },
      text: async () => '',
    }));
    await expect(getJson('https://dog.ceo/api', deps(fetch), budget)).rejects.toMatchObject({
      kind: 'timeout',
    });
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('本文読み取り中の切断は再試行し unavailable として扱う', async () => {
    const fetch = vi.fn(async () => ({
      ok: true,
      status: 200,
      json: async () => {
        throw new TypeError('terminated');
      },
      text: async () => '',
    }));
    await expect(getJson('https://dog.ceo/api', deps(fetch), budget)).rejects.toMatchObject({
      kind: 'unavailable',
    });
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('本文読み取りが 1 回目だけ失敗するなら 2 回目の結果を返す', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => {
          throw abortError();
        },
        text: async () => '',
      })
      .mockResolvedValueOnce(jsonResponse({ ok: true }));
    await expect(getJson('https://dog.ceo/api', deps(fetch), budget)).resolves.toEqual({
      ok: true,
    });
  });

  it('バックオフには上限がある', async () => {
    const waits: number[] = [];
    const fetch = vi.fn(async () => jsonResponse({}, 500));
    await expect(
      getJson(
        'https://dog.ceo/api',
        {
          fetch: fetch as never,
          sleep: async (ms: number) => {
            waits.push(ms);
          },
          random: () => 1,
        },
        { timeoutMs: 50, maxRetries: 3, backoffBaseMs: 100, maxBackoffMs: 150 },
      ),
    ).rejects.toBeInstanceOf(ProviderError);
    expect(fetch).toHaveBeenCalledTimes(4);
    expect(waits).toEqual([100, 150, 150]);
  });

  it('AbortSignal 付きで呼び出す', async () => {
    let captured: AbortSignal | undefined;
    const fetch = vi.fn(async (_url: string, init?: { signal?: AbortSignal }) => {
      captured = init?.signal;
      return jsonResponse({});
    });
    await getJson('https://cataas.com/api/cats', deps(fetch), budget);
    expect(captured).toBeInstanceOf(AbortSignal);
  });
});

describe('isRetryableStatus', () => {
  it('429 と 5xx のみ true', () => {
    expect(isRetryableStatus(429)).toBe(true);
    expect(isRetryableStatus(500)).toBe(true);
    expect(isRetryableStatus(599)).toBe(true);
    expect(isRetryableStatus(400)).toBe(false);
    expect(isRetryableStatus(404)).toBe(false);
    expect(isRetryableStatus(200)).toBe(false);
  });
});
