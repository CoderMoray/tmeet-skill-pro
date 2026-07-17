#!/bin/bash
# todo-to-doc.sh — 将 todo JSON 转为 Markdown 复盘报告
#
# 用法:
#   echo '<query_json>' | ./fetch-records.sh --todo-only | ./todo-to-doc.sh
#
# 输出: Markdown 文本
#   AI 用 base64 编码后调 doc.create_with_markdown(title="...", base64_markdown=<编码后>)
#
# 依赖: python3

INPUT=$(cat)
export INPUT
python3 << 'PYEOF'
import json, os
from datetime import datetime

todos = json.loads(os.environ["INPUT"])
today = datetime.now().strftime("%Y-%m-%d")

meetings = sorted(set(t["meeting"] for t in todos))
owners = sorted(set(t["owner"] for t in todos))

lines = [
    "# 跨会议待办复盘报告",
    "",
    f"> 自动生成于 {today}，数据来源：腾讯会议 AI 纪要",
    f"> 覆盖 {len(meetings)} 场会议，{len(todos)} 条待办，{len(owners)} 位负责人",
    "",
    "## 待办列表",
    "",
    "| 待办 | 负责人 | 来源会议 | 日期 |",
    "|------|--------|---------|------|",
]

for t in todos:
    lines.append(f"| {t['todo']} | {t['owner']} | {t['meeting']} | {t['date']} |")

lines += [
    "",
    "## 会议来源",
    "",
]

for i, m in enumerate(meetings):
    lines.append(f"{i+1}. {m}")

lines += [
    "",
    "---",
    "*本报告由 AI 自动生成，数据来源为会议待办项。如需补充结论或调整格式，请直接编辑本文档。*",
]

print("\n".join(lines))
PYEOF
