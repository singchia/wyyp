#!/usr/bin/env bash
# build-skill.sh — 把 wyyp 打包成 .skill 文件(agent skills zip 格式)
#
# 用法:
#     scripts/build-skill.sh              # 输出到 ./dist/wyyp.skill
#     scripts/build-skill.sh /path/to/out # 指定目录
#
# 依赖:bash + python3 + pyyaml + zip

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR_RAW="${1:-$REPO_ROOT/dist}"
mkdir -p "$OUT_DIR_RAW"
OUT_DIR="$(cd "$OUT_DIR_RAW" && pwd)"
STAGING_PARENT="$(mktemp -d)"
STAGING_DIR="$STAGING_PARENT/wyyp"

cleanup() { rm -rf "$STAGING_PARENT"; }
trap cleanup EXIT

echo "🔍 Validating SKILL.md..."
python3 "$REPO_ROOT/scripts/validate-skill.py" "$REPO_ROOT"
echo ""

echo "📦 Staging skill files..."
mkdir -p "$STAGING_DIR" "$STAGING_DIR/scripts"
cp "$REPO_ROOT/SKILL.md"   "$STAGING_DIR/"
cp "$REPO_ROOT/AGENTS.md"  "$STAGING_DIR/"
cp "$REPO_ROOT/LICENSE"    "$STAGING_DIR/"
cp -r "$REPO_ROOT/spec"    "$STAGING_DIR/"
cp -r "$REPO_ROOT/docs"    "$STAGING_DIR/"
cp -r "$REPO_ROOT/commands" "$STAGING_DIR/"
cp "$REPO_ROOT/scripts/install.sh" "$STAGING_DIR/scripts/"
cp "$REPO_ROOT/scripts/uninstall.sh" "$STAGING_DIR/scripts/"
chmod +x "$STAGING_DIR/scripts/install.sh" "$STAGING_DIR/scripts/uninstall.sh"
echo ""

echo "🗜  Packaging..."
(cd "$STAGING_PARENT" && zip -r -q "$OUT_DIR/wyyp.skill" wyyp/)

echo ""
echo "✅ Built: $OUT_DIR/wyyp.skill"
ls -lh "$OUT_DIR/wyyp.skill"
echo ""
echo "📋 Contents (last 10):"
unzip -l "$OUT_DIR/wyyp.skill" | tail -10
