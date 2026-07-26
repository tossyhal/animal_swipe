import { describe, expect, it } from 'vitest';
import { animalsCacheKey, dailyCacheKey, jstDateString, nextJstMidnightMs } from './store';

describe('animalsCacheKey', () => {
  it('正規化済みクエリから決定的なキーを作る', () => {
    expect(animalsCacheKey({ types: ['cat', 'dog'], limit: 10 })).toBe('animals:v1:cat+dog:10');
    expect(animalsCacheKey({ types: ['cat'], limit: 5 })).toBe('animals:v1:cat:5');
  });

  it('条件が違えばキーも違う', () => {
    const a = animalsCacheKey({ types: ['cat'], limit: 10 });
    const b = animalsCacheKey({ types: ['dog'], limit: 10 });
    const c = animalsCacheKey({ types: ['cat'], limit: 11 });
    expect(new Set([a, b, c]).size).toBe(3);
  });
});

describe('JST 日付', () => {
  it('UTC 15:00 は翌日の JST 日付になる', () => {
    // 2024-01-01T15:00:00Z = 2024-01-02T00:00:00+09:00
    expect(jstDateString(Date.parse('2024-01-01T15:00:00Z'))).toBe('2024-01-02');
    expect(jstDateString(Date.parse('2024-01-01T14:59:59Z'))).toBe('2024-01-01');
  });

  it('次の JST 深夜 0 時を返す', () => {
    const now = Date.parse('2024-01-01T10:00:00Z'); // JST 19:00
    expect(new Date(nextJstMidnightMs(now)).toISOString()).toBe('2024-01-01T15:00:00.000Z');
  });

  it('ちょうど JST 深夜 0 時なら次の日の深夜 0 時', () => {
    const now = Date.parse('2024-01-01T15:00:00Z');
    expect(new Date(nextJstMidnightMs(now)).toISOString()).toBe('2024-01-02T15:00:00.000Z');
  });

  it('dailyCacheKey は日付ごとに変わる', () => {
    expect(dailyCacheKey('2024-01-01')).not.toBe(dailyCacheKey('2024-01-02'));
  });
});
