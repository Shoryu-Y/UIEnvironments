#!/bin/bash
#
# Native trait bridge 有効/無効の両モードでテストを実行するスクリプト
#
# 使用方法:
#   ./scripts/test_both_modes.sh [SCHEME_NAME ...]
#
# 例:
#   # デフォルト(UIEnvironments)で実行
#   ./scripts/test_both_modes.sh
#
#   # 複数スキームを指定して実行
#   ./scripts/test_both_modes.sh UIEnvironments SchemeA
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_SCRIPT="$SCRIPT_DIR/test.sh"

if [ ! -x "$TEST_SCRIPT" ]; then
    echo "エラー: テストスクリプトが見つからないか実行不可です: $TEST_SCRIPT"
    exit 1
fi

if [ $# -eq 0 ]; then
    SCHEMES=("UIEnvironments")
else
    SCHEMES=("$@")
fi

FAILED_MODES=()

run_mode() {
    local mode_name="$1"
    shift

    echo ""
    echo "========================================"
    echo "モード: $mode_name"
    echo "========================================"

    if "$@"; then
        echo "✅ $mode_name: 成功"
    else
        echo "❌ $mode_name: 失敗"
        FAILED_MODES+=("$mode_name")
    fi
}

run_mode \
    "Native Trait Bridge Enabled" \
    env -u UIENVIRONMENTS_DISABLE_NATIVE_TRAIT_BRIDGE \
    "$TEST_SCRIPT" "${SCHEMES[@]}"

# xcodebuild は起動シェルの環境変数を simulator 上のテストプロセスへ渡さない。
# TEST_RUNNER_ プレフィックスを付けた変数のみ、プレフィックスを剥がして
# テストランナープロセスへ転送される。これを付けないと fallback モードは
# simulator 内に届かず、実際には bridge モードで実行されてしまう。
run_mode \
    "Fallback (UIENVIRONMENTS_DISABLE_NATIVE_TRAIT_BRIDGE=1)" \
    env UIENVIRONMENTS_DISABLE_NATIVE_TRAIT_BRIDGE=1 \
    TEST_RUNNER_UIENVIRONMENTS_DISABLE_NATIVE_TRAIT_BRIDGE=1 \
    "$TEST_SCRIPT" "${SCHEMES[@]}"

if [ ${#FAILED_MODES[@]} -gt 0 ]; then
    echo ""
    echo "========================================"
    echo "実行結果: 失敗"
    echo "========================================"
    for mode in "${FAILED_MODES[@]}"; do
        echo "  ❌ $mode"
    done
    exit 1
fi

echo ""
echo "========================================"
echo "実行結果: 成功"
echo "========================================"
echo "両モードのテストが成功しました。"
