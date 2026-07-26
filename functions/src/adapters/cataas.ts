import { getJson, type HttpBudget } from '../core/httpClient';
import { ProviderError } from '../core/errors';
import { sanitizeImageUrl } from '../core/imageUrl';
import type { AnimalItem } from '../core/types';
import type { AdapterDeps, AnimalAdapter } from './adapter';

const API_BASE = 'https://cataas.com/api/cats';
const IMAGE_BASE = 'https://cataas.com/cat';
/** 画像配信側へ渡す幅。転送量を抑えるため固定値にする。 */
const IMAGE_WIDTH = 800;
/** ランダム性を出すための skip の最大値（既存 Flutter 実装と同じ 0..999）。 */
const MAX_SKIP = 1000;

/**
 * Cataas (https://cataas.com) adapter。
 *
 * 想定レスポンス: `[{ "id": "...", "tags": ["..."] }, ...]` の配列。
 * ただし実 API へ接続して検証していないため、`id` / `_id` の双方を許容し、
 * ID を取り出せない要素は捨てる（フェイルオープンしない）。
 */
export const cataasAdapter: AnimalAdapter = {
  source: 'cataas',
  type: 'cat',

  async fetchItems(count: number, deps: AdapterDeps): Promise<AnimalItem[]> {
    const random = deps.random ?? Math.random;
    const skip = Math.floor(random() * MAX_SKIP);
    const url = `${API_BASE}?limit=${count}&skip=${skip}`;

    const payload = await getJson(url, deps, deps.budget as HttpBudget | undefined);
    return normalizeCataas(payload);
  },
};

export function normalizeCataas(payload: unknown): AnimalItem[] {
  if (!Array.isArray(payload)) {
    throw new ProviderError('invalid_response', '配列以外のレスポンスを受け取りました。');
  }

  const items: AnimalItem[] = [];
  for (const entry of payload) {
    if (typeof entry !== 'object' || entry === null) continue;

    const record = entry as Record<string, unknown>;
    const id = pickId(record);
    if (id === null) continue;

    // 画像 URL は外部レスポンスの任意フィールドではなく、
    // 検証済みの ID から自前で組み立てる（オープンプロキシ化を避ける）。
    const imageUrl = sanitizeImageUrl(
      `${IMAGE_BASE}/${encodeURIComponent(id)}?width=${IMAGE_WIDTH}`,
    );
    if (imageUrl === null) continue;

    items.push({
      id: `cataas:${id}`,
      type: 'cat',
      imageUrl,
      // Cataas は品種情報を返さない契約として扱う。
      breed: null,
      source: 'cataas',
    });
  }

  return items;
}

/** `id` / `_id` のいずれかから、空でない文字列 ID を取り出す。 */
function pickId(record: Record<string, unknown>): string | null {
  for (const key of ['id', '_id'] as const) {
    const value = record[key];
    if (typeof value === 'string' && value.trim() !== '') {
      return value.trim();
    }
  }
  return null;
}
