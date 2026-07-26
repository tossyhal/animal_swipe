import { describe, expect, it } from 'vitest';
import { ApiError } from './errors';
import { parseAnimalsQuery, parseLimit, parseTypes } from './validate';

describe('parseTypes (allowlist)', () => {
  it('未指定なら許可種すべてを返す', () => {
    expect(parseTypes(undefined)).toEqual(['cat', 'dog']);
    expect(parseTypes('')).toEqual(['cat', 'dog']);
  });

  it('許可値のみを受け付け、重複排除とソートを行う', () => {
    expect(parseTypes('dog,cat,dog')).toEqual(['cat', 'dog']);
    expect(parseTypes(' cat , dog ')).toEqual(['cat', 'dog']);
  });

  it.each([
    'bird',
    'CAT',
    'cat ,bird',
    'cats',
    '',
    'https://evil.example/x.jpg',
    'http://169.254.169.254/latest/meta-data/',
    'file:///etc/passwd',
    '../../etc/passwd',
    'cat,https://evil.example',
  ])('未知の値 %s は 400 で拒否する', (value) => {
    // 空文字は「全許可」パスに入るため、カンマ付きのケースだけを検証対象にする
    if (value === '') return;
    expect(() => parseTypes(value)).toThrowError(ApiError);
    try {
      parseTypes(value);
    } catch (err) {
      const apiErr = err as ApiError;
      expect(apiErr.status).toBe(400);
      expect(apiErr.code).toBe('INVALID_ANIMAL_TYPE');
      expect(apiErr.field).toBe('types');
    }
  });

  it('空要素を含む types を拒否する', () => {
    expect(() => parseTypes('cat,,dog')).toThrowError(ApiError);
  });
});

describe('parseLimit', () => {
  it('未指定なら既定値 10', () => {
    expect(parseLimit(undefined)).toBe(10);
    expect(parseLimit('')).toBe(10);
  });

  it('1..30 を受け付ける', () => {
    expect(parseLimit('1')).toBe(1);
    expect(parseLimit('30')).toBe(30);
  });

  it.each(['0', '31', '1000', '-1', '1.5', 'abc', '0x10', '1e3', ' 1e3 ', 'Infinity', 'NaN'])(
    '不正な limit %s は 400 で拒否する',
    (value) => {
      try {
        parseLimit(value);
        throw new Error(`should have thrown for ${value}`);
      } catch (err) {
        expect(err).toBeInstanceOf(ApiError);
        expect((err as ApiError).status).toBe(400);
        expect((err as ApiError).code).toBe('INVALID_LIMIT');
      }
    },
  );
});

describe('parseAnimalsQuery', () => {
  it('配列で渡されたクエリは先頭要素のみを採用する', () => {
    expect(parseAnimalsQuery({ types: ['cat', 'bird'], limit: ['5', '999'] })).toEqual({
      types: ['cat'],
      limit: 5,
    });
  });

  it('パラメータ未指定なら既定値', () => {
    expect(parseAnimalsQuery({})).toEqual({ types: ['cat', 'dog'], limit: 10 });
  });

  it.each([
    // Express の extended パーサが生成し得る構造化された値（?limit[x]=1 等）
    { types: { x: 'cat' } },
    { types: [['cat']] },
    { types: [{ a: 1 }] },
    { limit: { x: '1' } },
    { limit: [['5']] },
    { limit: 5 },
    { types: true },
  ])('構造化された値 %s は 500 ではなく 400 になる', (raw) => {
    try {
      parseAnimalsQuery(raw);
      throw new Error('should have thrown');
    } catch (err) {
      expect(err).toBeInstanceOf(ApiError);
      expect((err as ApiError).status).toBe(400);
    }
  });
});
