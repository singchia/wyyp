#!/usr/bin/env bash
# install.sh — 在你的项目根目录运行,安装并激活 wyyp
#
# 它做几件事:
#   1. 安装 wyyp skill 到 ~/.claude/skills/wyyp/
#   2. 在当前目录创建 AGENTS.md(Codex / Cline / Cursor 等通用 agent 入口)
#   3. 检测 Cursor,自动落 .cursor/rules/wyyp.mdc
#   4. 安装 /wyyp 斜杠命令到 ~/.claude/commands/wyyp.md(Claude Code)
#   5. 可选落 .wyyp.yml 模板
#
# 用法(远程):
#     cd your-project
#     bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/install.sh)
#
# 用法(本地已 clone):
#     cd your-project
#     ~/.claude/skills/wyyp/scripts/install.sh
#
# 项目级安装:
#     SKILL_DIR=.claude/skills/wyyp bash <(curl -sSL .../install.sh)
#
# 跳过子项:
#     NO_CURSOR=1 NO_COMMAND=1 NO_CONFIG=1 bash <(curl -sSL .../install.sh)

set -euo pipefail

REPO_URL="https://github.com/singchia/wyyp.git"
SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/wyyp}"
COMMAND_DIR="${COMMAND_DIR:-$HOME/.claude/commands}"
TEMPLATE_REL="docs/templates/project-agents-template.md"
CURSOR_TEMPLATE_REL="docs/templates/cursor-rule-template.mdc"
CONFIG_TEMPLATE_REL="docs/templates/wyyp-config-template.yml"
COMMAND_SRC_REL="commands/wyyp.md"
TARGET_AGENTS="./AGENTS.md"
TARGET_CURSOR_DIR="./.cursor/rules"
TARGET_CURSOR="$TARGET_CURSOR_DIR/wyyp.mdc"
TARGET_CONFIG="./.wyyp.yml"
TARGET_COMMAND="$COMMAND_DIR/wyyp.md"

echo "📦 wyyp(我要验牌)安装"
echo ""

# ────────────────────────────────────────────────────────
# Step 1: skill 安装
# ────────────────────────────────────────────────────────
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
    echo "✓ wyyp skill 已安装在 $SKILL_DIR"
    if command -v git >/dev/null 2>&1 && [[ -d "$SKILL_DIR/.git" ]]; then
        if git -C "$SKILL_DIR" fetch --quiet origin 2>/dev/null; then
            BEHIND=$(git -C "$SKILL_DIR" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
            if [[ "$BEHIND" != "0" ]]; then
                echo "⚠  本地 wyyp 落后远端 $BEHIND 个 commit,更新:"
                echo "     git -C $SKILL_DIR pull --ff-only"
            fi
        fi
    fi
else
    if ! command -v git >/dev/null 2>&1; then
        echo "❌ git 未安装,无法继续"
        exit 1
    fi
    echo "⬇  wyyp skill 未安装,clone 到 $SKILL_DIR..."
    mkdir -p "$(dirname "$SKILL_DIR")"
    git clone --depth 1 "$REPO_URL" "$SKILL_DIR"
    echo ""
fi

TEMPLATE_FULL="$SKILL_DIR/$TEMPLATE_REL"
CURSOR_TEMPLATE_FULL="$SKILL_DIR/$CURSOR_TEMPLATE_REL"
CONFIG_TEMPLATE_FULL="$SKILL_DIR/$CONFIG_TEMPLATE_REL"
COMMAND_SRC_FULL="$SKILL_DIR/$COMMAND_SRC_REL"

if [[ ! -f "$TEMPLATE_FULL" ]]; then
    echo "❌ 模板未找到: $TEMPLATE_FULL,安装可能损坏"
    echo "   尝试: rm -rf $SKILL_DIR && bash $0"
    exit 1
fi

# ────────────────────────────────────────────────────────
# Step 2: AGENTS.md
# ────────────────────────────────────────────────────────
if [[ -f "$TARGET_AGENTS" ]]; then
    BACKUP="$TARGET_AGENTS.bak.$(date +%Y%m%d%H%M%S)"
    echo "⚠  $TARGET_AGENTS 已存在,备份为 $BACKUP"
    cp "$TARGET_AGENTS" "$BACKUP"
fi
cp "$TEMPLATE_FULL" "$TARGET_AGENTS"
echo "✓ AGENTS.md 已创建:$(pwd)/AGENTS.md"

# ────────────────────────────────────────────────────────
# Step 3: Cursor 规则
# ────────────────────────────────────────────────────────
if [[ "${NO_CURSOR:-0}" == "1" ]]; then
    echo "⏭  跳过 Cursor 规则(NO_CURSOR=1)"
elif [[ ! -f "$CURSOR_TEMPLATE_FULL" ]]; then
    echo "⚠  Cursor 模板未找到,跳过"
else
    mkdir -p "$TARGET_CURSOR_DIR"
    if [[ -f "$TARGET_CURSOR" ]]; then
        BACKUP="$TARGET_CURSOR.bak.$(date +%Y%m%d%H%M%S)"
        echo "⚠  $TARGET_CURSOR 已存在,备份为 $BACKUP"
        cp "$TARGET_CURSOR" "$BACKUP"
    fi
    cp "$CURSOR_TEMPLATE_FULL" "$TARGET_CURSOR"
    echo "✓ Cursor 规则已创建:$TARGET_CURSOR"
fi

# ────────────────────────────────────────────────────────
# Step 4: Claude Code /wyyp 斜杠命令
# ────────────────────────────────────────────────────────
if [[ "${NO_COMMAND:-0}" == "1" ]]; then
    echo "⏭  跳过 /wyyp 斜杠命令(NO_COMMAND=1)"
elif [[ ! -f "$COMMAND_SRC_FULL" ]]; then
    echo "⚠  /wyyp 命令源文件未找到,跳过"
else
    mkdir -p "$COMMAND_DIR"
    if [[ -f "$TARGET_COMMAND" ]]; then
        BACKUP="$TARGET_COMMAND.bak.$(date +%Y%m%d%H%M%S)"
        echo "⚠  $TARGET_COMMAND 已存在,备份为 $BACKUP"
        cp "$TARGET_COMMAND" "$BACKUP"
    fi
    cp "$COMMAND_SRC_FULL" "$TARGET_COMMAND"
    echo "✓ /wyyp 斜杠命令已安装:$TARGET_COMMAND"
    echo "  在 Claude Code 里输入 /wyyp 即可触发验牌"
fi

# ────────────────────────────────────────────────────────
# Step 5: .wyyp.yml 配置(可选)
# ────────────────────────────────────────────────────────
if [[ "${NO_CONFIG:-0}" == "1" ]]; then
    echo "⏭  跳过 .wyyp.yml 模板(NO_CONFIG=1)"
elif [[ -f "$TARGET_CONFIG" ]]; then
    echo "✓ .wyyp.yml 已存在,不覆盖"
elif [[ ! -f "$CONFIG_TEMPLATE_FULL" ]]; then
    echo "⚠  .wyyp.yml 模板未找到,跳过"
else
    cp "$CONFIG_TEMPLATE_FULL" "$TARGET_CONFIG"
    echo "✓ .wyyp.yml 模板已创建(可按需编辑)"
fi

# ────────────────────────────────────────────────────────
# 提示 Claude Code 项目级安装
# ────────────────────────────────────────────────────────
if [[ -d ".claude" && ! -d ".claude/skills/wyyp" ]]; then
    echo ""
    echo "💡 检测到 .claude/,如需项目级安装:"
    echo "     SKILL_DIR=.claude/skills/wyyp bash $0"
fi

echo ""
echo "───────────────────────────────────────────────"
echo "下一步:"
echo "  1. 在 Claude Code 里输入 /wyyp 开始验牌"
echo "  2. 或编辑 .wyyp.yml 调整默认策略"
echo "  3. 提交到 git:"
echo "       git add AGENTS.md .cursor/rules/wyyp.mdc .wyyp.yml"
echo "       git commit -m 'chore: add wyyp QA rules'"
echo "───────────────────────────────────────────────"
