#!/usr/bin/env bash
# PostToolUse 钩子：自动推送未同步的提交到远程仓库
#
# 每次 Edit/Write/MultiEdit 后静默检查：
#   - 是否有未推送的提交？
#   - 远程仓库是否可达？
#   - 如果都有 → 后台静默推送，不阻塞主线
#
# 任何异常一律 exit 0，不影响读书/写作流程。

input=$(cat 2>/dev/null) || exit 0

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

# Claude Code 环境：用 CLAUDE_PROJECT_DIR 定位仓库
repo_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$repo_root" ] || exit 0
[ -d "$repo_root/.git" ] || exit 0

cd "$repo_root" 2>/dev/null || exit 0

# 检查：有没有远程仓库？
git remote -v 2>/dev/null | grep -q 'fetch' || exit 0

# 检查：有没有未推送的提交？
ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
[ -n "$ahead" ] && [ "$ahead" -gt 0 ] || exit 0

# 后台推送（不阻塞 hook 链，最多等 30 秒）
git push --quiet 2>/dev/null &

exit 0
