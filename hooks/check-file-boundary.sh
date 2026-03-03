#!/bin/bash
# 检查文件修改边界
# 读取项目配置，只允许修改配置中指定的目录

if ! command -v jq &> /dev/null; then
    exit 0
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# 规范化文件路径
normalize_path() {
    local path="$1"
    if [ -e "$path" ]; then
        echo "$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")"
    else
        local dir=$(dirname "$path")
        local base=$(basename "$path")
        if [ -d "$dir" ]; then
            echo "$(cd "$dir" 2>/dev/null && pwd)/$base"
        else
            echo "$path"
        fi
    fi
}

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# 读取配置文件
CONFIG_FILE="$PROJECT_ROOT/.claude/config.json"
ALLOWED_PATHS=()
FORBIDDEN_PATTERNS=()

# 默认允许的路径
DEFAULT_ALLOWED_PATHS=(
    "$PROJECT_ROOT"
    "$HOME/.claude"
)

# 默认禁止的文件模式
DEFAULT_FORBIDDEN_PATTERNS=(
    ".env"
    ".env.local"
    ".env.production"
    ".env.development"
    "*.pem"
    "*.key"
    "*.p12"
    "credentials.json"
    "secrets.yaml"
    "secrets.json"
)

# 从配置文件读取允许的路径
if [ -f "$CONFIG_FILE" ]; then
    # 读取 allowedPaths 数组
    while IFS= read -r path; do
        if [ -n "$path" ]; then
            # 处理相对路径
            if [[ "$path" != /* ]]; then
                path="$PROJECT_ROOT/$path"
            fi
            ALLOWED_PATHS+=("$path")
        fi
    done < <(jq -r '.allowedPaths[]? // empty' "$CONFIG_FILE" 2>/dev/null)

    # 读取 forbiddenPatterns 数组
    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            FORBIDDEN_PATTERNS+=("$pattern")
        fi
    done < <(jq -r '.forbiddenPatterns[]? // empty' "$CONFIG_FILE" 2>/dev/null)
fi

# 如果没有配置，使用默认值
if [ ${#ALLOWED_PATHS[@]} -eq 0 ]; then
    ALLOWED_PATHS=("${DEFAULT_ALLOWED_PATHS[@]}")
fi

if [ ${#FORBIDDEN_PATTERNS[@]} -eq 0 ]; then
    FORBIDDEN_PATTERNS=("${DEFAULT_FORBIDDEN_PATTERNS[@]}")
fi

# 规范化待检查的路径
NORMALIZED_PATH=$(normalize_path "$FILE_PATH")

# 检查文件路径是否在允许范围内
is_allowed() {
    local path="$1"
    for allowed in "${ALLOWED_PATHS[@]}"; do
        if [[ "$path" == "$allowed"* ]]; then
            return 0
        fi
    done
    return 1
}

# 检查是否是敏感文件
is_sensitive_file() {
    local path="$1"
    local basename=$(basename "$path")

    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
        case "$basename" in
            $pattern) return 0 ;;
        esac
    done
    return 1
}

if is_allowed "$NORMALIZED_PATH"; then
    if is_sensitive_file "$NORMALIZED_PATH"; then
        echo "禁止修改敏感文件: $FILE_PATH" >&2
        echo "敏感配置文件（.env, *.pem, *.key 等）禁止修改。" >&2
        exit 2
    fi
    exit 0
else
    echo "禁止修改: $FILE_PATH" >&2
    echo "该文件不在允许修改的范围内。" >&2
    echo "如需修改此文件，请在 .claude/config.json 中配置 allowedPaths。" >&2
    exit 2
fi
