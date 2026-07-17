#!/bin/bash
# test-check-conflict.sh — 冲突检测单元测试
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="$SCRIPT_DIR/check-conflict.sh"
PASS=0; FAIL=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; YELLOW='\033[0;33m'

run_test() {
    local name="$1" input="$2" mock="$3" expected="$4"

    local tmpdir=$(mktemp -d)
    echo "$mock" > "$tmpdir/mock.json"
    echo "$expected" > "$tmpdir/expected.json"

    local actual
    if actual=$(echo "$input" | "$CHECK" --data-file "$tmpdir/mock.json" 2>/dev/null); then
        echo "$actual" > "$tmpdir/actual.json"
    else
        echo "SCRIPT_ERROR" > "$tmpdir/actual.json"
    fi

    if python3 "$COMPARE_PY" "$tmpdir/actual.json" "$tmpdir/expected.json" 2>/dev/null; then
        echo -e "  ${GREEN}PASS${NC} $name"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC} $name"
        echo -e "    ${YELLOW}expected:${NC} $expected"
        echo -e "    ${YELLOW}actual:${NC}   $actual"
        ((FAIL++))
    fi
    rm -rf "$tmpdir"
}

# 创建一个简单的 Python 比较脚本到临时位置
# (不能用 heredoc，因为会和外层 heredoc 冲突)
COMPARE_PY=$(mktemp)
cat > "$COMPARE_PY" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f: a = json.load(f)
with open(sys.argv[2]) as f: e = json.load(f)
assert a == e, f"mismatch"
PYEOF

echo "=========================================="
echo "  check-conflict.sh 单元测试"
echo "=========================================="

echo ""; echo "[1] 无冲突"
run_test "无已有会议" \
  '[{"date":"2026-07-20","start":"09:00","end":"09:15","subject":"站会"}]' \
  '{}' \
  '[{"date":"2026-07-20","start":"09:00","end":"09:15","subject":"站会","conflict":false}]'

run_test "时段不重叠" \
  '[{"date":"2026-07-20","start":"14:00","end":"15:00","subject":"面试"}]' \
  '{"2026-07-20":[{"subject":"站会","start_time":"2026-07-20T09:00:00+08:00","end_time":"2026-07-20T09:15:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"14:00","end":"15:00","subject":"面试","conflict":false}]'

echo ""; echo "[2] 冲突场景"
run_test "完全重叠" \
  '[{"date":"2026-07-20","start":"09:00","end":"10:00","subject":"站会"}]' \
  '{"2026-07-20":[{"subject":"需求评审","start_time":"2026-07-20T09:00:00+08:00","end_time":"2026-07-20T10:00:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"09:00","end":"10:00","subject":"站会","conflict":true,"conflict_with":["需求评审"]}]'

run_test "部分重叠(新会议后半段覆盖已有)" \
  '[{"date":"2026-07-20","start":"09:30","end":"10:30","subject":"站会"}]' \
  '{"2026-07-20":[{"subject":"需求评审","start_time":"2026-07-20T09:00:00+08:00","end_time":"2026-07-20T10:00:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"09:30","end":"10:30","subject":"站会","conflict":true,"conflict_with":["需求评审"]}]'

run_test "部分重叠(新会议前半段覆盖已有)" \
  '[{"date":"2026-07-20","start":"08:30","end":"09:30","subject":"站会"}]' \
  '{"2026-07-20":[{"subject":"需求评审","start_time":"2026-07-20T09:00:00+08:00","end_time":"2026-07-20T10:00:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"08:30","end":"09:30","subject":"站会","conflict":true,"conflict_with":["需求评审"]}]'

run_test "新会议包含已有会议" \
  '[{"date":"2026-07-20","start":"08:00","end":"12:00","subject":"大会"}]' \
  '{"2026-07-20":[{"subject":"需求评审","start_time":"2026-07-20T09:00:00+08:00","end_time":"2026-07-20T10:00:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"08:00","end":"12:00","subject":"大会","conflict":true,"conflict_with":["需求评审"]}]'

echo ""; echo "[3] 边界场景"
run_test "紧挨不冲突(已有9:00结束,新9:00开始)" \
  '[{"date":"2026-07-20","start":"09:00","end":"09:30","subject":"站会"}]' \
  '{"2026-07-20":[{"subject":"晨会","start_time":"2026-07-20T08:30:00+08:00","end_time":"2026-07-20T09:00:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"09:00","end":"09:30","subject":"站会","conflict":false}]'

run_test "紧挨不冲突(新10:00结束,已有10:00开始)" \
  '[{"date":"2026-07-20","start":"09:00","end":"10:00","subject":"站会"}]' \
  '{"2026-07-20":[{"subject":"例会","start_time":"2026-07-20T10:00:00+08:00","end_time":"2026-07-20T11:00:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"09:00","end":"10:00","subject":"站会","conflict":false}]'

run_test "同一天一前一后都不冲突" \
  '[{"date":"2026-07-20","start":"08:00","end":"09:00","subject":"准备"},{"date":"2026-07-20","start":"10:00","end":"11:00","subject":"跟进"}]' \
  '{"2026-07-20":[{"subject":"主会","start_time":"2026-07-20T09:00:00+08:00","end_time":"2026-07-20T10:00:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"08:00","end":"09:00","subject":"准备","conflict":false},{"date":"2026-07-20","start":"10:00","end":"11:00","subject":"跟进","conflict":false}]'

echo ""; echo "[4] 多日期"
run_test "三天只有一天冲突" \
  '[{"date":"2026-07-20","start":"09:00","end":"09:30","subject":"站会"},{"date":"2026-07-21","start":"09:00","end":"09:30","subject":"站会"},{"date":"2026-07-22","start":"09:00","end":"09:30","subject":"站会"}]' \
  '{"2026-07-21":[{"subject":"特殊会议","start_time":"2026-07-21T09:00:00+08:00","end_time":"2026-07-21T09:30:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"09:00","end":"09:30","subject":"站会","conflict":false},{"date":"2026-07-21","start":"09:00","end":"09:30","subject":"站会","conflict":true,"conflict_with":["特殊会议"]},{"date":"2026-07-22","start":"09:00","end":"09:30","subject":"站会","conflict":false}]'

echo ""; echo "[5] 一天多冲突"
run_test "同时与两场已有会议重叠" \
  '[{"date":"2026-07-20","start":"09:00","end":"11:00","subject":"站会"}]' \
  '{"2026-07-20":[{"subject":"晨会","start_time":"2026-07-20T09:00:00+08:00","end_time":"2026-07-20T09:30:00+08:00"},{"subject":"周会","start_time":"2026-07-20T10:00:00+08:00","end_time":"2026-07-20T11:00:00+08:00"}]}' \
  '[{"date":"2026-07-20","start":"09:00","end":"11:00","subject":"站会","conflict":true,"conflict_with":["晨会","周会"]}]'

echo ""; echo "[6] 边界输入"
run_test "空数组" '[]' '{}' '[]'
run_test "mock中有日期但无会议" \
  '[{"date":"2026-07-20","start":"10:00","end":"11:00","subject":"站会"}]' \
  '{"2026-07-20":[]}' \
  '[{"date":"2026-07-20","start":"10:00","end":"11:00","subject":"站会","conflict":false}]'

rm -f "$COMPARE_PY"

echo ""
echo "=========================================="
T=$((PASS+FAIL))
if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}全部通过${NC} ($PASS/$T)"
else
    echo -e "  ${RED}$FAIL 失败${NC}, $PASS 通过 ($PASS/$T)"
fi
echo "=========================================="
exit $FAIL
