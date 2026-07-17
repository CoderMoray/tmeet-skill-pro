#!/bin/bash
# test-transfer-invitees.sh — transfer-invitees.sh 单元测试

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XFER="$SCRIPT_DIR/transfer-invitees.sh"
MOCK="$SCRIPT_DIR/test-transfer-invitees-data.json"
PASS=0
FAIL=0

run_test() {
    local name="$1"
    local expect="$2"

    echo -n "TEST: $name ... "

    OUTPUT=$(bash "$XFER" source_meeting target_meeting --data-file "$MOCK" 2>&1) || true

    if echo "$OUTPUT" | grep -q "$expect"; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        echo "  Expected to contain: $expect"
        echo "  Got:"
        echo "$OUTPUT" | head -5
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
#  Test 1: basic transfer with invitees
# ============================================================
run_test "extract and transfer invitees" \
  "已完成转移（5 人）"

# ============================================================
#  Test 2: show invitee count
# ============================================================
run_test "show invitee count" \
  "提取到 5 位受邀人"

# ============================================================
#  Test 3: mock response shown
# ============================================================
run_test "mock invitees-add response" \
  '"ok": true'

# ============================================================
#  Test 4: missing source ID exits with error
# ============================================================
echo -n "TEST: missing params error ... "
OUTPUT=$(bash "$XFER" 2>&1) || rc=$?
if echo "$OUTPUT" | grep -q "用法"; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    echo "  Expected usage message"
    FAIL=$((FAIL + 1))
fi

# ============================================================
#  Test 5: no invitees in source
# ============================================================
echo -n "TEST: empty invitees warning ... "
TMP_MOCK=$(mktemp)
echo '{"invitees": [], "invitees_add": {"response": {}}}' > "$TMP_MOCK"
OUTPUT=$(bash "$XFER" src dst --data-file "$TMP_MOCK" 2>&1) || true
rm -f "$TMP_MOCK"
if echo "$OUTPUT" | grep -q "没有受邀人"; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    echo "  Got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
#  Test 6: invitees-add error handling
# ============================================================
echo -n "TEST: invitees-add error ... "
TMP_MOCK=$(mktemp)
echo '{"invitees": [{"open_id": "u1"}], "invitees_add": {"error": "permission denied"}}' > "$TMP_MOCK"
OUTPUT=$(bash "$XFER" src dst --data-file "$TMP_MOCK" 2>&1) || true
rm -f "$TMP_MOCK"
if echo "$OUTPUT" | grep -q "添加失败"; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    echo "  Got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
#  Test 7: single invitee
# ============================================================
echo -n "TEST: single invitee ... "
TMP_MOCK=$(mktemp)
echo '{"invitees": [{"open_id": "only_one"}], "invitees_add": {"response": {"ok": true}}}' > "$TMP_MOCK"
OUTPUT=$(bash "$XFER" src dst --data-file "$TMP_MOCK" 2>&1) || true
rm -f "$TMP_MOCK"
if echo "$OUTPUT" | grep -q "已完成转移（1 人）"; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    echo "  Got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
#  Test 8: userid fallback
# ============================================================
echo -n "TEST: userid fallback ... "
TMP_MOCK=$(mktemp)
echo '{"invitees": [{"userid": "legacy_001"}, {"open_id": "modern_001"}], "invitees_add": {"response": {"ok": true}}}' > "$TMP_MOCK"
OUTPUT=$(bash "$XFER" src dst --data-file "$TMP_MOCK" 2>&1) || true
rm -f "$TMP_MOCK"
if echo "$OUTPUT" | grep -q "已完成转移（2 人）"; then
    echo "PASS"
    PASS=$((PASS + 1))
else
    echo "FAIL"
    echo "  Got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
