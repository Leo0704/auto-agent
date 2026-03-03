# Auto-Agent 项目规范

本文档包含项目的关键约定和规范，供 AI 助手参考。

## 项目概述

这是一个 Claude Code 工作流增强项目，提供结构化的开发工作流和自我改进能力。

## 核心功能

### 1. 开发工作流 (dev-workflow)
- 8步开发流程：历史学习检查 → 需求理解 → 上下文调研 → 影响分析 → 实施计划 → 代码开发 → 代码审核 → 测试验证 → 学习记录
- 强制需求确认机制：需求不清晰不写代码
- 团队模式：复杂任务自动启用多 agent 协作

### 2. 学习日志系统
- `MEMORY.md` - 项目级跨会话记忆，存储重要约定和规范
- `.learnings/LEARNINGS.md` - 记录学习、纠正、最佳实践
- `.learnings/ERRORS.md` - 记录错误和解决方案
- `.learnings/FEATURE_REQUESTS.md` - 记录功能请求

## 目录结构

```
auto-agent/
├── .claude/
│   ├── hooks/              # 钩子脚本
│   ├── skills/             # 技能文件
│   └── task/               # 任务目录
├── .learnings/             # 学习日志
│   ├── LEARNINGS.md
│   ├── ERRORS.md
│   └── FEATURE_REQUESTS.md
├── hooks/                  # 项目级钩子
├── skills/                 # 项目级技能
├── settings.json           # Claude Code 配置
├── CLAUDE.md              # 本文件（项目规范）
└── MEMORY.md              # 跨会话记忆
```

## 钩子系统

| 钩子 | 触发时机 | 作用 |
|------|----------|------|
| SessionStart | 会话开始 | 显示当前任务 |
| UserPromptSubmit | 用户提交提示 | 检查需求 |
| PreToolUse | 工具使用前 | 检查文件边界和工作流步骤 |
| Stop | 会话结束 | 代码审核 + 任务续接提醒 |
| PostToolUse(Bash) | Bash命令后 | 错误检测，提醒记录到 .learnings/ |

## 开发规范

### 工作边界
- 只修改允许修改的项目/目录
- 参考其他项目代码时只读取不修改

### 代码风格
- Shell 脚本使用 bash shebang
- 保持钩子脚本精简，避免性能影响

### 提交规范
- 不添加 Co-Authored-By 标识

## 常用命令

```bash
# 创建新任务
mkdir -p .claude/task/$(date +%Y-%m-%d)-功能名称
echo "$(date +%Y-%m-%d)-功能名称" > .claude/task/.current-task

# 查看当前工作流步骤
cat .claude/task/$(cat .claude/task/.current-task)/.workflow-step

# 记录学习到 MEMORY.md（重要约定）
echo "- 新约定内容" >> MEMORY.md

# 记录学习到 .learnings/
echo "## [LRN-$(date +%Y%m%d)-001] category" >> .learnings/LEARNINGS.md

# 记录错误
echo "## [ERR-$(date +%Y%m%d)-001] command" >> .learnings/ERRORS.md
```
