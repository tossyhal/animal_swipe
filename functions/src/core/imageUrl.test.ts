import { describe, expect, it } from 'vitest';
import { sanitizeImageUrl } from './imageUrl';

describe('sanitizeImageUrl (任意 URL を通さない)', () => {
  it('許可ホスト + HTTPS のみ通す', () => {
    expect(sanitizeImageUrl('https://cataas.com/cat/abc?width=800')).toBe(
      'https://cataas.com/cat/abc?width=800',
    );
    expect(sanitizeImageUrl('https://images.dog.ceo/breeds/pug/x.jpg')).toBe(
      'https://images.dog.ceo/breeds/pug/x.jpg',
    );
  });

  it.each([
    // 非 HTTPS
    'http://cataas.com/cat/abc',
    'http://images.dog.ceo/breeds/pug/x.jpg',
    // 完全に別ホスト
    'https://evil.example/x.jpg',
    'http://evil.example/x.jpg',
    // endsWith 実装なら通ってしまうサフィックス偽装
    'https://evilcataas.com/x.jpg',
    'https://notimages.dog.ceo/x.jpg',
    // includes 実装なら通ってしまうサブドメイン偽装
    'https://images.dog.ceo.evil.example/x.jpg',
    'https://cataas.com.evil.example/x.jpg',
    // ユーザー情報でホストを誤認させる古典的手口
    'https://cataas.com@evil.example/x.jpg',
    'https://user:pass@cataas.com/x.jpg',
    // 明示ポート
    'https://cataas.com:8443/x.jpg',
    // 別スキーム / SSRF 定番
    'file:///etc/passwd',
    'ftp://cataas.com/x.jpg',
    'javascript:alert(1)',
    'data:image/png;base64,AAAA',
    'https://169.254.169.254/latest/meta-data/',
    'https://metadata.google.internal/computeMetadata/v1/',
    'https://localhost/x.jpg',
    'https://127.0.0.1/x.jpg',
    // 壊れた入力
    '',
    '   ',
    'not a url',
    '//cataas.com/x.jpg',
  ])('%s は拒否する', (value) => {
    expect(sanitizeImageUrl(value)).toBeNull();
  });

  it.each([null, undefined, 42, {}, [], true])('文字列以外 (%s) は拒否する', (value) => {
    expect(sanitizeImageUrl(value)).toBeNull();
  });
});
