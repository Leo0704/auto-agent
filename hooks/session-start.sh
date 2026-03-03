#!/bin/bash
# 会话开始时注入上下文

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

# 列出所有可用任务
list_tasks() {
    if [ -d "$TASK_DIR" ]; then
        find "$TASK_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null
    fi
}

CURRENT_TASK_DIR=$(get_current_task)

# 有当前任务时，显示任务信息
if [ -n "$CURRENT_TASK_DIR" ]; then
    TASK_NAME=$(basename "$CURRENT_TASK_DIR")
    FILES=$(find "$CURRENT_TASK_DIR" -type f ! -name ".workflow-step" ! -name ".gitkeep" 2>/dev/null)
    FILE_COUNT=$(echo "$FILES" | grep -c . 2>/dev/null)

    echo "## 当前任务: $TASK_NAME"
    if [ "$FILE_COUNT" -gt 0 ]; then
        echo ""
        echo "需求文档 (${FILE_COUNT} 个):"
        echo "$FILES" | while read -r f; do
            echo "  - $(basename "$f")"
        done
    fi
    echo ""
    echo "---"
    echo ""
    echo "请使用 \`/dev-workflow\` 继续开发工作流。"
    echo ""
    echo "**需求理解不清晰，坚决不写代码！**"
    exit 0
fi

# 无当前任务时，显示可用任务列表
TASKS=$(list_tasks)
if [ -n "$TASKS" ]; then
    echo "## 可用任务"
    echo ""
    echo "$TASKS" | while read -r task; do
        echo "  - $task"
    done
    echo ""
    echo "使用以下命令切换任务："
    echo '```bash'
    echo "echo \"任务名\" > task/.current-task"
    echo '```'
    echo ""
    echo "或创建新任务目录后切换。"
else
    echo "老板好！请创建任务目录开始开发。"
    echo ""
    echo '```bash'
    echo "mkdir -p task/我的任务名"
    echo "echo \"我的任务名\" > task/.current-task"
    echo '```'
fi

echo ""
echo "**需求理解不清晰，坚决不写代码！**"
