# tmeet-skill-pro

> 让开会更简单 — 腾讯会议 CLI 增强版。在官方 tmeet-skill 基础上，用确定性脚本消灭 AI 幻觉，让你一句话搞定日程编排、会议复盘、受邀人管理。

[![Version](https://img.shields.io/badge/version-0.0.3-blue)](https://skillhub.cn/skills/tmeet-skill-pro)
[![Tests](https://img.shields.io/badge/tests-43%20passed-brightgreen)](#)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

---

## 为什么做这个

腾讯会议 CLI 能做的事很多，但 AI 在做「多步串行调用 + 数学计算」时容易出错：

- 算时间冲突？AI 经常搞错日期算术
- 翻页取全部受邀人？AI 会漏掉后面的页
- 跨 10 场会议捞转写文本？AI 在 4 跳 CLI 调用里迷路

**我们不做新功能，只做工程加固** — 把 AI 容易出错的链路写成确定性脚本，一次 stdin 传入、一次 stdout 返回，零幻觉。

---

## 覆盖的会议场景

| 场景 | 参赛方向 | 能力 |
|------|:--:|------|
| 会前准备 | 01 | 一键批量排期 + 冲突检测 + 历史受邀人复用 |
| 会后跟进 | 03 | 跨会议转录/纪要汇总 → 本地看板 + 腾讯文档同步 |
| 效率洞察 | 04 | 关键词搜索「谁提了XX」→ 命中段落 + 上下文 |
| 场景串联 | 05 | 周报/复盘/面试/培训，同一套工具全搞定 |

---

## 核心能力

### 1. 批量创建 + 冲突检测 `check-conflict.sh`

不用手动翻日历。说「下周一到周五上午 9 点站会」，AI 自动展开日期、检测冲突、列报告给你确认。

```bash
echo '[{"date":"2026-07-20","start":"09:00","end":"09:30","subject":"站会"}]' \
  | bash scripts/check-conflict.sh
```

### 2. 录制深度消费 `fetch-records.sh`

不用逐场翻录播。全文转录、关键词搜索、待办提取，一条命令搞定。

```bash
# 全文转写
echo '{"start":"2026-07-01","end":"2026-07-17","keyword":"面试","content_type":"transcript"}' \
  | bash scripts/fetch-records.sh

# 关键词搜索（命中段落 + 上下文窗口）
echo '{"start":"2026-07-01","end":"2026-07-17","search_text":"延期","context_paragraphs":2}' \
  | bash scripts/fetch-records.sh

# 待办提取
echo '{"start":"2026-07-01","end":"2026-07-17","todo_only":true}' \
  | bash scripts/fetch-records.sh
```

### 3. 待办看板 `todo-kanban.sh`

待办 JSON → 可拖拽 HTML 看板，三栏布局 + 筛选 + 撤销重做。

```bash
echo '{"start":"2026-07-01","end":"2026-07-17","todo_only":true}' \
  | bash scripts/fetch-records.sh \
  | bash scripts/todo-kanban.sh \
  > kanban.html
```

### 4. 受邀人继承 `transfer-invitees.sh`

不用逐个重新邀请。说「把上次项目复盘会的受邀人拉进这次会议」，自动翻页提取全部受邀人、一次性添加。

```bash
bash scripts/transfer-invitees.sh <源meeting_id> <目标meeting_id>
```

### 5. 腾讯文档同步 `todo-to-sheet.sh` / `todo-to-doc.sh`

待办数据一键推送到腾讯文档——在线表格（可筛选排序）或复盘报告文档。

```bash
# 生成 sheet 写入参数
echo '{"start":"2026-07-01","end":"2026-07-17","todo_only":true}' \
  | bash scripts/fetch-records.sh \
  | bash scripts/todo-to-sheet.sh

# 生成复盘 Markdown 报告
echo '{"start":"2026-07-01","end":"2026-07-17","todo_only":true}' \
  | bash scripts/fetch-records.sh \
  | bash scripts/todo-to-doc.sh
```

> 需安装 `tencent-docs` 连接器：`skillhub install tencent-docs` + WorkBuddy 连接器面板启用

---

## 快速开始

### 前提条件

```bash
# 1. 安装腾讯会议 CLI
npm install -g @tencentcloud/tmeet@latest

# 2. 登录授权
tmeet auth login 2>&1 &
# → 复制输出的授权 URL，在浏览器中打开完成登录

# 3. 确认登录成功
tmeet auth status
```

### 安装 Skill

```bash
skillhub install tmeet-skill-pro
```

### 跑测试

```bash
# 全量测试（43 用例，零 CLI 依赖）
bash scripts/test-check-conflict.sh      # 13 用例
bash scripts/test-transfer-invitees.sh   # 8 用例
bash scripts/test-fetch-records.sh       # 22 用例
```

---

## 文件结构

```
tmeet-skill-pro/
├── SKILL.md                    # 技能定义，AI 读取的入口
├── README.md                   # 本文件
├── DEVPLAN.md                  # 开发计划 & 设计原则
├── scripts/
│   ├── check-conflict.sh           # 批量创建冲突检测
│   ├── fetch-records.sh            # 跨会议录制内容消费
│   ├── transfer-invitees.sh        # 受邀人一键继承
│   ├── todo-kanban.sh              # 待办 JSON → 可拖拽 HTML 看板
│   ├── todo-to-sheet.sh            # 待办 JSON → 腾讯文档 sheet 参数
│   ├── todo-to-doc.sh              # 待办 JSON → Markdown 复盘报告
│   ├── test-check-conflict.sh      # 测试 (13 用例)
│   ├── test-fetch-records.sh       # 测试 (22 用例)
│   ├── test-fetch-records-data.json
│   ├── test-transfer-invitees.sh   # 测试 (8 用例)
│   └── test-transfer-invitees-data.json
└── references/                 # CLI 命令参考 + 增强工作流文档
    ├── tmeet-auth.md
    ├── tmeet-meeting.md
    ├── tmeet-record.md
    ├── tmeet-contact.md
    ├── tmeet-control.md
    ├── tmeet-report.md
    └── tmeet-tshoot.md
```

---

## 设计原则

- **只做确定性计算**：时间交集、翻页遍历、ID 链传递 — AI 擅长语义、不擅长这些
- **stdin→stdout**：每个脚本独立可运行，JSON 进、Markdown/JSON 出
- **不重复造轮子**：全部能力基于官方 tmeet CLI，脚本只是编排层

---

## License

MIT

## 作者

[Moray](https://github.com/CoderMoray)
