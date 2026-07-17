#!/bin/bash
# todo-kanban.sh — 从 todo JSON 生成交互式 HTML 看板
#
# 用法:
#   echo '<todo_json>' | bash todo-kanban.sh > kanban.html
#   或:
#   echo '{"start":"...","end":"...","todo_only":true}' \
#     | bash fetch-records.sh | bash todo-kanban.sh > kanban.html
#
# 依赖: python3

INPUT=$(cat)
if [ -z "$INPUT" ]; then
    echo '[]'
fi

export INPUT
python3 << 'PYEOF'
import json, os

todos = json.loads(os.environ["INPUT"])

meetings = sorted(set(t["meeting"] for t in todos))
owners = sorted(set(t["owner"] for t in todos))
dates = sorted(set(t["date"] for t in todos))
owner_counts = {}
for t in todos:
    owner_counts[t["owner"]] = owner_counts.get(t["owner"], 0) + 1

def card(t):
    """Render a todo card as HTML string."""
    return f"""<div class="card" data-meeting="{t['meeting']}" data-owner="{t['owner']}" data-date="{t['date']}">
    <div class="card-body">{t['todo']}</div>
    <span class="card-owner">@{t['owner']}</span>
    <div class="card-meta">{t['meeting']} · {t['date']}</div>
  </div>"""

# Build cards
start_cards = "\n".join(card(t) for t in todos)

# Build dropdown options
meeting_opts = '<option value="all">全部会议</option>\n    ' + \
    '\n    '.join(f'<option value="{m}">{m}</option>' for m in meetings)
owner_opts = '<option value="all">全部负责人</option>\n    ' + \
    '\n    '.join(f'<option value="{o}">@{o}（{owner_counts[o]} 条）</option>' for o in owners)
date_opts = '<option value="all">全部日期</option>\n    ' + \
    '\n    '.join(f'<option value="{d}">{d}</option>' for d in dates)

# Owner breakdown
owner_items = [f"{k}（{v} 条）" for k, v in sorted(owner_counts.items(), key=lambda x: -x[1])]

html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>跨会议待办看板</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif;
  background: #f7f7f7; color: #2c2c2c; padding: 24px 32px;
}}
.header {{ margin-bottom: 20px; }}
.header h1 {{ font-size: 22px; font-weight: 600; }}
.header .sub {{ font-size: 13px; color: #999; margin-top: 4px; }}
.filters {{
  display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 20px;
  background: #fff; padding: 14px 16px; border-radius: 10px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.06); align-items: center;
}}
.filters select, .filters button {{
  padding: 6px 12px; border: 1px solid #ddd; border-radius: 6px;
  font-size: 13px; font-family: inherit; background: #fff; cursor: pointer;
}}
.filters select:focus {{ outline: none; border-color: #534AB7; box-shadow: 0 0 0 2px #EEEDFE; }}
.filters button {{ background: #534AB7; color: #fff; border-color: #534AB7; margin-left: auto; }}
.filters button:hover {{ opacity: 0.9; }}
.filter-count {{ font-size: 12px; color: #aaa; margin-left: 8px; }}
.board {{ display: flex; gap: 16px; align-items: flex-start; }}
.column {{
  flex: 1; min-width: 0; background: #fff; border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08); padding: 16px;
}}
.column-header {{
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 12px; padding-bottom: 10px; border-bottom: 2px solid;
}}
.column:nth-child(1) .column-header {{ border-color: #F5A623; }}
.column:nth-child(2) .column-header {{ border-color: #4A90D9; }}
.column:nth-child(3) .column-header {{ border-color: #7ED321; }}
.column-title {{ font-size: 14px; font-weight: 600; }}
.column:nth-child(1) .column-title {{ color: #E0951A; }}
.column:nth-child(2) .column-title {{ color: #3A7DC1; }}
.column:nth-child(3) .column-title {{ color: #5EA513; }}
.column-count {{ font-size: 12px; color: #fff; border-radius: 10px; padding: 1px 8px; }}
.column:nth-child(1) .column-count {{ background: #F5A623; }}
.column:nth-child(2) .column-count {{ background: #4A90D9; }}
.column:nth-child(3) .column-count {{ background: #7ED321; }}
.card {{
  background: #fafafa; border: 1px solid #eee; border-radius: 8px;
  padding: 12px; margin-bottom: 8px; font-size: 13px;
  line-height: 1.55; transition: opacity .15s;
}}
.card.hidden {{ display: none; }}
.card-body {{ margin-bottom: 6px; }}
.card-owner {{
  display: inline-block; font-size: 11px; color: #534AB7;
  background: #EEEDFE; padding: 1px 8px; border-radius: 10px; margin-right: 6px;
}}
.card-meta {{ font-size: 11px; color: #bbb; margin-top: 2px; }}
.summary {{
  margin-top: 20px; font-size: 12px; color: #888;
  background: #fff; border-radius: 10px; padding: 14px 16px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.06); line-height: 1.7;
}}
.summary strong {{ color: #555; }}
.empty {{ color: #ccc; font-size: 13px; text-align: center; padding: 32px 0; }}
@media (max-width: 900px) {{ .board {{ flex-direction: column; }} }}
</style>
</head>
<body>
<div class="header">
  <h1>跨会议待办看板</h1>
  <p class="sub">共 [TOTAL] 条待办，[OWNER_COUNT] 位负责人，[MEETING_COUNT] 场会议</p>
</div>
<div class="filters">
  <select id="filterMeeting">
    [MEETING_OPTS]
  </select>
  <select id="filterOwner">
    [OWNER_OPTS]
  </select>
  <select id="filterDate">
    [DATE_OPTS]
  </select>
  <span class="filter-count" id="filterCount"></span>
  <button onclick="resetFilters()">清除筛选</button>
</div>
<div class="board">
  <div class="column" id="colTodo">
    <div class="column-header">
      <span class="column-title">待开始</span>
      <span class="column-count" id="countTodo">[START_COUNT]</span>
    </div>
    <div id="listTodo">
      [START_CARDS]
    </div>
  </div>
  <div class="column" id="colProgress">
    <div class="column-header">
      <span class="column-title">进行中</span>
      <span class="column-count" id="countProgress">0</span>
    </div>
    <div id="listProgress">
      <div class="empty">拖拽卡片到此处</div>
    </div>
  </div>
  <div class="column" id="colDone">
    <div class="column-header">
      <span class="column-title">已完成</span>
      <span class="column-count" id="countDone">0</span>
    </div>
    <div id="listDone">
      <div class="empty">拖拽卡片到此处</div>
    </div>
  </div>
</div>
<div style="display:flex;gap:8px;justify-content:flex-end;margin:16px 0 0;">
  <button onclick="showAddForm()" style="padding:6px 14px;border:1px solid #534AB7;border-radius:6px;background:#534AB7;color:#fff;font-size:12px;font-family:inherit;cursor:pointer;">+ 新增卡片</button>
  <button onclick="undo()" style="padding:6px 14px;border:1px solid #ddd;border-radius:6px;background:#fff;font-size:12px;font-family:inherit;cursor:pointer;color:#888;">↩ 撤销</button>
  <button onclick="redo()" style="padding:6px 14px;border:1px solid #ddd;border-radius:6px;background:#fff;font-size:12px;font-family:inherit;cursor:pointer;color:#888;">↪ 重做</button>
  <button onclick="resetBoard()" style="padding:6px 14px;border:1px solid #ddd;border-radius:6px;background:#fff;font-size:12px;font-family:inherit;cursor:pointer;color:#888;">↺ 重置卡片</button>
</div>
<div id="addForm" style="display:none;margin-top:12px;padding:16px;background:#fafafa;border:1px solid #eee;border-radius:10px;">
  <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:flex-end;">
    <input id="newTodo" placeholder="待办内容" style="flex:2;min-width:200px;padding:6px 10px;border:1px solid #ddd;border-radius:6px;font-size:13px;font-family:inherit;">
    <input id="newOwner" placeholder="@负责人" style="flex:1;min-width:100px;padding:6px 10px;border:1px solid #ddd;border-radius:6px;font-size:13px;font-family:inherit;">
    <select id="newMeeting" style="flex:1;min-width:120px;padding:6px 10px;border:1px solid #ddd;border-radius:6px;font-size:13px;font-family:inherit;">
      [MEETING_OPTS]
    </select>
    <input id="newDate" type="date" style="flex:1;min-width:120px;padding:6px 10px;border:1px solid #ddd;border-radius:6px;font-size:13px;font-family:inherit;">
    <button onclick="addCard()" style="padding:6px 16px;background:#534AB7;color:#fff;border:none;border-radius:6px;font-size:13px;font-family:inherit;cursor:pointer;">添加</button>
    <button onclick="hideAddForm()" style="padding:6px 12px;background:#fff;border:1px solid #ddd;border-radius:6px;font-size:13px;font-family:inherit;cursor:pointer;">取消</button>
  </div>
</div>
<div class="summary">
  <strong>负责人分布：</strong>[OWNER_LIST]
</div>
<script>
var allCards = document.querySelectorAll('.card');
var dragCardId = null;
var uidCounter = 0;
var initialState = null;  // snapshot on first load
var hasUnsaved = false;
var undoStack = [];
var redoStack = [];
var MAX_UNDO = 20;

function pushUndo() {{
  undoStack.push(JSON.stringify(collectState()));
  if (undoStack.length > MAX_UNDO) undoStack.shift();
  redoStack = [];
}}

// Assign unique IDs to all cards on page load
(function assignIds() {{
  document.querySelectorAll('.card').forEach(function(c) {{
    c.dataset.uid = 'card-' + (++uidCounter);
  }});
}})();

function applyFilters() {{
  var m = filterMeeting.value;
  var o = filterOwner.value;
  var d = filterDate.value;
  var visible = 0;
  allCards = document.querySelectorAll('.card');
  allCards.forEach(function(c) {{
    var ok = (m === 'all' || c.dataset.meeting === m) &&
            (o === 'all' || c.dataset.owner === o) &&
            (d === 'all' || c.dataset.date === d);
    c.classList.toggle('hidden', !ok);
    if (ok) visible++;
  }});
  var total = allCards.length;
  filterCount.textContent = visible < total ? '显示 ' + visible + '/' + total + ' 条' : '';
  updateCounts();
}}

filterMeeting.onchange = applyFilters;
filterOwner.onchange = applyFilters;
filterDate.onchange = applyFilters;

function resetFilters() {{
  filterMeeting.value = 'all';
  filterOwner.value = 'all';
  filterDate.value = 'all';
  applyFilters();
}}

function resetBoard() {{
  var all = {{}};
  document.querySelectorAll('.card').forEach(function(c) {{ all[c.dataset.uid] = c; }});
  ['Todo', 'Progress', 'Done'].forEach(function(col) {{
    document.getElementById('list' + col).innerHTML = '';
    var div = document.createElement('div'); div.className = 'empty';
    div.textContent = '拖拽卡片到此处';
    document.getElementById('list' + col).appendChild(div);
  }});
  var initial = JSON.parse(initialState);
  Object.keys(initial).forEach(function(col) {{
    var list = document.getElementById('list' + col);
    var empty = list.querySelector('.empty'); if (empty) empty.remove();
    (initial[col] || []).forEach(function(uid) {{
      if (all[uid]) list.appendChild(all[uid]);
    }});
  }});
  hasUnsaved = false; undoStack = []; redoStack = [];
  saveState(); checkEmptyColumns();
  allCards = document.querySelectorAll('.card'); applyFilters();
}};

function undo() {{
  if (undoStack.length === 0) return;
  redoStack.push(JSON.stringify(collectState()));
  restoreFromState(JSON.parse(undoStack.pop()));
}}

function redo() {{
  if (redoStack.length === 0) return;
  pushUndo();
  restoreFromState(JSON.parse(redoStack.pop()));
}}

function restoreFromState(state) {{
  var all = {{}};
  document.querySelectorAll('.card').forEach(function(c) {{ all[c.dataset.uid] = c; }});
  ['Todo', 'Progress', 'Done'].forEach(function(col) {{
    document.getElementById('list' + col).innerHTML = '';
    var div = document.createElement('div'); div.className = 'empty';
    div.textContent = '拖拽卡片到此处';
    document.getElementById('list' + col).appendChild(div);
  }});
  Object.keys(state).forEach(function(col) {{
    var list = document.getElementById('list' + col);
    var empty = list.querySelector('.empty'); if (empty) empty.remove();
    (state[col] || []).forEach(function(uid) {{
      if (all[uid]) list.appendChild(all[uid]);
    }});
  }});
  checkEmptyColumns();
  allCards = document.querySelectorAll('.card'); applyFilters();
}}

// ===== Drag & Drop with position-aware insertion =====
(function initDrag() {{
  document.querySelectorAll('.card').forEach(function(card) {{
    card.draggable = true;
    card.addEventListener('dragstart', function(e) {{
      dragCardId = card.dataset.uid;
      pushUndo();
      e.dataTransfer.setData('text/plain', card.dataset.uid);
      e.dataTransfer.effectAllowed = 'move';
      card.style.opacity = '0.4';
    }});
    card.addEventListener('dragend', function(e) {{
      card.style.opacity = '1';
      if (!hasUnsaved) hasUnsaved = true;
      saveState();
    }});
  }});
}})();

function getDragAfterElement(container, y) {{
  var cards = Array.from(container.querySelectorAll('.card:not(.dragging)'));
  return cards.reduce(function(closest, child) {{
    var box = child.getBoundingClientRect();
    var offset = y - box.top - box.height / 2;
    if (offset < 0 && offset > closest.offset) {{
      return {{ offset: offset, element: child }};
    }} else {{
      return closest;
    }}
  }}, {{ offset: Number.NEGATIVE_INFINITY }}).element;
}}

document.querySelectorAll('.column').forEach(function(col) {{
  col.addEventListener('dragover', function(e) {{
    e.preventDefault();
    col.style.background = '#f5f3ff';
  }});
  col.addEventListener('dragleave', function(e) {{
    col.style.background = '';
  }});
  col.addEventListener('drop', function(e) {{
    e.preventDefault();
    col.style.background = '';

    var id = e.dataTransfer.getData('text/plain');
    var card = document.querySelector('[data-uid="' + id + '"]');
    if (!card) return;

    var list = col.querySelector('div[id^="list"]');
    var empty = list.querySelector('.empty');
    if (empty) empty.remove();

    var afterElement = getDragAfterElement(list, e.clientY);
    if (afterElement) {{
      list.insertBefore(card, afterElement);
    }} else {{
      list.appendChild(card);
    }}

    checkEmptyColumns();
    allCards = document.querySelectorAll('.card');
    saveState();
    applyFilters();
  }});
}});

// ===== State persistence =====
function collectState() {{
  var state = {{}};
  ['Todo', 'Progress', 'Done'].forEach(function(col) {{
    state[col] = [];
    var list = document.getElementById('list' + col);
    list.querySelectorAll('.card').forEach(function(card) {{
      state[col].push(card.dataset.uid);
    }});
  }});
  return state;
}}

function saveState() {{
  localStorage.setItem('todo-kanban-state', JSON.stringify(collectState()));
}}

function restoreState() {{
  try {{
    var raw = localStorage.getItem('todo-kanban-state');
    if (!raw) return;
    var state = JSON.parse(raw);
    ['Todo', 'Progress', 'Done'].forEach(function(col) {{
      var list = document.getElementById('list' + col);
      var empty = list.querySelector('.empty');
      if (empty) empty.remove();
      list.querySelectorAll('.card').forEach(function(c) {{ c.remove(); }});
      (state[col] || []).forEach(function(uid) {{
        var card = document.querySelector('[data-uid="' + uid + '"]');
        if (card) list.appendChild(card);
      }});
    }});
    checkEmptyColumns();
    allCards = document.querySelectorAll('.card');
    applyFilters();
  }} catch(e) {{}}
}}

// Capture initial state (fresh JSON)
initialState = JSON.stringify(collectState());

// Close confirmation
window.addEventListener('beforeunload', function(e) {{
  if (hasUnsaved && JSON.stringify(collectState()) !== initialState) {{
    e.preventDefault();
    e.returnValue = '';
    return '';
  }}
}});

// ===== Add new card =====
function showAddForm() {{
  document.getElementById('addForm').style.display = 'block';
  document.getElementById('newTodo').focus();
}}

function hideAddForm() {{
  document.getElementById('addForm').style.display = 'none';
  var inp = document.getElementById('newTodo');
  inp.value = '';
  inp.style.borderColor = '';
  inp.style.background = '';
  document.getElementById('newOwner').value = '';
  document.getElementById('newMeeting').value = 'all';
  document.getElementById('newDate').value = '';
}}

function addCard() {{
  var input = document.getElementById('newTodo');
  var todo = input.value.trim();
  if (!todo) {{
    input.style.borderColor = '#E54D42';
    input.style.background = '#FFF5F4';
    input.placeholder = '请填写待办内容';
    input.focus();
    setTimeout(function() {{ input.style.borderColor = ''; input.style.background = ''; input.placeholder = '待办内容'; }}, 2000);
    return;
  }}
  var owner = document.getElementById('newOwner').value.trim() || '未指定';
  var meeting = document.getElementById('newMeeting').value === 'all' ? '手动添加' : document.getElementById('newMeeting').value;
  var date = document.getElementById('newDate').value || new Date().toISOString().slice(0,10);

  pushUndo();
  var card = document.createElement('div');
  card.className = 'card';
  card.dataset.uid = 'card-' + (++uidCounter);
  card.dataset.owner = owner;
  card.dataset.meeting = meeting;
  card.dataset.date = date;
  card.innerHTML = '<div class="card-body">' + escapeHtml(todo) + '</div>' +
    '<span class="card-owner">@' + escapeHtml(owner) + '</span>' +
    '<div class="card-meta">' + escapeHtml(meeting) + ' · ' + date + '</div>';
  card.draggable = true;
  card.addEventListener('dragstart', function(e) {{
    dragCardId = card.dataset.uid;
    pushUndo();
    e.dataTransfer.setData('text/plain', card.dataset.uid);
    e.dataTransfer.effectAllowed = 'move';
    card.style.opacity = '0.4';
  }});
  card.addEventListener('dragend', function(e) {{
    card.style.opacity = '1';
    if (!hasUnsaved) hasUnsaved = true;
    saveState();
  }});

  var list = document.getElementById('listTodo');
  var empty = list.querySelector('.empty');
  if (empty) empty.remove();
  list.appendChild(card);

  hideAddForm();
  hasUnsaved = true;
  saveState();
  checkEmptyColumns();
  allCards = document.querySelectorAll('.card');
  applyFilters();
}}

function escapeHtml(str) {{
  var div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}}

function checkEmptyColumns() {{
  document.querySelectorAll('.column').forEach(function(col) {{
    var list = col.querySelector('div[id^="list"]');
    var cards = list.querySelectorAll('.card');
    var empty = list.querySelector('.empty');
    if (cards.length === 0 && !empty) {{
      var div = document.createElement('div');
      div.className = 'empty';
      div.textContent = '拖拽卡片到此处';
      list.appendChild(div);
    }}
  }});
}}

function updateCounts() {{
  var colTodo = document.getElementById('colTodo').querySelector('div[id^="list"]');
  var colProgress = document.getElementById('colProgress').querySelector('div[id^="list"]');
  var colDone = document.getElementById('colDone').querySelector('div[id^="list"]');
  document.getElementById('countTodo').textContent = colTodo.querySelectorAll('.card:not(.hidden)').length;
  document.getElementById('countProgress').textContent = colProgress.querySelectorAll('.card:not(.hidden)').length;
  document.getElementById('countDone').textContent = colDone.querySelectorAll('.card:not(.hidden)').length;
}}
</script>
</body>
</html>"""

html = html.replace("[TOTAL]", str(len(todos)))
html = html.replace("[OWNER_COUNT]", str(len(owners)))
html = html.replace("[MEETING_COUNT]", str(len(meetings)))
html = html.replace("[START_COUNT]", str(len(todos)))
html = html.replace("[START_CARDS]", start_cards)
html = html.replace("[MEETING_OPTS]", meeting_opts)
html = html.replace("[OWNER_OPTS]", owner_opts)
html = html.replace("[DATE_OPTS]", date_opts)
html = html.replace("[OWNER_LIST]", "、".join(owner_items))

print(html)
PYEOF
