#!/usr/bin/env bash
# PostToolUse 钩子：阅读里程碑 → Slack 通知
#
# 当 progress.md 被写入时（章/单元被标记读完），
# 发一条 Slack 通知，告知当前阅读进度。
#
# 触发条件（与 insight-reminder 相同）：
#   1. 工具是 Edit/Write/MultiEdit
#   2. 操作的是 books/<书名>/progress.md
#   3. 该文件内容发生了变化（哈希去重）
#
# 任何异常静默退出，不阻断读书主线。

input=$(cat 2>/dev/null) || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$file_path" ] || exit 0

# 只认 books/<书名>/progress.md
if [[ "$file_path" =~ /books/([^/]+)/progress\.md$ ]]; then
  book="${BASH_REMATCH[1]}"
else
  exit 0
fi

# 去重：同一 session 里同书 progress 同内容只通知一次
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

# 统计阅读进度
total_chapters=$(find "books/${book}" -maxdepth 1 -name 'ch*' -type d 2>/dev/null | wc -l)
completed_chapters=$(grep -c '^\- \[x\]' "books/${book}/progress.md" 2>/dev/null || echo 0)

# 构建通知消息
if [ "$completed_chapters" -eq "$total_chapters" ] && [ "$total_chapters" -gt 0 ]; then
  MESSAGE="📚 读完《${book}》！全书 ${total_chapters} 章全部完成 🎉"
elif [ "$completed_chapters" -gt 0 ]; then
  MESSAGE="📖 《${book}》进度更新：${completed_chapters}/${total_chapters} 章"
else
  exit 0
fi

# 调用通知脚本
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
export REPO_ROOT
bash "${REPO_ROOT}/.codex/hooks/slack-notify.sh" "$MESSAGE" 2>/dev/null || true

exit 0
