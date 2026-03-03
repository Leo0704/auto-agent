#!/bin/bash
# 代码审核脚本
# 在代码修改后触发审核提醒，自动检测项目类型并执行对应的检查

if ! command -v jq &> /dev/null; then
    exit 0
fi

INPUT=$(cat)

STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0

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
exit 0
