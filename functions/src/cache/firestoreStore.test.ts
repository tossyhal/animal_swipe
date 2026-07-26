import { describe, expect, it } from 'vitest';
import { decodeEntry, encodeKey } from './firestoreStore';

describe('encodeKey', () => {
  it('document ID に使えない / を置換する', () => {
    expect(encodeKey('animals:v1:cat+dog:10')).toBe('animals:v1:cat+dog:10');
    expect(encodeKey('a/b')).toBe('a_b');
  });
});

describe('decodeEntry', () => {
  it('Timestamp 風オブジェクトを ms へ変換する', () => {
    const entry = decodeEntry({
      items: [],
      fetchedAt: { toMillis: () => 1000 },
      expiresAt: { toMillis: () => 2000 },
      purgeAt: { toMillis: () => 3000 },
    });
    expect(entry).toEqual({ items: [], fetchedAt: 1000, expiresAt: 2000, purgeAt: 3000 });
  });

  it('数値でも受け付ける', () => {
    expect(decodeEntry({ items: [], fetchedAt: 1, expiresAt: 2, purgeAt: 3 })).toEqual({
      items: [],
      fetchedAt: 1,
      expiresAt: 2,
      purgeAt: 3,
    });
  });

  it('purgeAt が無い旧データは expiresAt を流用する（後方互換）', () => {
    expect(decodeEntry({ items: [], fetchedAt: 1, expiresAt: 2 })).toEqual({
      items: [],
      fetchedAt: 1,
      expiresAt: 2,
      purgeAt: 2,
    });
  });

  it.each([
    null,
    undefined,
    'string',
    {},
    { items: [], fetchedAt: 1 },
    { items: 'not-array', fetchedAt: 1, expiresAt: 2 },
    { items: [], fetchedAt: 'x', expiresAt: 2 },
  ])('壊れたデータ %s は null（= cache miss）', (data) => {
    expect(decodeEntry(data)).toBeNull();
  });
});
