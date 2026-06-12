#!/usr/bin/env bash
# SessionStart 钩子：会话开始时注入一句"回声"——让上下文无缝衔接
#
# 扫描所有书的 progress.md + insight/INDEX.md，
# 生成一句摘要注入到会话开头。
#
# 输出格式示例：
#   上次在《乡土中国》第4章 · 3条概念 / 0个悬题开放

input=$(cat 2>/dev/null) || exit 0

# 定位项目根
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$REPO_ROOT" ] || exit 0
cd "$REPO_ROOT" 2>/dev/null || exit 0

# ── 1. 扫描阅读进度 ──
progress_lines=""

for progress_file in books/*/progress.md; do
  [ -f "$progress_file" ] || continue

  book_name=$(basename "$(dirname "$progress_file")")

  # 找最后一个已完成的章（- [x] chNN ... 或带子单元的 - [x] chNN — ...）
  last_chapter=""
  last_chapter_title=""

  while IFS= read -r line; do
    # 顶级已完成章：- [x] chNN — 标题
    if echo "$line" | grep -qP '^\- \[x\] ch\d+'; then
      last_chapter=$(echo "$line" | sed -E 's/^- \[x\] (ch[0-9]+).*/\1/')
      last_chapter_title=$(echo "$line" | sed -E 's/^- \[x\] ch[0-9]+ — (.*)/\1/' | sed 's/ · 回看.*//')
    fi
  done < "$progress_file"

  if [ -n "$last_chapter" ]; then
    # 计算总章数和已完成数
    total=$(grep -cP '^\- \[[ x]\] ch\d+' "$progress_file" 2>/dev/null || echo 0)
    done_count=$(grep -cP '^\- \[x\] ch\d+' "$progress_file" 2>/dev/null || echo 0)

    # 如果有子单元，找最后一个完成的单元
    last_unit=""
    while IFS= read -r line; do
      if echo "$line" | grep -qP '^  \- \[x\] \d+'; then
        last_unit=$(echo "$line" | sed -E 's/^  - \[x\] ([0-9]+).*/\1/')
      fi
    done < "$progress_file"

    if [ -n "$last_unit" ]; then
      unit_info=" 单元${last_unit}"
    else
      unit_info=""
    fi

    progress_lines="${progress_lines}《${book_name}》${last_chapter}${unit_info} (${done_count}/${total}章)\n"
  else
    # 还没开始读
    total=$(grep -cP '^\- \[[ x]\] ch\d+' "$progress_file" 2>/dev/null || echo 0)
    progress_lines="${progress_lines}《${book_name}》未开始 (0/${total}章)\n"
  fi
done

# ── 2. 扫描 insight 沉淀 ──
INDEX_FILE="insight/INDEX.md"
concept_count=0
story_count=0
flashback_count=0
resonance_count=0
open_question_count=0
answered_question_count=0

current_section=""
if [ -f "$INDEX_FILE" ]; then
  while IFS= read -r line; do
    case "$line" in
      "## 概念") current_section="概念" ;;
      "## 你的故事") current_section="故事" ;;
      "## 闪回") current_section="闪回" ;;
      "## 共振") current_section="共振" ;;
      "## 悬题（开放中）") current_section="悬题开放" ;;
      "## 悬题（已被生活答了）") current_section="悬题已答" ;;
      "## "*) current_section="" ;;  # 其他标题，跳过
    esac

    # 统计非空条目行（以 [[ 开头）
    if echo "$line" | grep -qP '^\[\[.+\]\]'; then
      case "$current_section" in
        "概念") concept_count=$((concept_count + 1)) ;;
        "故事") story_count=$((story_count + 1)) ;;
        "闪回") flashback_count=$((flashback_count + 1)) ;;
        "共振") resonance_count=$((resonance_count + 1)) ;;
        "悬题开放") open_question_count=$((open_question_count + 1)) ;;
        "悬题已答") answered_question_count=$((answered_question_count + 1)) ;;
      esac
    fi
  done < "$INDEX_FILE"
fi

# ── 3. 构建回声 ──
total_insight=$((concept_count + story_count + flashback_count + resonance_count))

# 构建 insight 摘要（只列非零维度）
insight_parts=""
[ "$concept_count" -gt 0 ] && insight_parts="${insight_parts}${concept_count}条概念 · "
[ "$story_count" -gt 0 ] && insight_parts="${insight_parts}${story_count}个故事 · "
[ "$flashback_count" -gt 0 ] && insight_parts="${insight_parts}${flashback_count}个闪回 · "
[ "$resonance_count" -gt 0 ] && insight_parts="${insight_parts}${resonance_count}个共振 · "

# 去末尾的 " · "
insight_parts="${insight_parts% · }"

[ -z "$insight_parts" ] && insight_parts="暂无沉淀"

# 悬题
question_info=""
[ "$open_question_count" -gt 0 ] && question_info="${open_question_count}个悬题未解"
[ "$answered_question_count" -gt 0 ] && question_info="${question_info}${question_info:+，}${answered_question_count}个已被生活答了"

# 拼装最终消息
echo_msg="【会话回声】"
echo_msg="${echo_msg}\n📖 ${progress_lines}"
if [ -n "$insight_parts" ] && [ "$insight_parts" != "暂无沉淀" ]; then
  echo_msg="${echo_msg}💡 ${insight_parts}"
fi
if [ -n "$question_info" ]; then
  echo_msg="${echo_msg} · ${question_info}"
fi
echo_msg="${echo_msg}\n(以上来自 SessionStart hook 自动扫描)"

# 去掉末尾多余换行
echo_msg=$(printf '%b' "$echo_msg" | sed '/^$/d')

# 输出
jq -n --arg ctx "$echo_msg" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}' 2>/dev/null

exit 0
