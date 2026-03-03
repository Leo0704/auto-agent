#!/bin/bash
# 检查当前任务目录，显示需求文档列表

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TASK_DIR="$PROJECT_ROOT/task"
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

if [ -n "$CURRENT_TASK_DIR" ] && [ -d "$CURRENT_TASK_DIR" ]; then
    FILES=$(find "$CURRENT_TASK_DIR" -type f ! -name ".workflow-step" ! -name ".gitkeep" 2>/dev/null)
    FILE_COUNT=$(echo "$FILES" | grep -c . 2>/dev/null)
    if [ "$FILE_COUNT" -gt 0 ]; then
        TASK_NAME=$(basename "$CURRENT_TASK_DIR")
        echo "当前任务: $TASK_NAME"
        echo "需求文档 (${FILE_COUNT} 个):"
        echo "$FILES" | while read -r f; do
            echo "  - $(basename "$f")"
        done
        echo ""
        echo "老板，模糊点必须确认后再继续！"
    fi
fi
