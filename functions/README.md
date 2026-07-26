# animal_swipe BFF (Firebase Functions)

外部動物画像 API（Cataas / Dog CEO）を集約し、共通形式へ正規化して返す BFF。

- 設計判断: [`docs/adr/0001-bff-introduction.md`](../docs/adr/0001-bff-introduction.md)
- API 契約: [`openapi/animal-swipe-bff.v1.yaml`](../openapi/animal-swipe-bff.v1.yaml)
- 関連 Issue: #45

## エンドポイント

| メソッド | パス | 説明 |
| --- | --- | --- |
| GET | `/api/v1/animals?types=cat,dog&limit=10` | 動物画像を最大 `limit` 件取得する |
| GET | `/api/v1/animals/daily` | 今日の1枚（JST 日付ごとに固定） |

Firebase Hosting の rewrite（`/api/**` → Functions `api`）経由で、Web アプリと同一オリジンで配信される。

## ディレクトリ構成

```text
functions/src/
  core/validate.ts        allowlist 入力検証（types / limit）
  core/imageUrl.ts        HTTPS + 許可ホスト完全一致の検証
  core/httpClient.ts      タイムアウト・再試行・バックオフ付き GET
  core/aggregate.ts       並行呼び出しと部分失敗の集約
  core/daily.ts           今日の1枚
  core/errors.ts          ApiError / ProviderError
  core/types.ts           共通型・allowlist 定数
  adapters/cataas.ts      Cataas adapter
  adapters/dogceo.ts      Dog CEO adapter
  cache/store.ts          CacheStore インターフェース・TTL 定数・キー生成
  cache/firestoreStore.ts CacheStore の Firestore 実装
  http/cors.ts            CORS 許可 origin
  http/handler.ts         ルーティング・ステータス／ヘッダー決定
  index.ts                firebase-functions への配線
  test/fakes.ts           テスト用 fake（fetch / CacheStore）
```

`firebase-admin` / `firebase-functions` に依存するのは `cache/firestoreStore.ts` と `index.ts` だけ。
ロジックは `fetch` / `CacheStore` / `now` / `random` / `sleep` を注入して受け取るため、
テストは実ネットワークにも Firestore にも触れない。

## ローカル実行

前提: Node.js 22、Firebase CLI（`npm i -g firebase-tools`）。
コマンドはすべて `functions/` ディレクトリで実行する（リポジトリルートに `package.json` は無い）。

```bash
cd functions
npm install
npm run build          # tsc -> lib/
npm test               # vitest（外部ネットワーク・Firestore に接続しない）
npm run typecheck      # 型チェックのみ
```

エミュレータ（Functions + Firestore）を起動する。

```bash
cd functions
npm run serve
# 別ターミナルから（Hosting rewrite 込みで確認する場合はリポジトリルートで
#   firebase emulators:start --only functions,firestore,hosting
# を使う）

curl 'http://127.0.0.1:5001/animal-swipe-596cc/asia-northeast1/api/v1/animals?types=cat&limit=3'
curl 'http://127.0.0.1:5001/animal-swipe-596cc/asia-northeast1/api/v1/animals/daily'
```

> エミュレータからの動作確認は**外部 API へ実際に接続する**。実 API を叩きたくない場合は
> `npm test` のみで検証すること（テストは外部へ出ない）。

CORS の挙動を確かめる場合は origin を明示する。

```bash
curl -i -H 'Origin: https://animal-swipe-596cc.web.app' \
  'http://127.0.0.1:5001/animal-swipe-596cc/asia-northeast1/api/v1/animals?limit=2'
```

## デプロイ

**順序が重要。Functions を先に、Hosting を後に。**
`/api/**` の rewrite は `api` 関数を参照するため、関数が未デプロイの状態で Hosting だけを
公開すると、バックエンド検証に失敗するか `/api/**` がバックエンド不在のまま公開される。

```bash
firebase use animal-swipe-596cc
firebase deploy --only functions          # 1. predeploy で npm run build が走る
firebase deploy --only hosting            # 2. /api/** の rewrite を反映
```

デプロイ前に必ず `npm test` を通すこと。

> **⚠️ CI 未対応（要対応）**
> 現在の main ブランチの GitHub Actions ワークフローは `FirebaseExtended/action-hosting-deploy`
> のみを実行しており、**Functions をデプロイしない**。この状態で本変更を main へマージすると、
> `api` 関数を手動デプロイしていない限り、Hosting デプロイが失敗するか `/api/**` が
> バックエンド不在で公開される。次のいずれかを先に済ませること。
>
> 1. ワークフローに Hosting デプロイの**前段**として Functions デプロイを追加する
>    （`functions/` で `npm ci && npm run build` → `firebase deploy --only functions`）。
> 2. それまでの暫定として、`api` 関数を手動で先にデプロイしておく。
>
> ワークフロー（`.github/`）の変更は本コミットの担当範囲外のため未対応。

### Firestore TTL ポリシー（デプロイ後に 1 回だけ実施）

キャッシュ document の自動削除は Firestore の TTL ポリシーで行う。
これを設定しないと期限切れ document が蓄積し続け、ストレージ課金が増え続ける。

```bash
gcloud firestore fields ttls update purgeAt \
  --collection-group=api_cache \
  --enable-ttl \
  --project=animal-swipe-596cc
```

- コレクション: `api_cache`
- TTL フィールド: **`purgeAt`**（`Timestamp` 型。他の型では TTL が機能しない）
- **`expiresAt` を TTL 対象にしてはならない。** `expiresAt` は「鮮度」の境界であり、
  そこから全滅時 stale フォールバックの利用期間が始まる。`expiresAt` を TTL 対象にすると
  stale として使いたい瞬間に document が削除対象になり、フォールバックが成立しない。
  そのため「鮮度」(`expiresAt`) と「物理削除」(`purgeAt`) を別フィールドで管理している。
- 削除は「期限後 24 時間以内」のベストエフォート。したがってアプリ側は
  必ず `expiresAt` / `fetchedAt` を読んで自前で失効判定している
  （TTL は掃除であって整合性の保証ではない）。

## キャッシュ設計

| 用途 | キー | 鮮度 `expiresAt` | 物理削除 `purgeAt` | 無効化 |
| --- | --- | --- | --- | --- |
| 一覧 | `animals:v1:{types}:{limit}` | 取得 + 5 分 | 取得 + 60 分 | `expiresAt` 経過で fresh ではなくなり、以降 60 分は stale 候補。`purgeAt` で TTL 削除 |
| 今日の1枚 | `daily:v1:{JST YYYY-MM-DD}` | 次の JST 深夜 0 時 | 次の JST 深夜 0 時 + 24 時間 | 日付が変わればキーが変わる。旧 document は `purgeAt` で TTL 削除 |

- キーは**検証・正規化後**のクエリからのみ生成する（`types` はソート済み、`limit` は範囲内）。
  生のクエリ文字列を混ぜないことでキー汚染を防ぐ。
- 部分失敗（`partial: true`）の結果はキャッシュへ書かない。縮退結果を 5 分間焼き付けないため。
- 全プロバイダー失敗時は、取得から 60 分以内の stale キャッシュに限り返す
  （`partial: true` + `STALE_CACHE_SERVED`）。それも無ければ 502。
- 「今日の1枚」の初回保存は create-if-absent（Firestore ではトランザクション）で行う。
  同時リクエストがそれぞれ別の画像を選んでも、確定するのは最初の 1 件だけで、
  競合に負けた側もその 1 件を返す。
- 共有キャッシュ（CDN）の `s-maxage` は、返した内容の**取得時刻から数えた残り秒数**にする。
  毎回 TTL 満了値を返すと、期限間際のキャッシュヒットのたびに CDN 側の寿命がリセットされ、
  実効的な鮮度が TTL の 2 倍近くまで伸びてしまう。同じ理由で「今日の1枚」も
  返した `date` に対応する期限から算出する。
- スキーマを変更したときはキーの `v1` を上げる（古いエントリを読まないため）。
- 手動で全削除したい場合はコレクションごと消してよい。キャッシュは常に再生成できる。

```bash
firebase firestore:delete --recursive api_cache --project animal-swipe-596cc
```

## タイムアウト・再試行

| 設定 | 値 |
| --- | --- |
| 1 試行あたりのタイムアウト | 3 秒（`AbortSignal.timeout`） |
| 再試行 | 追加 1 回（合計 2 試行） |
| バックオフ | 初回 200ms、2 倍ずつ、上限 1000ms、フルジッター |
| 再試行する条件 | ネットワークエラー / タイムアウト / 5xx / 429 |
| 再試行しない条件 | 429 以外の 4xx、JSON パース失敗 |
| Functions のタイムアウト | 20 秒 |

対象は冪等な GET のみ。プロバイダーは `Promise.allSettled` で並行実行するため、
最悪ケースの所要時間はプロバイダー数に比例しない。

## セキュリティ

### 秘密情報の扱い

**Flutter Web の `--dart-define` は秘密の保管場所ではない。**
`--dart-define` の値はビルド成果物（`build/web` の JS）に平文で埋め込まれ、
ブラウザの開発者ツールから誰でも読める。API キーを渡す用途に使ってはならない。

**現時点で本 BFF が扱う秘密情報は無い。** Cataas と Dog CEO はいずれも認証不要のため、
Secret Manager に登録すべきものは存在しない。以下は API キーを要する取得元
（#34 の The Cat API 等）を追加する際の手順である。

```bash
# 1. シークレットを作成（値は対話的に入力。シェル履歴やリポジトリに残さない）
firebase functions:secrets:set CAT_API_KEY --project animal-swipe-596cc

# 2. コード側で宣言し、対象関数へバインドする
#    import { defineSecret } from 'firebase-functions/params';
#    const catApiKey = defineSecret('CAT_API_KEY');
#    export const api = onRequest({ secrets: [catApiKey] }, handler);
#    使用時のみ catApiKey.value() を呼ぶ

# 3. デプロイ
firebase deploy --only functions

# 4. 参照・ローテーション・削除
firebase functions:secrets:access CAT_API_KEY
firebase functions:secrets:set CAT_API_KEY      # 新バージョンを作成し再デプロイ
firebase functions:secrets:prune                # 未使用バージョンを整理
```

守るべきこと。

- シークレットの値をログへ出さない。エラーメッセージに外部レスポンス本文や URL を載せない
  （本実装ではメッセージを自前の固定文言に正規化している）。
- `.env` をコミットしない（`.gitignore` 済み）。
- クライアントへ返すフィールドは OpenAPI に列挙したものだけに限定する。

### 入力検証とオープンプロキシ対策

- `types` は allowlist（`cat` / `dog`）の**完全一致**のみ。未知の値が 1 つでも混ざれば 400 で、
  **外部 API へのリクエストは一切行わない**。
- `limit` は 10 進整数かつ 1..30。範囲外は 400（黙って丸めない）。
- **URL を受け取るクエリパラメータは存在しない。追加してはならない。** 取得先は `types` から一意に決まる。
- 外部画像 URL は `https:` かつホスト名が `cataas.com` / `images.dog.ceo` に**完全一致**する場合のみ通す。
  `endsWith` / `includes` による判定は `evilcataas.com` や `images.dog.ceo.evil.example` を
  通してしまうため使っていない。ユーザー情報付き URL と明示ポートも拒否する。
- Cataas の画像 URL は外部レスポンスのフィールドをそのまま使わず、検証済み ID から自前で組み立てる。

### CORS

許可 origin は `https://animal-swipe-596cc.web.app` のみ。完全一致した場合だけその origin を
エコーし、`*` は返さない。常に `Vary: Origin` を付ける。

- `*.firebaseapp.com` は仕様どおり意図的に含めていない。必要になったら `src/http/cors.ts` の
  `ALLOWED_ORIGINS` に明示的に追加する。
- Hosting rewrite 経由の呼び出しは同一オリジンなので、そもそも CORS の対象にならない。
- **CORS は認証の代替ではない。** ブラウザ外からの呼び出しは CORS では防げない。
  レート制限・App Check・認証は未導入であり、必要になった段階で追加する（#45 の後続）。

### Firestore へのアクセス

キャッシュコレクション `api_cache` は Admin SDK 経由でのみ読み書きする。
クライアントから直接読ませる必要は無いため、セキュリティルールで拒否しておくことが望ましい
（本リポジトリにはまだ `firestore.rules` を置いていない）。

## コスト管理

### 実装済みのガード

`src/index.ts` の `setGlobalOptions` で以下を設定している。

| 設定 | 値 | 目的 |
| --- | --- | --- |
| `maxInstances` | 5 | 暴走・攻撃時の水平スケールを抑え、想定外の課金を防ぐ |
| `concurrency` | 40 | 1 インスタンスで複数リクエストを捌き、インスタンス数を抑える |
| `memory` | 256MiB | 本ワークロードに必要十分な最小構成 |
| `timeoutSeconds` | 20 | 最悪ケース（3s + backoff + 3s）を上回りつつ短く保つ |
| `region` | asia-northeast1 | 主な利用者と同リージョン。レイテンシと外向き通信費の抑制 |

加えて 5 分 TTL キャッシュにより、外部 API 呼び出しと Firestore read を削減している。

### 予算アラートの設定手順（**未設定。以下は手順のみ**）

Google Cloud の予算アラートは Firebase プロジェクトに紐づく請求先アカウントに設定する。

コンソールから行う場合:

1. [Google Cloud Console > お支払い > 予算とアラート](https://console.cloud.google.com/billing/budgets) を開く
2. 請求先アカウントを選び「予算を作成」
3. 範囲でプロジェクト `animal-swipe-596cc` を指定
4. 金額（例: 月 1,000 円）を設定
5. しきい値ルールを 50% / 90% / 100% で追加し、メール通知先を設定
6. 必要なら Pub/Sub トピックへ通知し、上限超過時に関数を停止する自動化を組む

CLI で行う場合:

```bash
gcloud billing budgets create \
  --billing-account=<BILLING_ACCOUNT_ID> \
  --display-name="animal-swipe monthly" \
  --budget-amount=1000JPY \
  --filter-projects="projects/animal-swipe-596cc" \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

> 予算アラートは**通知であって課金の停止ではない**。確実に止めるには
> Pub/Sub 通知を受けて Cloud Billing API でプロジェクトの請求を無効化する関数が必要になる。
> 現状はまず `maxInstances: 5` が事実上の上限として機能する。

### 監視（**未設定。以下は手順のみ**）

- Cloud Monitoring で以下のアラートポリシーを作る。
  - `cloudfunctions.googleapis.com/function/execution_count` の急増
  - `function/execution_times` の p95 悪化
  - 5xx 応答率の上昇
- ログベース指標で `UPSTREAM_UNAVAILABLE` の発生率を追い、外部 API の劣化を検知する。
- プロバイダーごとの成功率・レイテンシの継続的な監視は #44 の範囲。

```bash
firebase functions:log --only api --project animal-swipe-596cc
```

## テスト

```bash
cd functions
npm test
```

カバーしている観点。

- 入力検証: allowlist 外の `types`、範囲外・非整数の `limit`
- **任意 URL を取得できないこと**: `types` に URL を渡しても 400 になり、
  fake fetch が**一度も呼ばれない**こと。さらにプロバイダーが敵対的な URL
  （`http://`、別ホスト、サブドメイン偽装、サフィックス偽装）を返しても `items` に混入しないこと
- タイムアウト: `AbortError` による失敗と再試行回数の上限
- 部分失敗: 片方のみ失敗したときに `items` を返しつつ `partial: true` + `warnings`
- 全体失敗: stale キャッシュの有無による 200 / 502 の分岐
- キャッシュ: TTL の書き込み、hit 時に外部 API を呼ばないこと、ストア障害時に落ちないこと
- CORS: 許可 origin のエコー、許可外 origin でヘッダーを付けないこと、`*` を返さないこと
- 今日の1枚: JST 日付の境界計算、2 回目がキャッシュから返ること、
  同時リクエストが全員同じ 1 枚を受け取ること、処理中に JST 深夜 0 時を跨いだ場合に
  前日分を丸一日共有キャッシュへ載せないこと

## 既知の前提・未確認事項

- **Cataas のレスポンス形状は実 API へ接続して検証していない。**
  `[{ "id": "...", ... }]` を想定しつつ、`id` / `_id` の双方を許容し、
  ID を取り出せない要素はスキップする実装にしてある。#44 の契約テストで確定させる。
- **Cataas / Dog CEO の利用規約・転載条件は未確認。** 本 BFF は画像本体を保存・再配布せず、
  外部配信元の URL を参照するだけだが、自前保存を検討する前に必ず確認すること。
- Flutter 側（`lib/services/api_service.dart`）はまだ BFF を利用していない。切り替えは別作業。
