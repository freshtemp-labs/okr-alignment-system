#!/bin/bash
# ============================================================
# run-tests.sh — OKR Alignment System 测试运行脚本
# ============================================================
#
# 前置条件:
#   - macOS 14+ (Sonoma)
#   - Xcode 15+ 已安装 (包含 XCTest 框架)
#   - xcode-select 已指向 Xcode.app:
#       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#
# 注意: 如果只安装了 Command Line Tools (无 Xcode)，
#       swift test 会报 "no such module 'XCTest'" 错误，
#       因为 CLT 不包含 XCTest 框架。
#
# 用法:
#   ./run-tests.sh          # 运行全部测试
#   ./run-tests.sh --build  # 仅编译，不运行测试
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/project/OKRAlignment"

# ── 检查环境 ──────────────────────────────────────────────

check_xcode() {
    if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
        echo "⚠️  当前 xcode-select 指向: $(xcode-select -p)"
        echo "   swift test 需要 Xcode.app 中的 XCTest 框架。"
        echo ""
        echo "   请先运行:"
        echo "     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        echo ""
        echo "   或者在 Xcode 中直接运行测试 (⌘U)。"
        echo ""
        read -p "是否继续尝试? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# ── 运行 ──────────────────────────────────────────────────

cd "$PACKAGE_DIR"

echo "📦 项目: OKRAlignment"
echo "📁 路径: $PACKAGE_DIR"
echo "🔧 Swift: $(swift --version 2>&1 | head -1)"
echo ""

if [[ "${1:-}" == "--build" ]]; then
    echo "🔨 编译中..."
    swift build
    echo ""
    echo "✅ 编译成功!"
    exit 0
fi

check_xcode

echo "🧪 运行测试..."
echo "──────────────────────────────────────────"
swift test 2>&1
EXIT_CODE=$?
echo "──────────────────────────────────────────"

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ 所有测试通过!"
else
    echo "❌ 测试失败 (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE
