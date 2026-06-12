#!/usr/bin/env bash
# PostToolUse 钩子：编辑 .sh 脚本后自动 shellcheck
#
# 当 Edit/Write 改动了 .sh 文件时，用 shellcheck 检查语法，
# 把诊断结果注入为 additionalContext，方便及时发现和修复。
#
# 触发条件：
#   1. 工具是 Edit/Write/MultiEdit
#   2. 操作的是 .sh 文件
#   3. 机器上装了 shellcheck
#
# 静默退出策略：shellcheck 没装 → 跳过；文件语法完美 → 跳过

input=$(cat 2>/dev/null) || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[ -n "$file_path" ] || exit 0

# 只认 .sh 文件
[[ "$file_path" == *.sh ]] || exit 0
[ -f "$file_path" ] || exit 0

# 需要 shellcheck
command -v shellcheck &>/dev/null || exit 0

# 运行检查
result=$(shellcheck --severity=warning --format=gcc "$file_path" 2>&1) || true
[ -n "$result" ] || exit 0   # 没问题，静默退出

# 有问题 → 注入提醒
ctx="【脚本诊断·副线，勿打断主线】刚编辑了 ${file_path}，shellcheck 发现以下问题：\n${result}\n\n请评估是否需要修复。若无需修复（如故意为之），忽略即可。"

jq -n --arg ctx "$ctx" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}' 2>/dev/null

exit 0
