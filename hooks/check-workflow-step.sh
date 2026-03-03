#!/bin/bash
# 工作流步骤检查
# 有需求文档时，必须走完前4步才能写代码

if ! command -v jq &> /dev/null; then
    exit 0
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.claude/config.json"
TASK_DIR="$PROJECT_ROOT/.claude/task"
CURRENT_TASK_FILE="$TASK_DIR/.current-task"

# 获取当前任务目录
get_current_task() {
    if [ -f "$CURRENT_TASK_FILE" ]; then
        local task_name=$(cat "$CURRENT_TASK_FILE" 2>/dev/null | tr -d ' \n')
        if [ -n "$task_name" ] && [ -d "$TASK_DIR/$task_name" ]; then
            echo "$TASK_DIR/$task_name"
            return
        fi
    fi
    echo ""
}

CURRENT_TASK_DIR=$(get_current_task)
STEP_FILE="$CURRENT_TASK_DIR/.workflow-step"

# 没有当前任务 → 不强制
if [ -z "$CURRENT_TASK_DIR" ]; then
    exit 0
fi

# 检查任务目录是否有需求文档
FILE_COUNT=$(find "$CURRENT_TASK_DIR" -type f ! -name ".workflow-step" ! -name ".gitkeep" 2>/dev/null | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -eq 0 ]; then
    exit 0
fi

# 检查是否是代码文件
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
    *.go|*.vue|*.ts|*.js|*.jsx|*.tsx|*.py|*.java|*.rs|*.c|*.cpp|*.h|*.php|*.rb|*.swift|*.kt)
        ;;
    *)
        exit 0
        ;;
esac

# 排除：允许写入工作流状态文件本身
if [[ "$FILE_PATH" == *".workflow-step"* ]]; then
    exit 0
fi

# 读取当前步骤
CURRENT_STEP=0
if [ -f "$STEP_FILE" ]; then
    CURRENT_STEP=$(cat "$STEP_FILE" 2>/dev/null | tr -d ' \n')
    if ! [[ "$CURRENT_STEP" =~ ^[0-9]+$ ]]; then
        CURRENT_STEP=0
    fi
fi

# 步骤 >= 5 才能写代码
if [ "$CURRENT_STEP" -lt 5 ]; then
    echo "⛔ 工作流拦截: 当前在步骤 ${CURRENT_STEP}，必须完成到步骤 5（代码开发）才能修改代码文件" >&2
    echo "" >&2
    if [ "$CURRENT_STEP" -eq 0 ]; then
        echo "还没开始工作流。请先使用 /dev-workflow 执行需求理解。" >&2
    else
        echo "请先完成步骤 $((CURRENT_STEP + 1)) 再继续。" >&2
    fi
    echo "如需跳过工作流，请先清空需求文档目录。" >&2
    exit 2
fi

exit 0
