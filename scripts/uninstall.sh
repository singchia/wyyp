#!/usr/bin/env bash
# uninstall.sh — 移除 wyyp skill 和当前项目里的 wyyp 落盘文件
#
# 用法(在你的项目根目录运行):
#     bash <(curl -sSL https://raw.githubusercontent.com/singchia/wyyp/main/scripts/uninstall.sh)
#
# 或本地(已 clone):
#     ~/.claude/skills/wyyp/scripts/uninstall.sh
#
# 默认移除:
#   - 当前目录的 ./AGENTS.md(如果是 wyyp 生成的,先备份再删)
#   - 当前目录的 ./.cursor/rules/wyyp.mdc
#   - 当前目录的 ./.wyyp.yml(如果是模板未改过)
#   - ~/.claude/commands/wyyp.md
# 不会自动删 ~/.claude/skills/wyyp/,除非 KEEP_SKILL=0
#
# 环境变量:
#   KEEP_SKILL=0        一并删 ~/.claude/skills/wyyp/(默认保留)
#   KEEP_COMMAND=1      保留 ~/.claude/commands/wyyp.md(默认删)
#   KEEP_CONFIG=1       保留当前目录的 .wyyp.yml(默认删模板)
#   SKILL_DIR=...       自定义 skill 目录
#   COMMAND_DIR=...     自定义 commands 目录

set -euo pipefail

SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/wyyp}"
COMMAND_DIR="${COMMAND_DIR:-$HOME/.claude/commands}"
KEEP_SKILL="${KEEP_SKILL:-1}"
KEEP_COMMAND="${KEEP_COMMAND:-0}"
KEEP_CONFIG="${KEEP_CONFIG:-0}"
TARGET_AGENTS="./AGENTS.md"
TARGET_CURSOR="./.cursor/rules/wyyp.mdc"
TARGET_CONFIG="./.wyyp.yml"
TARGET_COMMAND="$COMMAND_DIR/wyyp.md"

echo "🧹 wyyp(我要验牌)卸载"
echo ""

# ────────────────────────────────────────────────────────
# Step 1: 项目根 AGENTS.md
# ────────────────────────────────────────────────────────
if [[ -f "${TARGET_AGENTS}" ]]; then
    if grep -q "wyyp" "${TARGET_AGENTS}" 2>/dev/null; then
        BACKUP="${TARGET_AGENTS}.bak.$(date +%Y%m%d%H%M%S)"
        cp "${TARGET_AGENTS}" "${BACKUP}"
        rm "${TARGET_AGENTS}"
        echo "✓ 已删除 ${TARGET_AGENTS}(备份为 ${BACKUP})"
    else
        echo "⏭  ${TARGET_AGENTS} 不像是 wyyp 生成的(不含 'wyyp' 字样),保留不动"
    fi
else
    echo "⏭  ${TARGET_AGENTS} 不存在,跳过"
fi

# ────────────────────────────────────────────────────────
# Step 2: Cursor 规则
# ────────────────────────────────────────────────────────
if [[ -f "${TARGET_CURSOR}" ]]; then
    rm "${TARGET_CURSOR}"
    echo "✓ 已删除 ${TARGET_CURSOR}"
    if [[ -d "./.cursor/rules" ]] && [[ -z "$(ls -A ./.cursor/rules)" ]]; then
        rmdir ./.cursor/rules
        if [[ -d "./.cursor" ]] && [[ -z "$(ls -A ./.cursor)" ]]; then
            rmdir ./.cursor
        fi
    fi
else
    echo "⏭  ${TARGET_CURSOR} 不存在,跳过"
fi

# ────────────────────────────────────────────────────────
# Step 3: 项目级 .wyyp.yml(只删未改过的模板)
# ────────────────────────────────────────────────────────
if [[ -f "${TARGET_CONFIG}" ]]; then
    if [[ "${KEEP_CONFIG}" == "1" ]]; then
        echo "⏭  ${TARGET_CONFIG} 保留(KEEP_CONFIG=1)"
    elif [[ -f "${SKILL_DIR}/docs/templates/wyyp-config-template.yml" ]] \
         && diff -q "${TARGET_CONFIG}" "${SKILL_DIR}/docs/templates/wyyp-config-template.yml" >/dev/null 2>&1; then
        rm "${TARGET_CONFIG}"
        echo "✓ 已删除 ${TARGET_CONFIG}(和模板完全一致,未自定义)"
    else
        echo "⏭  ${TARGET_CONFIG} 已被修改,保留(如要删加 KEEP_CONFIG=0 ... rm 手工删)"
    fi
else
    echo "⏭  ${TARGET_CONFIG} 不存在,跳过"
fi

# ────────────────────────────────────────────────────────
# Step 4: /wyyp 斜杠命令(legacy:0.4.0 之前才会有这个文件)
# ────────────────────────────────────────────────────────
# 0.4.0 起不再装独立 slash command,但老版本装过的用户升级时这里可能残留
if [[ -f "${TARGET_COMMAND}" ]]; then
    if [[ "${KEEP_COMMAND}" == "1" ]]; then
        echo "⏭  ${TARGET_COMMAND} 保留(KEEP_COMMAND=1)"
    else
        rm "${TARGET_COMMAND}"
        echo "✓ 已删除 legacy ${TARGET_COMMAND}(0.4.0+ 不再需要)"
    fi
else
    echo "⏭  ${TARGET_COMMAND} 不存在,跳过(0.4.0+ 本来就不装)"
fi

# ────────────────────────────────────────────────────────
# Step 5: 全局 skill 目录
# ────────────────────────────────────────────────────────
if [[ "${KEEP_SKILL}" == "0" ]]; then
    if [[ -d "${SKILL_DIR}" ]]; then
        rm -rf "${SKILL_DIR}"
        echo "✓ 已删除 ${SKILL_DIR}"
    else
        echo "⏭  ${SKILL_DIR} 不存在,跳过"
    fi
else
    if [[ -d "${SKILL_DIR}" ]]; then
        echo "ℹ  保留 ${SKILL_DIR}(其他项目可能仍在用)"
        echo "   如要一并删除:KEEP_SKILL=0 bash \$0"
    fi
fi

echo ""
echo "✅ 卸载完成"
