#!/usr/bin/env bash
# PostToolUse 钩子（Claude Code 版）：编辑 .sh 脚本后自动 shellcheck

input=$(cat 2>/dev/null) || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[ -n "$file_path" ] || exit 0

[[ "$file_path" == *.sh ]] || exit 0
[ -f "$file_path" ] || exit 0

command -v shellcheck &>/dev/null || exit 0

result=$(shellcheck --severity=warning --format=gcc "$file_path" 2>&1) || true
[ -n "$result" ] || exit 0

ctx="【脚本诊断·副线，勿打断主线】刚编辑了 ${file_path}，shellcheck 发现以下问题：\n${result}\n\n请评估是否需要修复。若无需修复（如故意为之），忽略即可。"

jq -n --arg ctx "$ctx" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}' 2>/dev/null

exit 0
