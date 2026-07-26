import type { HttpBudget, HttpClientDeps } from '../core/httpClient';
import type { AnimalItem, AnimalType, SourceId } from '../core/types';

/**
 * 外部 API 1 つを共通形式へ変換する adapter の契約。
 *
 * adapter は「取得」と「正規化」だけを担当し、
 * 部分失敗の集約・キャッシュ・HTTP 表現には関与しない。
 */
export interface AnimalAdapter {
  readonly source: SourceId;
  readonly type: AnimalType;
  /**
   * 最大 `count` 件を取得する。
   * 失敗時は必ず ProviderError を投げる（生の例外を漏らさない）。
   * 許可されない画像 URL の項目は黙って除外するため、戻り値が count 未満になり得る。
   */
  fetchItems(count: number, deps: AdapterDeps): Promise<AnimalItem[]>;
}

export interface AdapterDeps extends HttpClientDeps {
  budget?: HttpBudget;
  /** ランダム性の注入（テストで決定的にする）。 */
  random?: () => number;
}
