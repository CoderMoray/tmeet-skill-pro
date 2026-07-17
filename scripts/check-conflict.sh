#!/bin/bash
# check-conflict.sh — 批量会议时间冲突检测
#
# 用法:
#   # 生产模式 — 调真实 tmeet CLI
#   echo '<schedule_json>' | ./check-conflict.sh
#
#   # 测试模式 — 使用 mock 数据
#   echo '<schedule_json>' | ./check-conflict.sh --data-file /path/to/mock.json
#
# 输入(stdin): JSON 数组，每个元素 {date, start, end, subject}
# 输出:         JSON 数组，每个元素增加 conflict 标记
#
# 依赖: tmeet CLI（生产模式）, python3（必须）
#
# 设计原则:
#   - 只做确定性计算（时间交集判断），不做语义理解
#   - 按日期分组查询，减少 API 调用次数
#   - 输出纯 JSON，方便 AI 解析

set -e

# ===== 自动查找 tmeet CLI =====
if command -v tmeet &>/dev/null; then
    TMEET="tmeet"
elif [ -x ~/.workbuddy/binaries/node/versions/*/bin/tmeet ]; then
    TMEET=$(ls -d ~/.workbuddy/binaries/node/versions/*/bin/tmeet 2>/dev/null | head -1)
else
    TMEET="tmeet"  # fallback，subprocess 会捕获 FileNotFoundError
fi

DATA_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --data-file)
            DATA_FILE="$2"; shift 2 ;;
        *)
            shift ;;
    esac
done

# ===== 读取输入 =====
INPUT=$(cat)

if [ -z "$INPUT" ]; then
    echo '{"error": "no input provided, expect JSON array via stdin"}' >&2
    exit 1
fi

# ===== 传递参数给 Python =====
export DATA_FILE
export TMEET
export INPUT
python3 << 'PYEOF'
import json
import subprocess
import sys
import os
from datetime import datetime

TIMEZONE = "+08:00"
DATA_FILE = os.environ.get("DATA_FILE", "")
TMEET_CMD = os.environ.get("TMEET", "tmeet")
INPUT_JSON = os.environ.get("INPUT", "")

def parse_time(date_str, time_str):
    """将 date + HH:MM 转为 datetime"""
    return datetime.fromisoformat(f"{date_str}T{time_str}:00{TIMEZONE}")

def parse_meeting_time(time_str):
    """解析时间字符串，兼容多种格式"""
    if not time_str:
        return None
    for fmt in [
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M%z",
        "%Y-%m-%d %H:%M:%S",
    ]:
        try:
            return datetime.strptime(time_str, fmt)
        except ValueError:
            continue
    return None

def time_overlap(a_start, a_end, b_start, b_end):
    """两个时间段 [a_start, a_end) 和 [b_start, b_end) 是否重叠"""
    return a_start < b_end and b_start < a_end

def load_mock_meetings(mock_file):
    """从 mock 文件加载会议数据。格式:
    {
      "2026-07-20": [
        {"subject": "...", "start_time": "2026-07-20T09:00:00+08:00", "end_time": "2026-07-20T10:00:00+08:00"}
      ]
    }
    """
    with open(mock_file) as f:
        return json.load(f)

def query_tmeet(date_str):
    """调 tmeet CLI 查当天已有会议"""
    start_iso = f"{date_str}T00:00:00{TIMEZONE}"
    end_iso   = f"{date_str}T23:59:59{TIMEZONE}"

    result = subprocess.run(
        [TMEET_CMD, "meeting", "list",
         "--start", start_iso,
         "--end", end_iso,
         "--compact",
         "--format", "json"],
        capture_output=True, text=True, timeout=30
    )

    if result.returncode != 0:
        return []

    data = json.loads(result.stdout).get("data", {})
    meetings = data.get("meetings", data.get("meeting_list", data.get("items", [])))

    existing = []
    for m in meetings:
        s = m.get("start_time", m.get("start", ""))
        e = m.get("end_time", m.get("end", ""))
        s_dt = parse_meeting_time(s)
        e_dt = parse_meeting_time(e)
        if s_dt and e_dt:
            existing.append({"subject": m.get("subject", "未知会议"), "start": s_dt, "end": e_dt})
    return existing

# ===== 1. 解析输入 =====
try:
    schedule = json.loads(INPUT_JSON)
except json.JSONDecodeError as e:
    print(json.dumps({"error": f"invalid JSON: {e}"}))
    sys.exit(1)

if not isinstance(schedule, list):
    print(json.dumps({"error": "input must be a JSON array"}))
    sys.exit(1)

# ===== 2. 按日期分组 =====
date_slots = {}
for slot in schedule:
    d = slot.get("date", "")
    date_slots.setdefault(d, []).append(slot)

# ===== 3. 获取已有会议数据 =====
existing_by_date = {}

if DATA_FILE:
    mock = load_mock_meetings(DATA_FILE)
    for date_str in date_slots:
        entries = mock.get(date_str, [])
        existing = []
        for m in entries:
            s_dt = parse_meeting_time(m.get("start_time", m.get("start", "")))
            e_dt = parse_meeting_time(m.get("end_time", m.get("end", "")))
            if s_dt and e_dt:
                existing.append({"subject": m.get("subject", "未知会议"), "start": s_dt, "end": e_dt})
        existing_by_date[date_str] = existing
else:
    for date_str in date_slots:
        try:
            existing_by_date[date_str] = query_tmeet(date_str)
        except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
            existing_by_date[date_str] = []

# ===== 4. 逐个 slot 检测冲突 =====
output = []
for slot in schedule:
    date_str  = slot.get("date", "")
    start_str = slot.get("start", "")
    end_str   = slot.get("end", "")

    try:
        new_start = parse_time(date_str, start_str)
        new_end   = parse_time(date_str, end_str)
    except ValueError:
        output.append({**slot, "conflict": False, "parse_error": True})
        continue

    conflicts = []
    for ex in existing_by_date.get(date_str, []):
        if time_overlap(new_start, new_end, ex["start"], ex["end"]):
            conflicts.append(ex["subject"])

    entry = {**slot}
    entry["conflict"] = len(conflicts) > 0
    if conflicts:
        entry["conflict_with"] = conflicts

    output.append(entry)

print(json.dumps(output, ensure_ascii=False, indent=2))
PYEOF
