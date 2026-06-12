#!/usr/bin/env bash
# 通用 Slack 通知发送器（Claude Code 版）
# 用法：bash slack-notify.sh "消息内容" [频道]
#
# 与 Codex 版逻辑相同，仅 repo 定位改用 CLAUDE_PROJECT_DIR。

set -euo pipefail

MESSAGE="${1:-}"
CHANNEL="${2:-}"

[ -n "$MESSAGE" ] || exit 0

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$REPO_ROOT" ] || exit 0

CONFIG="$REPO_ROOT/.slack/config"
[ -f "$CONFIG" ] || exit 0

# shellcheck disable=SC1090
source "$CONFIG"

[ -n "${SLACK_TOKEN:-}" ] || exit 0
[ -n "${CHANNEL:-}" ] || CHANNEL="${SLACK_CHANNEL:-#echo-reading}"

curl -s -X POST "https://slack.com/api/chat.postMessage" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg channel "$CHANNEL" \
    --arg text "$MESSAGE" \
    '{channel: $channel, text: $text}')" \
  > /dev/null 2>&1 || true

exit 0
