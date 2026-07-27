# Animal Swipe
![workflow](https://github.com/tossyhal/animal_swipe/actions/workflows/firebase-hosting-merge.yml/badge.svg)

<img src="https://github.com/user-attachments/assets/92290127-2a09-4680-8911-26d71861ee33" width="35%">          　
<img src="https://github.com/user-attachments/assets/696eb54e-4db4-4a21-bd86-979c56e92877" width="35%">

<br />

> [!NOTE]
> モバイル端末のブラウザでの利用を推奨します。  
> デプロイコストの観点から、Flutterを用いてPWAという形で作成しました。

## URL
https://animal-swipe-596cc.web.app/

<img src="https://github.com/user-attachments/assets/fd683122-cad1-4a9c-8b23-5f387edabf95" width="30%">

<br /><br />

## Overview

**Animal Swipe**は、スワイプすることで動物の画像を見ることができるアプリです。  
動物の画像で癒やされましょう！  

<br />

## Features

- **動物タイプの選択:**  
  起動画面で「ねこ」と「いぬ」から表示したい動物を選択できます。

- **画像取得とスワイプ:**  
  - 外部API（cataas API と Dog API）を利用して、リアルタイムで動物画像を取得。  
  - カード形式で画像を表示し、左右へのスワイプで次の画像へ移行する直感的なUIを実現。

- **プリロード機能:**  
  画像の事前読み込みにより、スワイプ時の表示がスムーズかつ迅速です。

- **状態管理:**  
  Riverpodを使用し、動物タイプの選択状態や画像リストの管理を行っています。

<br />

## Technology Stack
<img width=400 src="https://skillicons.dev/icons?i=dart,flutter,firebase">

<br />

## API
- **Cataas(Cat as a service)**：https://cataas.com/
- **Dog API**：https://dog.ceo/dog-api/

<br />

## Future

今後のアップデートや改善として、以下を検討しています。
- **プリロード機能の改善**  
  現時点では、画像自体をプリロードするのではなく、画像のURLをプリロードする設計になってしまっており、スワイプ時の画像表示に時間がかかっている。修正予定。

- **お気に入り機能**  
  ユーザーがお気に入りの画像を保存し、後で閲覧できるようにする機能を実装予定です。

- **動物種類の拡充**  
  現在は「ねこ」と「いぬ」の画像にのみ対応していますが、鳥やうさぎなど、他の動物の追加を検討中です。

- **画像アップロード機能**  
  自分のペットの画像をアップロードし、他のユーザーに共有できる機能を検討中です。

- **UI/UXの改善**  
  より洗練されたアニメーションやユーザビリティ向上を目指し、UIの最適化を進める予定です。

<br />


## エラー監視（Sentry）

未処理例外とクラッシュを Sentry へ送信できます。**DSN が未設定なら Sentry は初期化されず、ログ出力のみ**になるため、開発中やフォークでの動作に外部サービスの設定は不要です。

### 有効にする手順

1. [Sentry](https://sentry.io/) で Flutter プロジェクトを作成し、DSN を取得する
2. ビルド時に `--dart-define` で渡す

```bash
flutter build web --release --dart-define=SENTRY_DSN=https://xxxx@oNNN.ingest.sentry.io/NNN
```

3. GitHub のリポジトリ設定で `SENTRY_DSN` を Actions secret として登録する

デプロイのワークフローは既に `--dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }}` を渡すようになっています。**secret が未登録なら空文字が渡り、Sentry は初期化されません**（ビルドは失敗しません）。つまり secret を登録した時点で有効になります。

**PR プレビューには `SENTRY_DSN` を渡していません。** PR の試行錯誤で出たエラーが本番プロジェクトに混ざるとアラートが汚れ、無料枠も消費するためです。プレビューでも監視したい場合は、**別の Sentry プロジェクト**を作って `SENTRY_DSN_PREVIEW` を登録してください。未登録ならプレビューは監視なしでビルドされます。

### DSN の扱いについて

Sentry の DSN は**元からクライアントに埋め込む前提の公開値**です（イベントの投稿にしか使えず、データの読み出しはできません）。したがって `--dart-define` で渡して問題ありません。

ただし **Flutter Web の `--dart-define` はビルド成果物から読み取れるため、秘匿手段ではありません**。同じ方法で API キーなど本当に秘密にすべき値を渡さないでください。その用途にはサーバー側のプロキシ（#45）を使います。

### 有効になる条件

| 条件 | 送信 |
|---|---|
| リリースビルド + DSN 設定あり | ✅ |
| リリースビルド + DSN なし | ❌（ログのみ） |
| デバッグビルド | ❌（ノイズと無料枠の消費を避けるため） |

### ログレベル

リリースビルドでは `Level.warning` 以上のみ出力します。Web ではブラウザのコンソールにそのまま出るため、デバッグログを残したままにすると利用者に内部情報が見えてしまうためです。
