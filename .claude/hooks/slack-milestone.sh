#!/usr/bin/env bash
# PostToolUse 钩子（Claude Code 版）：阅读里程碑 → Slack 通知
#
# 逻辑与 Codex 版相同，差异仅在环境变量命名。

input=$(cat 2>/dev/null) || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$file_path" ] || exit 0

if [[ "$file_path" =~ /books/([^/]+)/progress\.md$ ]]; then
  book="${BASH_REMATCH[1]}"
else
  exit 0
fi

guard_dir="/tmp/slack-milestone-guard"
mkdir -p "$guard_dir" 2>/dev/null
marker="${guard_dir}/${session_id:-default}-${book}"
hash=$(shasum "$file_path" 2>/dev/null | cut -d' ' -f1)
if [ -n "$hash" ]; then
  last=""
  [ -f "$marker" ] && last=$(cat "$marker" 2>/dev/null)
  [ "$last" = "$hash" ] && exit 0
  printf '%s' "$hash" > "$marker" 2>/dev/null
fi

book_dir="books/${book}"
total_chapters=$(find "$book_dir" -maxdepth 1 -name 'ch*' -type d 2>/dev/null | wc -l)
completed_chapters=$(grep -c '^\- \[x\]' "$file_path" 2>/dev/null || echo 0)

if [ "$completed_chapters" -eq "$total_chapters" ] && [ "$total_chapters" -gt 0 ]; then
  MESSAGE="📚 读完《${book}》！全书 ${total_chapters} 章全部完成 🎉"
elif [ "$completed_chapters" -gt 0 ]; then
  MESSAGE="📖 《${book}》进度更新：${completed_chapters}/${total_chapters} 章"
else
  exit 0
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
export REPO_ROOT
bash "${REPO_ROOT}/.claude/hooks/slack-notify.sh" "$MESSAGE" 2>/dev/null || true

exit 0
