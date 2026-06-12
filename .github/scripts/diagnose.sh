#!/usr/bin/env bash
# 一键诊断：shell 脚本质量 + JSON 语法 + Markdown 链接
#
# 用法：
#   bash diagnose.sh              # 检查所有
#   bash diagnose.sh --ci         # CI 模式（严格，有错就退 1）
#
# 依赖：shellcheck, jq

set -euo pipefail

CI_MODE=false
[ "${1:-}" = "--ci" ] && CI_MODE=true

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0

# ── 头 ──────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "  echo-reading 诊断报告"
echo "═══════════════════════════════════════════"
echo ""

# ── 1. ShellCheck ────────────────────────────────────
echo "── 1. Shell 脚本检查 (shellcheck) ──"
echo ""

if command -v shellcheck &>/dev/null; then
  while IFS= read -r -d '' file; do
    result=$(shellcheck --severity=warning --format=gcc "$file" 2>&1) || true
    if [ -z "$result" ]; then
      echo "  ✅ $(basename "$file")"
      PASS=$((PASS + 1))
    else
      echo "  ❌ $(basename "$file")"
      echo "$result" | while IFS= read -r line; do
        echo "     $line"
      done
      FAIL=$((FAIL + 1))
    fi
  done < <(find . -name '*.sh' -not -path './.git/*' -print0 2>/dev/null)
  echo ""
else
  echo "  ⚠️  shellcheck 未安装，跳过"
  echo "     安装: brew install shellcheck / apt install shellcheck"
  echo ""
fi

# ── 2. JSON 语法 ─────────────────────────────────────
echo "── 2. JSON 语法检查 ──"
echo ""

if command -v jq &>/dev/null; then
  while IFS= read -r -d '' file; do
    if jq empty "$file" 2>/dev/null; then
      echo "  ✅ ${file#./}"
      PASS=$((PASS + 1))
    else
      echo "  ❌ ${file#./} — JSON 语法错误"
      FAIL=$((FAIL + 1))
    fi
  done < <(find . -name '*.json' -not -path './.git/*' -print0 2>/dev/null)
  echo ""
else
  echo "  ⚠️  jq 未安装，跳过"
  echo ""
fi

# ── 3. 链接检查（复用已有脚本）────────────────────────
echo "── 3. Wiki 链接检查 ──"
echo ""

if [ -f ".github/scripts/check-links.sh" ]; then
  if bash .github/scripts/check-links.sh . 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
else
  echo "  ⚠️  链接检查脚本不存在，跳过"
fi

# ── 尾 ──────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "  通过: $PASS  ·  失败: $FAIL"
echo "═══════════════════════════════════════════"

if $CI_MODE && [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
