#!/bin/bash
# transfer-invitees.sh — 从源会议提取受邀人，添加到目标会议
#
# 用法:
#   ./transfer-invitees.sh <源 meeting_id> <目标 meeting_id>
#
#   # 测试模式 — 使用 mock 数据
#   ./transfer-invitees.sh <源 meeting_id> <目标 meeting_id> --data-file /path/to/mock.json
#
# 依赖: tmeet CLI, python3

set -e

# ===== 自动查找 tmeet CLI =====
if command -v tmeet &>/dev/null; then
    TMEET="tmeet"
elif ls ~/.workbuddy/binaries/node/versions/*/bin/tmeet &>/dev/null 2>&1; then
    TMEET=$(ls -d ~/.workbuddy/binaries/node/versions/*/bin/tmeet 2>/dev/null | head -1)
else
    echo "❌ tmeet CLI not found" >&2; exit 1
fi

SOURCE_ID="$1"
TARGET_ID="$2"
DATA_FILE=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --data-file)
            DATA_FILE="$2"; shift 2 ;;
        *)
            shift ;;
    esac
done

if [ -z "$SOURCE_ID" ] || [ -z "$TARGET_ID" ]; then
    echo "用法: $0 <源 meeting_id> <目标 meeting_id>" >&2
    echo "示例: $0 100000000 200000000" >&2
    exit 1
fi

export TMEET SOURCE_ID TARGET_ID DATA_FILE
python3 << 'PYEOF'
import json
import subprocess
import sys
import os

TMEET_CMD = os.environ.get("TMEET", "tmeet")
SOURCE_ID = os.environ.get("SOURCE_ID", "")
TARGET_ID = os.environ.get("TARGET_ID", "")
DATA_FILE = os.environ.get("DATA_FILE", "")

MOCK = None
if DATA_FILE:
    with open(DATA_FILE) as f:
        MOCK = json.load(f)

# ===== 1. 分页获取源会议所有受邀人 =====

ALL_IDS = []

if MOCK:
    ml = MOCK.get("invitees", [])
    for invitee in ml:
        oid = invitee.get("open_id", invitee.get("userid", ""))
        if oid:
            ALL_IDS.append(oid)
else:
    ALL_IDS = []
    PAGE_TOKEN = ""

    while True:
        args = [
            "meeting", "invitees-list",
            "--meeting-id", SOURCE_ID,
            "--compact", "--format", "json"
        ]
        if PAGE_TOKEN:
            args += ["--page-token", PAGE_TOKEN]

        result = subprocess.run(
            [TMEET_CMD] + args,
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            print(f"❌ invitees-list 失败: {result.stderr.strip() or result.stdout.strip()}", file=sys.stderr)
            sys.exit(1)

        data = json.loads(result.stdout).get("data", {})
        invitees = data.get("invitees", data.get("invitee_list", data.get("items", [])))
        for i in invitees:
            oid = i.get("open_id", i.get("userid", ""))
            if oid:
                ALL_IDS.append(oid)

        PAGE_TOKEN = data.get("next_page_token", "")
        if not PAGE_TOKEN:
            break

if not ALL_IDS:
    print("⚠️  源会议没有受邀人")
    sys.exit(0)

ALL_IDS_STR = ",".join(ALL_IDS)
INVITEE_COUNT = len(ALL_IDS)
print(f"👥 提取到 {INVITEE_COUNT} 位受邀人，正在添加到目标会议...")

# ===== 2. 添加到目标会议 =====

if MOCK:
    result = MOCK.get("invitees_add", {})
    if result.get("error"):
        print(f"❌ 添加失败: {result['error']}")
        sys.exit(1)
    print(json.dumps(result.get("response", {}), ensure_ascii=False))
else:
    result = subprocess.run(
        [TMEET_CMD, "meeting", "invitees-add",
         "--meeting-id", TARGET_ID,
         "--invitees", ALL_IDS_STR],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        print(f"❌ invitees-add 失败: {result.stderr.strip() or result.stdout.strip()}", file=sys.stderr)
        sys.exit(1)
    print(result.stdout.strip())

print()
print(f"✅ 已完成转移（{INVITEE_COUNT} 人）")
PYEOF
