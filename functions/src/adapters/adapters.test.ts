import { describe, expect, it } from 'vitest';
import { ProviderError } from '../core/errors';
import { CATAAS_PAYLOAD, DOGCEO_PAYLOAD, createFakeFetch, jsonResponse } from '../test/fakes';
import { cataasAdapter, normalizeCataas } from './cataas';
import { breedFromUrl, dogCeoAdapter, normalizeDogCeo } from './dogceo';

const budget = { timeoutMs: 50, maxRetries: 0, backoffBaseMs: 1, maxBackoffMs: 1 };

describe('cataas adapter', () => {
  it('共通形式へ正規化する', () => {
    const items = normalizeCataas(CATAAS_PAYLOAD);
    expect(items).toHaveLength(3);
    expect(items[0]).toEqual({
      id: 'cataas:cat-1',
      type: 'cat',
      imageUrl: 'https://cataas.com/cat/cat-1?width=800',
      breed: null,
      source: 'cataas',
    });
  });

  it('_id 形式も受け付け、ID を取り出せない要素は捨てる', () => {
    const items = normalizeCataas([
      { _id: 'x1' },
      { id: '' },
      { nothing: true },
      null,
      'string',
      42,
    ]);
    expect(items.map((i) => i.id)).toEqual(['cataas:x1']);
  });

  it('配列以外は invalid_response', () => {
    expect(() => normalizeCataas({ foo: 'bar' })).toThrowError(ProviderError);
  });

  it('外部が返した URL ではなく検証済み ID から imageUrl を組み立てる', () => {
    const items = normalizeCataas([{ id: 'abc', url: 'https://evil.example/pwn.jpg' }]);
    expect(items[0].imageUrl).toBe('https://cataas.com/cat/abc?width=800');
  });

  it('limit と skip 付きで cataas を呼ぶ', async () => {
    const fetch = createFakeFetch([
      { match: 'cataas.com/api/cats', respond: async () => jsonResponse(CATAAS_PAYLOAD) },
    ]);
    const items = await cataasAdapter.fetchItems(5, { fetch, random: () => 0.5, budget });
    expect(fetch.calls[0]).toBe('https://cataas.com/api/cats?limit=5&skip=500');
    expect(items).toHaveLength(3);
  });
});

describe('dogceo adapter', () => {
  it('共通形式へ正規化し、品種を URL から復元する', () => {
    const items = normalizeDogCeo(DOGCEO_PAYLOAD);
    expect(items).toHaveLength(3);
    expect(items[0]).toEqual({
      id: 'dogceo:breeds/hound-afghan/n02088094_1003.jpg',
      type: 'dog',
      imageUrl: 'https://images.dog.ceo/breeds/hound-afghan/n02088094_1003.jpg',
      breed: 'Afghan Hound',
      source: 'dogceo',
    });
    expect(items[1].breed).toBe('Beagle');
  });

  it('許可ホスト外・非 HTTPS の URL は items に現れない', () => {
    const items = normalizeDogCeo({
      status: 'success',
      message: [
        'http://evil.example/x.jpg',
        'https://evil.example/x.jpg',
        'https://images.dog.ceo.evil.example/x.jpg',
        'https://notimages.dog.ceo/x.jpg',
        'file:///etc/passwd',
        'https://images.dog.ceo/breeds/pug/ok.jpg',
      ],
    });
    expect(items.map((i) => i.imageUrl)).toEqual(['https://images.dog.ceo/breeds/pug/ok.jpg']);
    for (const item of items) {
      expect(new URL(item.imageUrl).hostname).toBe('images.dog.ceo');
    }
  });

  it('同一 URL は重複排除される', () => {
    const url = 'https://images.dog.ceo/breeds/pug/a.jpg';
    const items = normalizeDogCeo({ status: 'success', message: [url, url] });
    expect(items).toHaveLength(1);
  });

  it.each([
    { status: 'error', message: [] },
    { status: 'success', message: 'not-an-array' },
    [],
    'string',
    null,
  ])('契約違反のレスポンス %s は invalid_response', (payload) => {
    expect(() => normalizeDogCeo(payload)).toThrowError(ProviderError);
  });

  it('count を URL パスへ渡す', async () => {
    const fetch = createFakeFetch([
      { match: 'dog.ceo/api', respond: async () => jsonResponse(DOGCEO_PAYLOAD) },
    ]);
    await dogCeoAdapter.fetchItems(7, { fetch, budget });
    expect(fetch.calls[0]).toBe('https://dog.ceo/api/breeds/image/random/7');
  });
});

describe('breedFromUrl', () => {
  it('想定外のパスでは null を返す', () => {
    expect(breedFromUrl('https://images.dog.ceo/other/x.jpg')).toBeNull();
    expect(breedFromUrl('https://images.dog.ceo/breeds/HOUND-Afghan/x.jpg')).toBeNull();
    expect(breedFromUrl('https://images.dog.ceo/breeds/')).toBeNull();
  });
});
