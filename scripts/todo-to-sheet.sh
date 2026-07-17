#!/bin/bash
# todo-to-sheet.sh — 将 todo JSON 转为腾讯文档 sheet 写入参数
#
# 用法:
#   echo '<todo_json>' | ./todo-to-sheet.sh
#
# 输出: MCP sheet.set_range_value 的 values 数组 JSON
#   AI 直接用输出值作为 values 参数调 MCP
#
# 依赖: python3

INPUT=$(cat)
export INPUT
python3 << 'PYEOF'
import json, os

todos = json.loads(os.environ["INPUT"])

values = [
    # Header row
    {"col": 0, "row": 0, "string_value": "待办内容", "value_type": "STRING"},
    {"col": 1, "row": 0, "string_value": "负责人",   "value_type": "STRING"},
    {"col": 2, "row": 0, "string_value": "来源会议",  "value_type": "STRING"},
    {"col": 3, "row": 0, "string_value": "日期",     "value_type": "STRING"},
    {"col": 4, "row": 0, "string_value": "状态",     "value_type": "STRING"},
]

for i, t in enumerate(todos):
    row = i + 1
    values.append({"col": 0, "row": row, "string_value": t["todo"],    "value_type": "STRING"})
    values.append({"col": 1, "row": row, "string_value": t["owner"],   "value_type": "STRING"})
    values.append({"col": 2, "row": row, "string_value": t["meeting"], "value_type": "STRING"})
    values.append({"col": 3, "row": row, "string_value": t["date"],    "value_type": "STRING"})
    values.append({"col": 4, "row": row, "string_value": "待开始",     "value_type": "STRING"})

print(json.dumps(values, ensure_ascii=False))
PYEOF
