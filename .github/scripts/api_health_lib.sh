#!/usr/bin/env bash
# .github/workflows/api-health.yml の各ステップから source される共有ヘルパー。
#
# なぜ関数として1箇所にまとめるのか:
#   以前は「HTTPヘッダーから値を取り出す」処理を Cataas / Dog CEO の各ステップに
#   コピーしていた。その結果、ヘッダー名の大文字小文字ゆれ（HTTPヘッダー名は
#   RFC 9110 上大文字小文字を区別しない）を grep 側は -i で吸収していたのに
#   sed 側は固定の大文字小文字パターンでしか名前部分を剥がせず、
#   `ACCESS-CONTROL-ALLOW-ORIGIN:` のような大文字表記や大文字小文字混在の
#   ヘッダーが来ると値の抽出に失敗し、実際はCORSが正しく設定されているのに
#   「CORSヘッダーなし」という誤検知（false RED）でアラート疲れを招く欠陥が
#   あった。コピーが複数箇所にあると片方だけ直して片方を直し忘れる事故が
#   起きるため、関数を1つにまとめてsourceする形にしている。

# 指定したヘッダーの値を取り出す。
#
# - ヘッダー名の大文字小文字を区別しない（grep -i で行を拾い、名前部分は
#   コロンまでを丸ごと剥がすことで大文字小文字に依存しないようにする）
# - `curl -D` が出力するCRLF改行の `\r` を除去する
# - 値の前後の空白（コロン直後のスペース、行末の余分な空白）を除去する
# - 同名ヘッダーが複数行来た場合は最後の1行を採用する
#   （中継プロキシ等が重複させても、クライアントに実際反映されるのは
#   通常最後の値であるため）
extract_header_value() {
  local headers_file="$1"
  local header_name="$2"

  grep -i "^${header_name}:" "$headers_file" \
    | tail -n 1 \
    | sed -E 's/^[^:]*:[[:space:]]*//' \
    | tr -d '\r' \
    | sed -E 's/[[:space:]]+$//'
}

# レスポンスヘッダーが Content-Type: *json* かどうかを確認する
check_content_type_json() {
  local headers_file="$1"
  local content_type
  content_type=$(extract_header_value "$headers_file" 'content-type')
  echo "$content_type" | grep -qi 'json'
}

# レスポンスヘッダーが PWA_ORIGIN からのアクセスを許可しているかを確認する
#
# ヘッダーが存在するだけでなく、値が `*`（全許可）またはリクエストで送った
# Origin と一致することまで見る。存在確認だけでは「別オリジン向けの値が
# たまたま入っている」ケースを見逃すため。
#
# 加えて、同名ヘッダーがちょうど1個だけ返ってきていることも必須にする。
# `extract_header_value` は「複数あれば最後の1個を採用する」設計だが、
# ブラウザの CORS チェックは重複した Access-Control-Allow-Origin を
# 「どちらか」ではなく既定でエラー扱いにする（fetch/XHR は重複ヘッダーを
# 単純結合してから検証するため、単一の期待値と一致しなくなる）。
# つまり「最後の値だけ見れば正しい値に見える」構成こそが、実際には
# ブラウザ側で失敗する典型例であり、それを緑判定してしまうと本末転倒になる。
check_cors_allows_origin() {
  local headers_file="$1"
  local expected_origin="$2"

  local header_count
  header_count=$(grep -ci '^access-control-allow-origin:' "$headers_file")
  if [ "$header_count" -ne 1 ]; then
    echo "  [CORS] Access-Control-Allow-Origin ヘッダーが ${header_count} 個検出された" \
      "（1個以外はヘッダー重複によりブラウザがCORS失敗として扱うため不合格）" >&2
    return 1
  fi

  local cors_value
  cors_value=$(extract_header_value "$headers_file" 'access-control-allow-origin')

  [ -n "$cors_value" ] && { [ "$cors_value" = "*" ] || [ "$cors_value" = "$expected_origin" ]; }
}
