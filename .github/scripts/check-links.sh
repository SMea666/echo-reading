#!/usr/bin/env bash
# 检查所有 markdown 文件中的 [[wiki-style]] 链接是否有效
# 
# 链接格式：
#   [[概念/xxx]]              → insight/概念/xxx.md
#   [[乡土中国/ch03/03]]       → books/乡土中国/ch03/03.md
#   [[乡土中国/ch03/03|显示名]] → 同上（| 后面是显示文本，忽略）
#
# 规则：
#   1. 链接路径第一段匹配 books/ 下某个书名 → 视为书籍引用，解析到 books/
#   2. 链接路径第一段匹配 insight/ 下某个维度 → 视为 insight 引用，解析到 insight/
#   3. 链接路径包含 / → 是完整路径，直接检查
#   4. 都不匹配 → 报错
#
# 退出码：0=全部有效，1=存在断链

set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

BROKEN=0
TOTAL=0

# 收集所有已知书名（books/ 下的目录，排除 .gitkeep 等非目录）
KNOWN_BOOKS=""
for d in books/*/; do
  name=$(basename "$d")
  [ "$name" = ".gitkeep" ] && continue
  KNOWN_BOOKS="$KNOWN_BOOKS $name"
done

# 收集所有 insight 维度（insight/ 下的目录）
KNOWN_DIMS=""
for d in insight/*/; do
  name=$(basename "$d")
  [ "$name" = ".gitkeep" ] && continue
  KNOWN_DIMS="$KNOWN_DIMS $name"
done

echo "=== 链接检查 ==="
echo "已知书籍: $KNOWN_BOOKS"
echo "已知维度: $KNOWN_DIMS"
echo ""

# 扫描所有 .md 文件中的 [[...]] 链接
while IFS=: read -r file line_num content; do
  # 提取所有 [[...]] 链接（一行可能有多个）
  links=$(echo "$content" | grep -oP '\[\[\K[^]]+(?=\]\])' || true)
  [ -z "$links" ] && continue

  while IFS= read -r link; do
    [ -z "$link" ] && continue
    TOTAL=$((TOTAL + 1))

    # 去掉 | 后面的显示文本
    target="${link%%|*}"
    target="${target%%#*}"   # 也去掉 # 锚点（如果有）

    # 跳过示例 / 模板占位符链接（如 [[书名/章节/单元]]、[[条目名]]）
    first_seg="${target%%/*}"
    case "$first_seg" in
      书名|条目名|维度|条目|章节) continue ;;
    esac

    # 跳过外部链接
    [[ "$target" =~ ^https?:// ]] && continue

    # 确定目标文件路径
    target_file=""
    first_seg="${target%%/*}"

    if echo "$KNOWN_BOOKS" | grep -qw "$first_seg"; then
      # 是书籍引用 → books/<书名>/<剩余路径>.md
      target_file="books/${target}.md"
    elif echo "$KNOWN_DIMS" | grep -qw "$first_seg"; then
      # 是 insight 引用 → insight/<维度>/<条目>.md
      target_file="insight/${target}.md"
    elif [[ "$target" == */* ]]; then
      # 包含 / 的完整路径
      target_file="${target}.md"
    else
      # 纯条目名——去 insight 各维度下找
      found=""
      for dim in $KNOWN_DIMS; do
        if [ -f "insight/${dim}/${target}.md" ]; then
          found="insight/${dim}/${target}.md"
          break
        fi
      done
      if [ -n "$found" ]; then
        target_file="$found"
      else
        target_file="${target}.md"
      fi
    fi

    # 跳过被 .gitignore 排除的 insight 个人笔记（概念/故事/闪回/共振/悬题）
    # 这些文件只在本地存在，CI 上没有，不应算断链
    if [[ "$target_file" =~ ^insight/(概念|你的故事|闪回|共振|悬题)/ ]]; then
      continue
    fi

    # 检查文件是否存在
    if [ ! -f "$target_file" ]; then
      echo "❌ $file:$line_num  [[${link}]]  →  $target_file  (不存在)"
      BROKEN=$((BROKEN + 1))
    else
      echo "✅ $file:$line_num  [[${link}]]  →  $target_file"
    fi
  done <<< "$links"
done < <(grep -rn '\[\[' books/ insight/ --include='*.md' 2>/dev/null || true)

echo ""
echo "=== 结果 ==="
echo "检查链接总数: $TOTAL"
echo "断链数: $BROKEN"

if [ "$BROKEN" -gt 0 ]; then
  echo ""
  echo "💥 发现 $BROKEN 个断链，请修复后再提交。"
  exit 1
else
  echo "✅ 所有链接有效。"
  exit 0
fi
