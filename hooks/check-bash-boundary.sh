#!/bin/bash
# Best-effort: 检查 Bash 命令中的写操作是否超出项目边界
# 读取项目配置，只允许在配置中指定的目录执行写操作

if ! command -v jq &> /dev/null; then
    exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
    exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.claude/config.json"

# 读取允许的路径
ALLOWED_PREFIXES=()
ALLOWED_PREFIXES+=("$PROJECT_ROOT")
ALLOWED_PREFIXES+=("$HOME/.claude")

# 从配置文件读取额外的允许路径
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r path; do
        if [ -n "$path" ]; then
            if [[ "$path" != /* ]]; then
                path="$PROJECT_ROOT/$path"
            fi
            ALLOWED_PREFIXES+=("$path")
        fi
    done < <(jq -r '.allowedPaths[]? // empty' "$CONFIG_FILE" 2>/dev/null)
fi

check_path() {
    local path="$1"
    [[ "$path" != /* ]] && return 0

    for allowed in "${ALLOWED_PREFIXES[@]}"; do
        [[ "$path" == "$allowed"* ]] && return 0
    done

    echo "禁止: Bash 命令写入项目外路径: $path" >&2
    echo "如需修改此路径，请在 .claude/config.json 中配置 allowedPaths。" >&2
    exit 2
}

# 重定向 > 或 >> 到绝对路径
for target in $(echo "$COMMAND" | grep -oE '>>?\s+/[^ ]+' | grep -oE '/[^ ]+'); do
    check_path "$target"
done

# tee 到绝对路径
for target in $(echo "$COMMAND" | grep -oE 'tee\s+(-a\s+)?/[^ ]+' | grep -oE '/[^ ]+'); do
    check_path "$target"
done

# cp/mv 最后一个参数是绝对路径
if echo "$COMMAND" | grep -qE '^\s*(cp|mv)\s'; then
    LAST_ARG=$(echo "$COMMAND" | awk '{print $NF}')
    [[ "$LAST_ARG" == /* ]] && check_path "$LAST_ARG"
fi

# sed -i 目标文件
SED_TARGET=$(echo "$COMMAND" | grep -oE "sed\s+-i[^ ]*\s+.*" | awk '{print $NF}')
[[ -n "$SED_TARGET" && "$SED_TARGET" == /* ]] && check_path "$SED_TARGET"

exit 0
