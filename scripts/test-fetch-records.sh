#!/bin/bash
# test-fetch-records.sh — fetch-records.sh 单元测试
# 使用 --data-file mock 模式，零 CLI 依赖

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FETCH="$SCRIPT_DIR/fetch-records.sh"
MOCK="$SCRIPT_DIR/test-fetch-records-data.json"
PASS=0
FAIL=0

run_test() {
    local name="$1"
    local input="$2"
    local expect_contains="$3"
    local expect_not="$4"

    echo -n "TEST: $name ... "

    OUTPUT=$(echo "$input" | bash "$FETCH" --data-file "$MOCK" 2>&1) || true

    if [ -n "$expect_contains" ]; then
        if echo "$OUTPUT" | grep -q "$expect_contains"; then
            :
        else
            echo "FAIL"
            echo "  Expected to contain: $expect_contains"
            echo "  Got (first 300 chars):"
            echo "$OUTPUT" | head -10
            FAIL=$((FAIL + 1))
            return
        fi
    fi

    if [ -n "$expect_not" ]; then
        if echo "$OUTPUT" | grep -q "$expect_not"; then
            echo "FAIL"
            echo "  Expected NOT to contain: $expect_not"
            echo "  Got (first 300 chars):"
            echo "$OUTPUT" | head -10
            FAIL=$((FAIL + 1))
            return
        fi
    fi

    echo "PASS"
    PASS=$((PASS + 1))
}

# ============================================================
#  Test 1: transcript mode with keyword filter
# ============================================================
run_test "keyword filter '面试'" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"面试","content_type":"transcript"}' \
  "前端面试" \
  "产品周会"

# ============================================================
#  Test 2: max_meetings cap (2 of 4)
# ============================================================
run_test "max_meetings=2" \
  '{"start":"2026-07-01","end":"2026-07-17","max_meetings":2,"content_type":"transcript"}' \
  "_共找到 4 场会议，匹配 2 场_" \
  ""

# ============================================================
#  Test 3: transcript mode shows metadata
# ============================================================
run_test "transcript shows meeting_code" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"面试","content_type":"transcript"}' \
  "444-555-666" \
  ""

# ============================================================
#  Test 4: transcript shows speakers
# ============================================================
run_test "transcript shows speaker list" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"面试","content_type":"transcript"}' \
  "面试官、张三" \
  ""

# ============================================================
#  Test 5: no recording meeting shows properly
# ============================================================
run_test "no recording meeting" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"后端面试","content_type":"transcript"}' \
  "无录制" \
  ""

# ============================================================
#  Test 6: recording not ready (转码中)
# ============================================================
run_test "recording in transcode state" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"策略会","content_type":"transcript"}' \
  "录制未就绪" \
  "转写内容："

# ============================================================
#  Test 7: participant no_permission
# ============================================================
run_test "participant no_permission" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"面试","content_type":"transcript"}' \
  "无法获取（仅会议发起人及主持人/联席主持人可获取）" \
  ""

# ============================================================
#  Test 8: participant OK (m1 has participants in mock)
# ============================================================
run_test "participant list when available" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"产品周会","content_type":"transcript"}' \
  "张经理、李工、小王" \
  ""

# ============================================================
#  Test 9: input validation - start > end
# ============================================================
run_test "validation: start after end" \
  '{"start":"2026-07-20","end":"2026-07-01","content_type":"transcript"}' \
  "start (2026-07-20) 晚于 end (2026-07-01)" \
  ""

# ============================================================
#  Test 10: minutes mode
# ============================================================
run_test "minutes mode" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"产品周会","content_type":"minutes"}' \
  "会议摘要" \
  ""

# ============================================================
#  Test 11: minutes mode speaker extraction
# ============================================================
run_test "minutes mode extracts speakers" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"产品周会","content_type":"minutes"}' \
  "张经理、李工、小王（3 人）" \
  ""

# ============================================================
#  Test 12: no matching meetings
# ============================================================
run_test "no matching meetings" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"团建","content_type":"transcript"}' \
  "没有匹配的会议" \
  ""

# ============================================================
#  Test 13: no keyword, all meetings
# ============================================================
run_test "no keyword returns all" \
  '{"start":"2026-07-01","end":"2026-07-17","max_meetings":10,"content_type":"transcript"}' \
  "_共处理 4 场会议_" \
  ""

# ============================================================
#  Test 14: document header
# ============================================================
run_test "document header with reference_date" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"面试","content_type":"transcript","reference_date":"2026-07-17"}' \
  "参考日期：2026-07-17" \
  ""

# ============================================================
#  Test 15: document header without reference_date
# ============================================================
run_test "document header without reference_date" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"面试","content_type":"transcript"}' \
  "录制内容汇总" \
  "参考日期"

# ============================================================
#  Test 16: content_type validation
# ============================================================
run_test "validation: invalid content_type" \
  '{"start":"2026-07-01","end":"2026-07-17","content_type":"video"}' \
  "content_type 必须为 transcript 或 minutes" \
  ""

# ============================================================
#  Test 17: search mode - activates with search_text
# ============================================================
run_test "search mode activates" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"产品周会","content_type":"transcript","search_text":"延期"}' \
  "搜索「延期」" \
  ""

# ============================================================
#  Test 18: search mode - hit count shown
# ============================================================
run_test "search mode shows hit count" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"产品周会","content_type":"transcript","search_text":"延期"}' \
  "命中 5 处" \
  ""

# ============================================================
#  Test 19: search mode - interval merge info
# ============================================================
run_test "search mode shows interval merge" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"产品周会","content_type":"transcript","search_text":"延期"}' \
  "合并" \
  ""

# ============================================================
#  Test 20: search mode - content label
# ============================================================
run_test "search mode shows 转写节选" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"产品周会","content_type":"transcript","search_text":"延期"}' \
  "转写节选" \
  "转写内容"

# ============================================================
#  Test 21: search mode - search text shown in header
# ============================================================
run_test "search mode header shows search text" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"前端面试","content_type":"transcript","search_text":"高并发"}' \
  "搜索「高并发」" \
  ""

# ============================================================
#  Test 22: search mode - speakers still extracted
# ============================================================
run_test "search mode extracts speakers" \
  '{"start":"2026-07-01","end":"2026-07-17","keyword":"产品周会","content_type":"transcript","search_text":"延期"}' \
  "发言人：" \
  ""

# ============================================================
#  Summary
# ============================================================
echo ""
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
