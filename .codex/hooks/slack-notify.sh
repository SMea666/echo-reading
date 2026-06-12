#!/usr/bin/env bash
# 通用 Slack 通知发送器
# 用法：bash slack-notify.sh "消息内容" [频道]
#
# 从 .slack/config 读取 token，通过 Slack API 发送消息。
# 任何错误静默退出，不阻断主线。

set -euo pipefail

MESSAGE="${1:-}"
CHANNEL="${2:-}"

[ -n "$MESSAGE" ] || exit 0

# 定位项目根目录（从调用方传入或自动检测）
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$REPO_ROOT" ] || exit 0

CONFIG="$REPO_ROOT/.slack/config"
[ -f "$CONFIG" ] || exit 0

# 读取配置
# shellcheck disable=SC1090
source "$CONFIG"

[ -n "${SLACK_TOKEN:-}" ] || exit 0
[ -n "${CHANNEL:-}" ] || CHANNEL="${SLACK_CHANNEL:-#echo-reading}"

# 发送消息（用 chat.postMessage API）
curl -s -X POST "https://slack.com/api/chat.postMessage" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg channel "$CHANNEL" \
    --arg text "$MESSAGE" \
    '{channel: $channel, text: $text}')" \
  > /dev/null 2>&1 || true

exit 0
