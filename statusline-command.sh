#!/bin/bash
# Claude Code 状态栏脚本 - 显示模型、上下文使用率、费用

input=$(cat)
TODAY=$(date +%Y-%m-%d)

# 模型名
model=$(echo "$input" | jq -r '.model.display_name')

# 上下文使用百分比
usage=$(echo "$input" | jq '.context_window.current_usage')
size=$(echo "$input" | jq '.context_window.context_window_size // 200000')
if [ "$usage" != "null" ]; then
    input_tok=$(echo "$usage" | jq '.input_tokens // 0')
    cache_create=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
    pct=$(( (input_tok + cache_create + cache_read) * 100 / size ))
    context_info="${pct}% ctx"
else
    context_info="--"
fi

# 会话费用
session_cost=$(printf "%.2f" "$(echo "$input" | jq -r '.cost.total_cost_usd // 0')")

# 今日累计费用（从 JSONL 计算）
daily_cost=$(cat ~/.claude/projects/*/*.jsonl 2>/dev/null | \
    grep "\"type\":\"assistant\"" | grep "$TODAY" | \
    jq -r '[.message.id, .message.model, .message.usage.input_tokens, .message.usage.output_tokens, (.message.usage.cache_creation_input_tokens // 0), (.message.usage.cache_read_input_tokens // 0)] | @tsv' 2>/dev/null | \
    sort -t'	' -k1,1 -k3,3rn -k4,4rn | \
    awk -F'\t' '
    !seen[$1]++ {
        m=$2; i=$3; o=$4; cw=$5; cr=$6
        if (m ~ /opus-4-5/) cost = (i*5 + o*25 + cw*6.25 + cr*0.50) / 1000000
        else if (m ~ /opus/) cost = (i*15 + o*75 + cw*18.75 + cr*1.50) / 1000000
        else if (m ~ /sonnet/) cost = (i*3 + o*15 + cw*3.75 + cr*0.30) / 1000000
        else if (m ~ /haiku-3-5/) cost = (i*0.80 + o*4 + cw*1 + cr*0.08) / 1000000
        else if (m ~ /haiku/) cost = (i*1 + o*5 + cw*1.25 + cr*0.10) / 1000000
        total += cost
    }
    END { printf "%.2f", total }')

printf "%s | %s | \$%s / \$%s" "$model" "$context_info" "$session_cost" "$daily_cost"
