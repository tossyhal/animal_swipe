import { getJson, type HttpBudget } from '../core/httpClient';
import { ProviderError } from '../core/errors';
import { sanitizeImageUrl } from '../core/imageUrl';
import type { AnimalItem } from '../core/types';
import type { AdapterDeps, AnimalAdapter } from './adapter';

const API_BASE = 'https://dog.ceo/api/breeds/image/random';

/**
 * Dog CEO (https://dog.ceo/dog-api/) adapter。
 *
 * 想定レスポンス: `{ "message": ["https://images.dog.ceo/breeds/.../x.jpg", ...], "status": "success" }`
 * message の各要素は外部が返す任意の URL なので、必ず allowlist 検証を通してから採用する。
 */
export const dogCeoAdapter: AnimalAdapter = {
  source: 'dogceo',
  type: 'dog',

  async fetchItems(count: number, deps: AdapterDeps): Promise<AnimalItem[]> {
    const url = `${API_BASE}/${count}`;
    const payload = await getJson(url, deps, deps.budget as HttpBudget | undefined);
    return normalizeDogCeo(payload);
  },
};

export function normalizeDogCeo(payload: unknown): AnimalItem[] {
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    throw new ProviderError('invalid_response', 'オブジェクト以外のレスポンスを受け取りました。');
  }

  const record = payload as Record<string, unknown>;
  if (record.status !== 'success') {
    throw new ProviderError('invalid_response', 'status が success ではありません。');
  }

  const message = record.message;
  if (!Array.isArray(message)) {
    throw new ProviderError('invalid_response', 'message が配列ではありません。');
  }

  const items: AnimalItem[] = [];
  const seen = new Set<string>();

  for (const raw of message) {
    // ここが本 adapter 唯一の外部由来 URL。HTTPS + 許可ホスト完全一致を通らなければ捨てる。
    const imageUrl = sanitizeImageUrl(raw);
    if (imageUrl === null) continue;

    const id = `dogceo:${stableIdFromUrl(imageUrl)}`;
    if (seen.has(id)) continue;
    seen.add(id);

    items.push({
      id,
      type: 'dog',
      imageUrl,
      breed: breedFromUrl(imageUrl),
      source: 'dogceo',
    });
  }

  return items;
}

/**
 * Dog CEO は ID を返さないため、画像 URL のパスを安定 ID として使う。
 * 同一画像 URL は常に同一 ID になり、重複排除に利用できる。
 */
export function stableIdFromUrl(imageUrl: string): string {
  return new URL(imageUrl).pathname.replace(/^\/+/, '');
}

/**
 * `/breeds/hound-afghan/xxx.jpg` のようなパスから品種名を復元する。
 * 想定外のパス形状では null を返す（推測しない）。
 */
export function breedFromUrl(imageUrl: string): string | null {
  const segments = new URL(imageUrl).pathname.split('/').filter((s) => s !== '');
  if (segments.length < 2 || segments[0] !== 'breeds') return null;

  const slug = segments[1];
  if (!/^[a-z]+(-[a-z]+)?$/.test(slug)) return null;

  // "hound-afghan" -> "Afghan Hound"、"beagle" -> "Beagle"
  const parts = slug.split('-');
  const ordered = parts.length === 2 ? [parts[1], parts[0]] : parts;
  return ordered.map((p) => p.charAt(0).toUpperCase() + p.slice(1)).join(' ');
}
