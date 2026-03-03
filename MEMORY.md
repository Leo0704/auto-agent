# Auto-Agent 项目记忆

本文档存储跨会话的持久化记忆。在每次开始任务时会被 dev-workflow 自动读取。

## 项目概述

基于 Claude Code 的开发工作流增强系统。

## 核心组件

### 工作流系统
- dev-workflow: 8步开发流程（含学习记录）
- 团队模式: 复杂任务自动启用多agent协作
- 学习日志: .learnings/ 目录

### 钩子系统
- SessionStart: 显示当前任务
- Stop: 代码审核 + 任务续接
- PostToolUse(Bash): 错误检测

## 重要约定

- 提交时不添加 Co-Authored-By 标识
- 需求不清晰不写代码
- 工作流步骤通过 .workflow-step 文件跟踪

## 文件结构

```
auto-agent/
├── task/                   # 任务目录
│   ├── 2026-03-03-功能名/  # 任务子目录
│   │   ├── prd.pdf         # 需求文档
│   │   └── .workflow-step  # 工作流状态
│   └── .current-task       # 当前任务标识
├── .learnings/             # 学习日志
│   ├── LEARNINGS.md
│   ├── ERRORS.md
│   └── FEATURE_REQUESTS.md
├── hooks/                  # 钩子脚本
├── skills/                 # 技能文件
├── CLAUDE.md               # 项目规范
├── MEMORY.md               # 本文件
└── settings.json           # 配置
```

## 与系统记忆的关系

- `MEMORY.md`（本文件）: 项目级，跟随Git，工作流步骤0读取
- `~/.claude/projects/.../memory/`: 用户级自动记忆（不使用）
