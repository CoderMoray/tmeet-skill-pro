#!/bin/bash
# fetch-records.sh — 批量获取历史会议录制内容（转写 / 纪要）
#
# 用法:
#   echo '<query_json>' | ./fetch-records.sh
#
#   # 测试模式 — 使用 mock 数据
#   echo '<query_json>' | ./fetch-records.sh --data-file /path/to/mock.json
#
# 输入(stdin): JSON 对象 {start, end, keyword?, max_meetings?, content_type, reference_date?}
# 输出:         合并 Markdown 文本
#
# 依赖: tmeet CLI, python3

set -e

# ===== 自动查找 tmeet CLI =====
if command -v tmeet &>/dev/null; then
    TMEET="tmeet"
elif ls ~/.workbuddy/binaries/node/versions/*/bin/tmeet &>/dev/null 2>&1; then
    TMEET=$(ls -d ~/.workbuddy/binaries/node/versions/*/bin/tmeet 2>/dev/null | head -1)
else
    TMEET="tmeet"
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

INPUT=$(cat)

if [ -z "$INPUT" ]; then
    echo '{"error": "no input provided, expect JSON via stdin"}' >&2
    exit 1
fi

export TMEET
export INPUT
export DATA_FILE
python3 << 'PYEOF'
import json
import subprocess
import sys
import os
from datetime import datetime, timedelta

TIMEZONE = "+08:00"
TMEET_CMD = os.environ.get("TMEET", "tmeet")
INPUT_JSON = os.environ.get("INPUT", "")
DATA_FILE = os.environ.get("DATA_FILE", "")
MOCK = None
if DATA_FILE:
    with open(DATA_FILE) as f:
        MOCK = json.load(f)

# ============================================================
#  CLI helpers
# ============================================================

def run_tmeet(*args, timeout=60):
    """Run tmeet CLI, return (success, data_dict_or_error)."""
    result = subprocess.run(
        [TMEET_CMD] + list(args),
        capture_output=True, text=True, timeout=timeout
    )
    if result.returncode != 0:
        return False, result.stderr.strip() or result.stdout.strip()
    try:
        body = json.loads(result.stdout)
        return True, body.get("data", body)
    except json.JSONDecodeError:
        return False, result.stdout.strip()


def iso_range(date_str, start_of_day=True):
    """Convert YYYY-MM-DD to ISO 8601 with timezone."""
    if not date_str:
        return ""
    time_part = "T00:00:00" if start_of_day else "T23:59:59"
    return f"{date_str}{time_part}{TIMEZONE}"


def parse_date(date_str):
    """Parse YYYY-MM-DD to datetime."""
    if not date_str:
        return None
    try:
        return datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        return None

# ============================================================
#  Input validation
# ============================================================

def validate_input(q):
    errors = []
    warnings = []

    if not q.get("start") or not q.get("end"):
        errors.append("start 和 end 为必填字段")
    else:
        s = parse_date(q["start"])
        e = parse_date(q["end"])
        if s and e and s > e:
            errors.append(f"start ({q['start']}) 晚于 end ({q['end']})")
        if s and e and (e - s).days > 31:
            errors.append(f"时间范围 ({e - s}).days 天，超过 31 天限制")

    if q.get("reference_date"):
        ref = parse_date(q["reference_date"])
        e = parse_date(q.get("end", ""))
        if ref and e:
            delta = (e - ref).days
            if delta > 365:
                warnings.append(
                    f"end ({q['end']}) 比 reference_date ({q['reference_date']}) "
                    f"晚 {delta} 天，请确认没有年份计算错误"
                )

    ct = q.get("content_type", "transcript")
    if ct not in ("transcript", "minutes"):
        errors.append(f"content_type 必须为 transcript 或 minutes，当前: {ct}")

    return errors, warnings

# ============================================================
#  Step 1: meeting list-ended (with pagination)
# ============================================================

def get_ended_meetings(start_iso, end_iso):
    """Fetch all ended meetings in time range, handle pagination."""
    if MOCK:
        ml = MOCK.get("list_ended", {})
        meetings = []
        for m in ml.get("meeting_info_list", []):
            meetings.append({
                "meeting_id": m.get("meeting_id", ""),
                "meeting_code": m.get("meeting_code", ""),
                "subject": m.get("subject", ""),
                "start_time": m.get("start_time", ""),
                "end_time": m.get("end_time", ""),
                "meeting_type": m.get("meeting_type", ""),
            })
        return meetings, None

    all_meetings = []
    page_token = ""

    while True:
        args = [
            "meeting", "list-ended",
            "--start", start_iso,
            "--end", end_iso,
            "--compact", "--format", "json"
        ]
        if page_token:
            args += ["--page-token", page_token]

        ok, data = run_tmeet(*args, timeout=30)
        if not ok:
            return None, f"meeting list-ended 失败: {data}"

        meetings = data.get("meeting_info_list", [])
        for m in meetings:
            all_meetings.append({
                "meeting_id": m.get("meeting_id", ""),
                "meeting_code": m.get("meeting_code", ""),
                "subject": m.get("subject", ""),
                "start_time": m.get("start_time", ""),
                "end_time": m.get("end_time", ""),
                "meeting_type": m.get("meeting_type", ""),
            })

        page_token = data.get("next_page_token", "")
        if not page_token:
            break

    return all_meetings, None

# ============================================================
#  Step 2: keyword filter
# ============================================================

def filter_meetings(meetings, keyword, max_meetings):
    if keyword:
        kw = keyword.lower()
        meetings = [m for m in meetings if kw in m["subject"].lower()]
    if max_meetings and len(meetings) > max_meetings:
        meetings = meetings[:max_meetings]
    return meetings

# ============================================================
#  Step 3: record list
# ============================================================

def get_recording(meeting_id):
    """Get recording info for a meeting. Returns dict with record_file_id etc, or None."""
    if MOCK:
        rl = MOCK.get("record_list", {})
        rec = rl.get(meeting_id, {})
        if rec.get("status"):
            return rec
        return rec if rec.get("record_file_id") else {"status": "no_recording"}

    ok, data = run_tmeet(
        "record", "list", "--meeting-id", meeting_id,
        "--compact", "--format", "json",
        timeout=30
    )
    if not ok:
        return {"status": "error", "detail": data}

    record_meetings = data.get("record_meetings", [])
    if not record_meetings:
        return {"status": "no_recording"}

    rm = record_meetings[0]
    record_files = rm.get("record_files", [])
    if not record_files:
        return {"status": "no_recording"}

    rf = record_files[0]
    return {
        "status": "ok",
        "meeting_record_id": rm.get("meeting_record_id", ""),
        "record_file_id": rf.get("record_file_id", ""),
        "record_type": rm.get("record_type", ""),
        "state": rm.get("state", ""),
        "record_start_time": rf.get("record_start_time", ""),
        "record_end_time": rf.get("record_end_time", ""),
    }

# ============================================================
#  Step 3b: report participants (best-effort)
# ============================================================

def get_participants(meeting_id):
    """Try to get participant list. Returns (list_of_names, status_text)."""
    if MOCK:
        pl = MOCK.get("participants", {})
        p = pl.get(meeting_id)
        if p == "no_permission":
            return [], "no_permission"
        if isinstance(p, list):
            return p, "ok"
        return [], "empty"

    ok, data = run_tmeet(
        "report", "participants", "--meeting-id", meeting_id,
        "--compact", "--format", "json",
        timeout=30
    )
    if not ok:
        # 9042 = 无权限
        if "9042" in str(data) or "无权限" in str(data):
            return [], "no_permission"
        return [], "error"

    participants = data.get("participants", data.get("participant_list", data.get("items", [])))
    names = []
    for p in participants:
        name = p.get("user_name", p.get("name", ""))
        if name:
            names.append(name)

    if names:
        return names, "ok"
    return [], "empty"

# ============================================================
#  Step 4a: transcript-get (with pagination)
# ============================================================

def get_transcript(record_file_id):
    """Fetch full transcript, paginated. Returns (text, speaker_list, error)."""
    if MOCK:
        tl = MOCK.get("transcript", {})
        t = tl.get(record_file_id, {})
        return t.get("text", ""), t.get("speakers", []), t.get("error")

    all_paragraphs = []
    pid = ""

    while True:
        args = [
            "record", "transcript-get",
            "--record-file-id", record_file_id,
            "--format", "json"
        ]
        if pid:
            args += ["--pid", pid, "--limit", "30"]

        ok, data = run_tmeet(*args, timeout=30)
        if not ok:
            return "", [], f"transcript-get 失败: {data}"

        minutes = data.get("minutes", {})
        paragraphs = minutes.get("paragraphs", [])

        if not paragraphs:
            break

        all_paragraphs.extend(paragraphs)

        # Check if there are more paragraphs
        last_pid = paragraphs[-1].get("pid", "")
        # Try to get more — if we got fewer than limit, or last pid == pid, stop
        if len(paragraphs) < 30 or last_pid == pid:
            break
        pid = last_pid

    # Extract speakers
    speakers = set()
    for p in all_paragraphs:
        speaker = p.get("speaker", {})
        name = speaker.get("user_name", "")
        if name:
            speakers.add(name)

    # Extract text
    lines = []
    for p in all_paragraphs:
        speaker = p.get("speaker", {})
        name = speaker.get("user_name", "未知")
        for s in p.get("sentences", []):
            text_parts = []
            for w in s.get("words", []):
                text_parts.append(w.get("text", ""))
            text = "".join(text_parts)
            if text:
                lines.append(f"{name}：{text}")

    return "\n".join(lines), sorted(speakers), None

# ============================================================
#  Step 4a-extra: transcript-search + merge intervals
# ============================================================

def transcript_search(record_file_id, search_text):
    """Search transcript for keyword. Returns list of unique pid strings."""
    if MOCK:
        tl = MOCK.get("transcript_search", {})
        pids = tl.get(record_file_id, [])
        return list(pids), None

    ok, data = run_tmeet(
        "record", "transcript-search",
        "--record-file-id", record_file_id,
        "--text", search_text,
        "--format", "json",
        timeout=30
    )
    if not ok:
        return [], f"transcript-search 失败: {data}"

    hits = data.get("hits", [])
    pids = list(set(h.get("pid", "") for h in hits if h.get("pid")))
    return pids, None


def merge_intervals(pid_strs, window):
    """Merge overlapping pid intervals with context window.
    Returns list of (start_pid, end_pid) int tuples.
    """
    if not pid_strs:
        return []

    pids = sorted(set(int(p) for p in pid_strs if p.isdigit()))
    intervals = [(max(0, p - window), p + window) for p in pids]
    intervals.sort()

    merged = [intervals[0]]
    for start, end in intervals[1:]:
        last_start, last_end = merged[-1]
        if start <= last_end + 1:
            merged[-1] = (last_start, max(last_end, end))
        else:
            merged.append((start, end))
    return merged


def get_transcript_range(record_file_id, start_pid, count):
    """Fetch transcript paragraphs from start_pid for count paragraphs."""
    if MOCK:
        tl = MOCK.get("transcript_range", {})
        ranges = tl.get(record_file_id, {})
        r = ranges.get(str(start_pid), {})
        return r.get("text", ""), r.get("speakers", [])

    ok, data = run_tmeet(
        "record", "transcript-get",
        "--record-file-id", record_file_id,
        "--pid", str(start_pid),
        "--limit", str(count),
        "--format", "json",
        timeout=30
    )
    if not ok:
        return "", []

    minutes = data.get("minutes", {})
    paragraphs = minutes.get("paragraphs", [])

    speakers = set()
    lines = []
    for p in paragraphs:
        speaker = p.get("speaker", {})
        name = speaker.get("user_name", "未知")
        if name:
            speakers.add(name)
        for s in p.get("sentences", []):
            text = "".join(w.get("text", "") for w in s.get("words", []))
            if text:
                lines.append(f"{name}：{text}")

    return "\n".join(lines), sorted(speakers)

# ============================================================
#  Step 4b: smart-minutes
# ============================================================

def extract_speakers_from_minutes(text):
    """Extract speaker names from smart-minutes text header.
    Pattern: 发言人：Name1、Name2、...等N人  or  发言人：Name1、Name2、...
    """
    import re
    m = re.search(r'发言人[：:]\s*(.+?)(?:等\d+人|\n)', text)
    if m:
        raw = m.group(1).strip()
        # Split by Chinese/English comma and 、
        names = re.split(r'[、,，]', raw)
        names = [n.strip() for n in names if n.strip()]
        if names:
            return names
    return []


def get_minutes(record_file_id):
    """Fetch smart minutes. Returns (text, speakers, error)."""
    if MOCK:
        ml = MOCK.get("minutes", {})
        m = ml.get(record_file_id, {})
        return m.get("text", ""), m.get("speakers", []), m.get("error")

    ok, data = run_tmeet(
        "record", "smart-minutes",
        "--record-file-id", record_file_id,
        "--format", "json",
        timeout=30
    )
    if not ok:
        return "", [], f"smart-minutes 失败: {data}"

    mm = data.get("meeting_minute", {})
    text = mm.get("minute", "")
    speakers = extract_speakers_from_minutes(text)
    return text, speakers, None

# ============================================================
#  Output helpers
# ============================================================

def format_duration(start_str, end_str):
    """Calculate duration from two ISO strings, return readable format."""
    fmts = [
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M%z",
        "%Y-%m-%d %H:%M:%S",
    ]
    s_dt = e_dt = None
    for fmt in fmts:
        try:
            if not s_dt:
                s_dt = datetime.strptime(start_str, fmt)
            if not e_dt:
                e_dt = datetime.strptime(end_str, fmt)
        except ValueError:
            continue
    if s_dt and e_dt:
        mins = int((e_dt - s_dt).total_seconds() / 60)
        if mins >= 60:
            h, m = divmod(mins, 60)
            if m == 0:
                return f"{h} 小时"
            return f"{h} 小时 {m} 分钟"
        return f"{mins} 分钟"
    return ""


def format_time_display(iso_str):
    """Format ISO time to readable display: 06-16 10:14"""
    fmts = [
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M%z",
    ]
    for fmt in fmts:
        try:
            dt = datetime.strptime(iso_str, fmt)
            return dt.strftime("%m-%d %H:%M")
        except ValueError:
            continue
    return iso_str


PARTICIPANT_NO_PERMISSION = "无法获取（仅会议发起人及主持人/联席主持人可获取）"

# ============================================================
#  Main
# ============================================================

def main():
    # Parse input
    try:
        q = json.loads(INPUT_JSON)
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"invalid JSON: {e}"}))
        sys.exit(1)

    # Validate
    errors, warnings = validate_input(q)
    if errors:
        print("# 参数校验失败\n")
        for e in errors:
            print(f"- **错误**：{e}")
        print()
        if warnings:
            for w in warnings:
                print(f"- **警告**：{w}")
        sys.exit(1)

    start = q["start"]
    end = q["end"]
    keyword = q.get("keyword", "")
    max_meetings = q.get("max_meetings", 5)
    content_type = q.get("content_type", "transcript")
    reference_date = q.get("reference_date", "")
    search_text = q.get("search_text", "")
    context_paragraphs = q.get("context_paragraphs", 2)

    start_iso = iso_range(start, start_of_day=True)
    end_iso = iso_range(end, start_of_day=False)

    # Document header
    print(f"# 录制内容汇总：{start} ~ {end}")
    if reference_date:
        print(f"- 参考日期：{reference_date}")
    kw_display = f"，关键词：{keyword}" if keyword else ""
    print(f"- 匹配范围：最多 {max_meetings} 场{kw_display}")
    ct_display = "转写" if content_type == "transcript" else "纪要"
    if search_text:
        ct_display += f"（搜索「{search_text}」）"
    print(f"- 内容类型：{ct_display}")
    if warnings:
        for w in warnings:
            print(f"- ⚠️ {w}")
    print()

    # Step 1: get meetings
    meetings, err = get_ended_meetings(start_iso, end_iso)
    if err:
        print(f"**获取会议列表失败**：{err}")
        sys.exit(1)

    if not meetings:
        print("该时间段内没有已结束的会议。")
        sys.exit(0)

    # Step 2: filter
    total_before = len(meetings)
    meetings = filter_meetings(meetings, keyword, max_meetings)
    total_after = len(meetings)

    if total_before != total_after:
        print(f"_共找到 {total_before} 场会议，匹配 {total_after} 场_\n")

    if not meetings:
        print("没有匹配的会议。")
        sys.exit(0)

    # Step 3-4: process each meeting
    idx = 0
    for m in meetings:
        idx += 1
        subject = m["subject"]
        meeting_code = m["meeting_code"]
        start_t = m["start_time"]
        end_t = m["end_time"]
        meeting_type = m["meeting_type"]
        duration = format_duration(start_t, end_t)
        time_display = f"{format_time_display(start_t)} ~ {format_time_display(end_t)}"
        if duration:
            time_display += f"（{duration}）"

        print(f"### {idx}. {subject}")
        print(f"- 会议号：{meeting_code}")
        print(f"- 时间：{time_display}")
        print(f"- 类型：{meeting_type}")

        # Get recording
        rec = get_recording(m["meeting_id"])

        if rec["status"] == "no_recording":
            print("- 录制：无录制")
            print(f"- 参会人：{PARTICIPANT_NO_PERMISSION}")
            print("- 发言人：—")
            print("- 内容：—")
            print()
            continue

        if rec["status"] == "error":
            print(f"- 录制：获取失败（{rec['detail']}）")
            print(f"- 参会人：{PARTICIPANT_NO_PERMISSION}")
            print("- 发言人：—")
            print("- 内容：—")
            print()
            continue

        record_state = f"{rec['record_type']}，{rec['state']}" if rec['record_type'] else rec['state']
        print(f"- 录制：{record_state}")

        # Get participants (best-effort)
        participant_names, participant_status = get_participants(m["meeting_id"])
        if participant_names:
            count = len(participant_names)
            print(f"- 参会人：{'、'.join(participant_names)}（{count} 人）")
        else:
            print(f"- 参会人：{PARTICIPANT_NO_PERMISSION}")

        # Get content
        record_file_id = rec.get("record_file_id", "")
        if not record_file_id:
            print("- 发言人：—")
            print("- 内容：—")
            print()
            continue

        # Only fetch content if recording is ready
        state = rec.get("state", "")
        if state and state not in ("转码完成", "ok"):
            print("- 发言人：—")
            print("- 内容：—（录制未就绪）")
            print()
            continue

        if content_type == "transcript":
            if search_text:
                # === Search mode ===
                hit_pids, search_err = transcript_search(record_file_id, search_text)
                if search_err:
                    print(f"- 🔍 搜索失败：{search_err}")
                    print("- 发言人：—")
                    print("- 内容：—")
                    print()
                    continue

                if not hit_pids:
                    print(f"- 🔍 搜索「{search_text}」无结果")
                    print("- 发言人：—")
                    print("- 内容：—")
                    print()
                    continue

                raw_hits = len(hit_pids)
                intervals = merge_intervals(hit_pids, context_paragraphs)
                total_paragraphs = sum(e - s + 1 for s, e in intervals)

                interval_desc = "、".join(f"p{s}~p{e}" for s, e in intervals)
                print(f"- 🔍 搜索「{search_text}」命中 {raw_hits} 处，"
                      f"±{context_paragraphs} 段上下文，"
                      f"合并 {len(intervals)} 个区间（{interval_desc}），"
                      f"共 {total_paragraphs} 段")

                # Fetch each interval
                all_lines = []
                all_speakers = set()
                for si, (s_pid, e_pid) in enumerate(intervals):
                    int_lines, int_speakers = get_transcript_range(
                        record_file_id, s_pid, e_pid - s_pid + 1)
                    if int_lines:
                        if len(intervals) > 1:
                            all_lines.append(f"\n**区间 {si+1}：p{s_pid} ~ p{e_pid}**\n")
                        all_lines.append(int_lines)
                        all_speakers.update(int_speakers)

                if all_speakers:
                    count = len(all_speakers)
                    print(f"- 发言人：{'、'.join(sorted(all_speakers))}（{count} 人）")
                else:
                    print("- 发言人：—")

                full_text = "\n".join(all_lines)
                if full_text:
                    print(f"- 转写节选：")
                    print()
                    print(full_text)
                else:
                    print("- 转写节选：—")
            else:
                # === Full transcript mode ===
                text, speakers, tex_err = get_transcript(record_file_id)
                if speakers:
                    count = len(speakers)
                    print(f"- 发言人：{'、'.join(speakers)}（{count} 人）")
                else:
                    print("- 发言人：—")

                if tex_err:
                    print(f"- 转写内容：获取失败（{tex_err}）")
                elif text:
                    print(f"- 转写内容：")
                    print()
                    print(text)
                else:
                    print("- 转写内容：—（无转写数据）")
        else:
            text, spk_list, min_err = get_minutes(record_file_id)

            if spk_list:
                count = len(spk_list)
                print(f"- 发言人：{'、'.join(spk_list)}（{count} 人）")
            else:
                print("- 发言人：—")

            if min_err:
                print(f"- 纪要内容：获取失败（{min_err}）")
            elif text:
                print(f"- 纪要内容：")
                print()
                print(text)
            else:
                print("- 纪要内容：—（无纪要数据）")

        print()

    print("---")
    print(f"_共处理 {idx} 场会议_")

if __name__ == "__main__":
    main()
PYEOF
