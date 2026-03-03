#!/bin/bash
# 代码审核脚本
# 在代码修改后触发审核提醒，自动检测项目类型并执行对应的检查
# 同时检查是否有未完成的任务，提示继续工作流

if ! command -v jq &> /dev/null; then
    exit 0
fi

INPUT=$(cat)

STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0

# === 任务续接检查 ===
TASK_DIR="$PROJECT_ROOT/.claude/task"
CURRENT_TASK_FILE="$TASK_DIR/.current-task"

check_pending_tasks() {
    # 检查是否有当前任务
    if [ -f "$CURRENT_TASK_FILE" ]; then
        local task_name=$(cat "$CURRENT_TASK_FILE" 2>/dev/null | tr -d ' \n')
        if [ -n "$task_name" ] && [ -d "$TASK_DIR/$task_name" ]; then
            local step_file="$TASK_DIR/$task_name/.workflow-step"
            if [ -f "$step_file" ]; then
                local current_step=$(cat "$step_file" 2>/dev/null | tr -d ' \n')
                if [ -n "$current_step" ] && [[ "$current_step" =~ ^[0-9]+$ ]]; then
                    if [ "$current_step" -lt 7 ]; then
                        echo ""
                        echo "---"
                        echo ""
                        echo "## 📋 任务续接提醒"
                        echo ""
                        echo "**当前任务:** $task_name"
                        echo "**当前步骤:** $current_step / 7"
                        echo ""
                        echo "工作流尚未完成，请使用 \`/dev-workflow\` 继续。"
                        echo ""
                        return 0
                    else
                        # 步骤7已完成，提示清理
                        echo ""
                        echo "---"
                        echo ""
                        echo "## ✅ 任务完成"
                        echo ""
                        echo "**当前任务:** $task_name"
                        echo "**状态:** 工作流已完成（步骤 7/7）"
                        echo ""
                        echo "建议清理："
                        echo '```bash'
                        echo "rm .claude/task/$task_name/.workflow-step"
                        echo '```'
                        echo ""
                        echo "如需开始新任务，请创建新的任务目录。"
                        echo ""
                        return 0
                    fi
                fi
            fi
        fi
    fi

    # 检查是否有其他待处理任务（没有.current-task但有任务目录）
    if [ -d "$TASK_DIR" ]; then
        local pending_tasks=$(find "$TASK_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -5)
        if [ -n "$pending_tasks" ]; then
            echo ""
            echo "---"
            echo ""
            echo "## 📋 可用任务"
            echo ""
            echo "$pending_tasks" | while read -r task_dir; do
                local task_name=$(basename "$task_dir")
                echo "  - $task_name"
            done
            echo ""
            echo "使用以下命令切换任务："
            echo '```bash'
            echo "echo \"任务名\" > .claude/task/.current-task"
            echo '```'
            echo ""
            echo "然后使用 \`/dev-workflow\` 开始工作流。"
            echo ""
        fi
    fi
}

# 检查是否有未提交的修改
CHANGES=$(git status --porcelain 2>/dev/null)
if [ -z "$CHANGES" ]; then
    exit 0
fi

CHANGE_COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')

# 检测项目类型
detect_project_type() {
    if [ -f "go.mod" ]; then
        echo "go"
    elif [ -f "package.json" ]; then
        echo "node"
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        echo "python"
    elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
        echo "java"
    elif [ -f "Cargo.toml" ]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

PROJECT_TYPE=$(detect_project_type)

# 根据项目类型执行检查
BUILD_STATUS="未检查"
LINT_STATUS="未检查"
BUILD_ERROR=""
LINT_ERROR=""

case "$PROJECT_TYPE" in
    go)
        # Go 项目检查
        HAS_GO_CHANGES=$(echo "$CHANGES" | grep '\.go$' | head -1)
        if [ -n "$HAS_GO_CHANGES" ]; then
            BUILD_OUTPUT=$(go build ./... 2>&1)
            if [ $? -eq 0 ]; then
                BUILD_STATUS="通过"
            else
                BUILD_STATUS="失败"
                BUILD_ERROR=$(echo "$BUILD_OUTPUT" | head -5)
            fi

            VET_OUTPUT=$(go vet ./... 2>&1)
            if [ $? -eq 0 ]; then
                LINT_STATUS="通过"
            else
                LINT_STATUS="失败"
                LINT_ERROR=$(echo "$VET_OUTPUT" | head -5)
            fi

            FMT_OUTPUT=$(gofmt -l . 2>&1)
            if [ -z "$FMT_OUTPUT" ]; then
                FMT_STATUS="通过"
            else
                gofmt -w . 2>/dev/null
                FMT_STATUS="已自动格式化"
            fi
        fi
        ;;
    node)
        # Node.js 项目检查
        HAS_JS_CHANGES=$(echo "$CHANGES" | grep -E '\.(js|ts|jsx|tsx|vue)$' | head -1)
        if [ -n "$HAS_JS_CHANGES" ]; then
            # 检测包管理器
            if [ -f "pnpm-lock.yaml" ]; then
                PKG_MANAGER="pnpm"
            elif [ -f "yarn.lock" ]; then
                PKG_MANAGER="yarn"
            else
                PKG_MANAGER="npm"
            fi

            if [ -f "package.json" ] && grep -q '"build"' package.json; then
                BUILD_OUTPUT=$($PKG_MANAGER run build 2>&1)
                if [ $? -eq 0 ]; then
                    BUILD_STATUS="通过"
                else
                    BUILD_STATUS="失败"
                    BUILD_ERROR=$(echo "$BUILD_OUTPUT" | head -5)
                fi
            fi

            if [ -f "package.json" ] && grep -q '"lint"' package.json; then
                LINT_OUTPUT=$($PKG_MANAGER run lint 2>&1)
                if [ $? -eq 0 ]; then
                    LINT_STATUS="通过"
                else
                    LINT_STATUS="失败"
                    LINT_ERROR=$(echo "$LINT_OUTPUT" | head -5)
                fi
            fi
        fi
        ;;
    python)
        # Python 项目检查
        HAS_PY_CHANGES=$(echo "$CHANGES" | grep '\.py$' | head -1)
        if [ -n "$HAS_PY_CHANGES" ]; then
            if command -v python &> /dev/null; then
                BUILD_OUTPUT=$(python -m py_compile . 2>&1)
                if [ $? -eq 0 ]; then
                    BUILD_STATUS="通过"
                else
                    BUILD_STATUS="失败"
                    BUILD_ERROR=$(echo "$BUILD_OUTPUT" | head -5)
                fi
            fi
        fi
        ;;
esac

# 构建输出
OUTPUT="---

**老板，检测到 ${CHANGE_COUNT} 个文件被修改，请确认：**

- [ ] 边界检查: 只修改了允许修改的项目
- [ ] 代码风格: 符合项目规范
- [ ] 安全性: 无注入等风险
- [ ] 错误处理: 完善

**项目类型:** ${PROJECT_TYPE}"

if [ "$BUILD_STATUS" != "未检查" ] || [ "$LINT_STATUS" != "未检查" ]; then
    OUTPUT="${OUTPUT}

**编译/检查结果:**"

    if [ "$BUILD_STATUS" != "未检查" ]; then
        OUTPUT="${OUTPUT}
- build: ${BUILD_STATUS}"
    fi

    if [ "$LINT_STATUS" != "未检查" ]; then
        OUTPUT="${OUTPUT}
- lint: ${LINT_STATUS}"
    fi
fi

if [ -n "$BUILD_ERROR" ]; then
    OUTPUT="${OUTPUT}

**编译错误详情:**
\`\`\`
${BUILD_ERROR}
\`\`\`"
fi

if [ -n "$LINT_ERROR" ]; then
    OUTPUT="${OUTPUT}

**检查错误详情:**
\`\`\`
${LINT_ERROR}
\`\`\`"
fi

OUTPUT="${OUTPUT}

**需要详细审核请使用 /code-review 技能**"

echo "$OUTPUT"

# 检查待续接的任务
check_pending_tasks

exit 0
