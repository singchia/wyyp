#!/usr/bin/env bash
# install.sh — 在你的项目根目录运行,安装并激活 wyyp
#
# 它做几件事:
#   1. 安装 wyyp skill 到 ~/.claude/skills/wyyp/
#   2. 在当前目录创建 AGENTS.md(Codex / Cline / Cursor 等通用 agent 入口)
#   3. 检测 Cursor,自动落 .cursor/rules/wyyp.mdc
#   4. 可选落 .wyyp.yml 模板
#   5. 清理旧版(< 0.4.0)留下的 ~/.claude/commands/wyyp.md(避免 /wyyp 菜单重复)
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
#     NO_CURSOR=1 NO_CONFIG=1 bash <(curl -sSL .../install.sh)

set -euo pipefail

REPO_URL="https://github.com/singchia/wyyp.git"
SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/wyyp}"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
CODEX_SKILL_LINK="$CODEX_SKILLS_DIR/wyyp"
LEGACY_COMMAND="${HOME}/.claude/commands/wyyp.md"
TEMPLATE_REL="docs/templates/project-agents-template.md"
CURSOR_TEMPLATE_REL="docs/templates/cursor-rule-template.mdc"
CONFIG_TEMPLATE_REL="docs/templates/wyyp-config-template.yml"
TARGET_AGENTS="./AGENTS.md"
TARGET_CURSOR_DIR="./.cursor/rules"
TARGET_CURSOR="$TARGET_CURSOR_DIR/wyyp.mdc"
TARGET_CONFIG="./.wyyp.yml"

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
# Step 4: .wyyp.yml 配置(可选)
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
# Step 5: 清理旧版(< 0.4.0)残留的 slash command 文件
# ────────────────────────────────────────────────────────
# 0.4.0 改成 skill-only:/wyyp 直接触发 skill,不再需要独立的 commands/wyyp.md
# 老用户升级时把 legacy command 文件清掉,否则 Claude Code 菜单会出现两个 /wyyp
if [[ -f "$LEGACY_COMMAND" ]]; then
    rm "$LEGACY_COMMAND"
    echo "🧹 清理旧版残留:$LEGACY_COMMAND(0.4.0+ 不再需要)"
fi

# ────────────────────────────────────────────────────────
# Step 6: 检测 Codex,symlink 到 ~/.codex/skills/wyyp
# ────────────────────────────────────────────────────────
# Codex(OpenAI Codex CLI)用同样的 SKILL.md 协议,只是读自己的 skills 目录
# 通过 symlink 一份 skill 两处生效,update 时不需要重复 sync
if [[ "${NO_CODEX:-0}" == "1" ]]; then
    echo "⏭  跳过 Codex 安装(NO_CODEX=1)"
elif [[ -d "$(dirname "$CODEX_SKILLS_DIR")" ]]; then
    mkdir -p "$CODEX_SKILLS_DIR"
    if [[ -L "$CODEX_SKILL_LINK" ]]; then
        # 已是符号链接,确认指向正确
        CURRENT_TARGET="$(readlink "$CODEX_SKILL_LINK")"
        if [[ "$CURRENT_TARGET" == "$SKILL_DIR" ]]; then
            echo "✓ Codex skill 已就位:$CODEX_SKILL_LINK -> $SKILL_DIR"
        else
            rm "$CODEX_SKILL_LINK"
            ln -s "$SKILL_DIR" "$CODEX_SKILL_LINK"
            echo "✓ Codex skill 链接已更新:$CODEX_SKILL_LINK -> $SKILL_DIR"
        fi
    elif [[ -e "$CODEX_SKILL_LINK" ]]; then
        echo "⚠  $CODEX_SKILL_LINK 已存在但不是符号链接,跳过。如要换成 link:"
        echo "     rm -rf '$CODEX_SKILL_LINK' && ln -s '$SKILL_DIR' '$CODEX_SKILL_LINK'"
    else
        ln -s "$SKILL_DIR" "$CODEX_SKILL_LINK"
        echo "✓ Codex skill 已安装(symlink):$CODEX_SKILL_LINK -> $SKILL_DIR"
        echo "  重启 Codex 后,skill 列表里会出现 wyyp(个人)"
    fi
else
    echo "⏭  未检测到 Codex($(dirname "$CODEX_SKILLS_DIR") 不存在),跳过"
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
echo "     (/wyyp 会直接触发 wyyp skill,不需要额外命令文件)"
echo "  2. 或编辑 .wyyp.yml 调整默认策略"
echo "  3. 提交到 git:"
echo "       git add AGENTS.md .cursor/rules/wyyp.mdc .wyyp.yml"
echo "       git commit -m 'chore: add wyyp QA rules'"
echo "───────────────────────────────────────────────"
