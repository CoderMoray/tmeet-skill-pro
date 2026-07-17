# tmeet record — 录制管理

> **前置条件：** 先执行 `tmeet auth login` 完成登录授权。

时间参数格式：`2026-03-12T14:00:00+08:00` 或 `2026-03-12T14:00+08:00`（必须包含时区）。

---

## list — 查询录制列表

```bash
# 按会议 ID 查询
tmeet record list --meeting-id "100000000"

# 按会议码查询
tmeet record list --meeting-code "123456789"

# 按时间范围查询
tmeet record list \
  --start "2026-04-01T00:00:00+08:00" \
  --end "2026-04-30T23:59:59+08:00"

# 组合使用：会议 ID + 时间范围（进一步缩小结果范围）
tmeet record list \
  --meeting-id "100000000" \
  --start "2026-04-01T00:00:00+08:00" \
  --end "2026-04-30T23:59:59+08:00"

# 分页查询（使用 page-token翻下一页）
tmeet record list \
  --meeting-id "100000000" \
  --page-token "<next_page_token>" \
  --page-size 30
```

### 参数

| 参数 | 必填 | 默认值 | 说明                                             |
|------|------|--------|------------------------------------------------|
| `--meeting-id <id>` | 至少一组 | — | 会议 ID                                          |
| `--meeting-code <code>` | 至少一组 | — | 会议码                                            |
| `--start <time>` + `--end <time>` | 至少一组 | — | 时间范围（ISO 8601，含时区，建议 `--start` 与 `--end` 同时提供） |
| `--page-token <token>` | 否 | — | 分页游标，首页不传；后续翻页传入上一次响应的 `next_page_token` |
| `--page-size <n>` | 否 | `30` | 每页数量，默认 30，最大 30 |
| `--page <n>` | 否 | — | ⚠️ **已弃用**：页码（从 1 开始），请改用 `--page-token` |

> `--meeting-id`、`--meeting-code`、`--start + --end` 三组**至少提供一组**，多组可叠加使用以缩小查询范围。

---

## address — 获取录制文件下载地址

```bash
# 获取录制文件下载地址
tmeet record address --meeting-record-id "record_abc123"

# 分页获取（翻下一页）
tmeet record address \
  --meeting-record-id "record_abc123" \
  --page-token "<next_page_token>" \
  --page-size 30
```

### 参数

| 参数 | 必填 | 默认值 | 说明                             |
|------|------|--------|--------------------------------|
| `--meeting-record-id <id>` | ✅ | — | 会议录制 ID（从 `record list` 结果中获取） |
| `--page-token <token>` | 否 | — | 分页游标，首页不传；后续翻页传入上一次响应的 `next_page_token` |
| `--page-size <n>` | 否 | `30` | 每页数量，默认 30，最大 30 |
| `--page <n>` | 否 | — | ⚠️ **已弃用**：页码（从 1 开始），请改用 `--page-token` |

---

## smart-minutes — 获取智能纪要

```bash
# 获取录制文件的智能纪要（默认原文）
tmeet record smart-minutes --record-file-id "file_abc123"

# 获取中文翻译版纪要
tmeet record smart-minutes \
  --record-file-id "file_abc123" \
  --lang zh

# 带访问密码的录制文件
tmeet record smart-minutes \
  --record-file-id "file_abc123" \
  --pwd "123456"
```

### 参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `--record-file-id <id>` | ✅ | — | 录制文件 ID（从 `record address` 结果中获取） |
| `--lang <lang>` | 否 | `default` | 语言：`default`-原文，`zh`-简体中文，`en`-英文，`ja`-日语 |
| `--pwd <pwd>` | 否 | — | 录制文件访问密码 |

---

## transcript-get — 获取转写详情

```bash
# 获取转写详情
tmeet record transcript-get --record-file-id "file_abc123"

# 指定起始段落 ID 与查询段落数
tmeet record transcript-get \
  --record-file-id "file_abc123" \
  --meeting-id "100000000" \
  --pid "<paragraph_id>" \
  --limit "30"
```

### 参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `--record-file-id <id>` | ✅ | — | 录制文件 ID |
| `--meeting-id <id>` | 否 | — | 会议 ID |
| `--pid <id>` | 否 | — | 查询的起始段落 ID |
| `--limit <n>` | 否 | — | 查询的段落数 |

---

## transcript-paragraphs — 获取转写段落列表

```bash
# 获取转写段落列表
tmeet record transcript-paragraphs --record-file-id "file_abc123"

# 指定会议 ID
tmeet record transcript-paragraphs \
  --record-file-id "file_abc123" \
  --meeting-id "100000000"
```

### 参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `--record-file-id <id>` | ✅ | — | 录制文件 ID |
| `--meeting-id <id>` | 否 | — | 会议 ID |

---

## transcript-search — 搜索转写内容

```bash
# 在转写内容中搜索关键词
tmeet record transcript-search \
  --record-file-id "file_abc123" \
  --text "季度目标"

# 指定会议 ID 搜索
tmeet record transcript-search \
  --record-file-id "file_abc123" \
  --meeting-id "100000000" \
  --text "行动项"
```

### 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| `--record-file-id <id>` | ✅ | 录制文件 ID |
| `--text <keyword>` | ✅ | 搜索关键词 |
| `--meeting-id <id>` | 否 | 会议 ID |

---

## permission-apply-prepare — 预览录制权限申请

当调用 `record address` / `record smart-minutes` / `record transcript-*` 等命令返回 **无权限** 错误时，先调用本命令拉取审批文案、会议主题、录制所有者等预览信息，**展示给用户二次确认后**，再调用 `record permission-apply-commit` 真正提交申请。

```bash
# 预览录制权限申请信息
tmeet record permission-apply-prepare --meeting-record-id "record_abc123"

# 同时指定会议 ID
tmeet record permission-apply-prepare \
  --meeting-record-id "record_abc123" \
  --meeting-id "100000000"
```

### 参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `--meeting-record-id <id>` | ✅ | — | 会议录制 ID |
| `--meeting-id <id>` | 否 | — | 会议 ID |

### 响应关键字段

| 字段 | 说明 |
|------|------|
| `preview.meeting_record_id` | 会议录制 ID |
| `preview.approval_name` | 申请类型文案 |
| `preview.subject` | 会议标题 |
| `preview.file_owner` | 录制所有者名称 |
| `preview.apply_note` | 权限申请备注信息 |
| `preview.applicant` | 申请人名称 |
| `expires_in` | 过期时间（秒），超过后需重新 prepare |

---

## permission-apply-commit — 提交录制权限申请

> **写操作 · 必须二次确认**：本命令会正式发起审批流程。**必须先调用 `permission-apply-prepare` 拉取预览信息**，将申请类型 / 会议标题 / 录制所有者 / 申请备注等关键字段完整展示给用户，**待用户明确同意后再调用本命令**。

```bash
# 提交录制权限申请
tmeet record permission-apply-commit --meeting-record-id "record_abc123"

# 同时指定会议 ID
tmeet record permission-apply-commit \
  --meeting-record-id "record_abc123" \
  --meeting-id "100000000"
```

### 参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `--meeting-record-id <id>` | ✅ | — | 会议录制 ID（必须与 `permission-apply-prepare` 一致）|
| `--meeting-id <id>` | 否 | — | 会议 ID |

### 响应关键字段

| 字段 | 说明 |
|------|------|
| `unique_id` | 申请 ID |
| `status` | 审批状态 |
| `message` | 审批状态描述 |
| `approval_url` | 审批链接（可展示给用户跟踪审批进度）|
| `share_text` | 申请说明描述（可分享给审批人）|

---

## 典型工作流

```
1. 查询录制列表，获取 meeting_record_id
   tmeet record list --meeting-id "..."

2. 获取录制文件下载地址，获取 record_file_id
   tmeet record address --meeting-record-id <meeting_record_id>

3. 获取智能纪要 / 转写内容
   tmeet record smart-minutes --record-file-id <record_file_id>
   tmeet record transcript-get --record-file-id <record_file_id>
   tmeet record transcript-search --record-file-id <record_file_id> --text "关键词"
```

### 无录制权限时的申请流程

当 `record address` / `record smart-minutes` / `record transcript-*` 等命令返回 **无权限** 错误时，按以下流程发起权限申请：

```
1. 调用 prepare 获取预览信息
   tmeet record permission-apply-prepare --meeting-record-id <meeting_record_id>

2. 将 preview 中的「申请类型 / 会议标题 / 录制所有者 / 备注 / 申请人」完整展示给用户，
   并明确询问是否同意发起权限申请；

3. 收到用户明确确认（"确认"/"是"/"yes" 等肯定指令）后，再调用 commit 提交申请：
   tmeet record permission-apply-commit --meeting-record-id <meeting_record_id>

4. 将 commit 响应中的 approval_url 展示给用户跟踪审批进度；
   若用户未明确确认或表示取消，则终止流程，不得调用 commit。
```

> **重要**：`permission-apply-commit` 为写操作，**严禁在未经用户确认时直接执行**。`prepare` 返回的 `expires_in` 过期后，需重新调用 `prepare` 拉取最新预览再确认提交。

## 常见错误

| 错误现象 | 原因 | 解决方案 |
|---------|------|---------|
| `one of the following groups is required` | 缺少必填参数组 | 提供 `--meeting-id`、`--meeting-code` 或 `--start + --end` 其中一组 |
| `--start format error` | 时间格式不合法（如缺少时区） | 改用 `2026-03-12T14:00:00+08:00` 格式 |
| `--record-file-id is required` | 缺少必填参数 | 先通过 `record list` + `record address` 获取 |
| `--text is required` | 搜索缺少关键词 | 补充 `--text` |
| `record address` / `smart-minutes` / `transcript-*` 返回无权限 | 当前用户对该录制无访问权限 | 先 `permission-apply-prepare` 预览，经用户确认后再 `permission-apply-commit` 申请 |

## 参考

- [tmeet](../SKILL.md) — 全部命令概览
- [tmeet-meeting](tmeet-meeting.md) — 会议管理
- [tmeet-report](tmeet-report.md) — 会议报告

## 批量录制消费

> **辅助脚本**：`scripts/fetch-records.sh`

跨会议批量获取转写/纪要内容，合并为 Markdown 供 AI 做语义分析。

### 输入

stdin 传入 JSON 查询条件：

```json
{
  "start": "2026-07-01",
  "end": "2026-07-31",
  "keyword": "面试",
  "max_meetings": 5,
  "content_type": "transcript",
  "reference_date": "2026-07-17"
}
```

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `start` / `end` | ✅ | — | 查询时间范围（YYYY-MM-DD），最长 31 天 |
| `keyword` | 否 | — | 按 meeting subject 关键词过滤 |
| `max_meetings` | 否 | 5 | 最多处理的会议数（转写数据量较大，建议不超过 10） |
| `content_type` | 否 | `transcript` | `transcript`-逐字转写 / `minutes`-AI 纪要 |
| `search_text` | 否 | — | 在转写内容中搜索的关键词，启用搜索模式（仅 `transcript` 模式有效） |
| `context_paragraphs` | 否 | 2 | 搜索模式下每个命中段前后包含的段落数 |
| `todo_only` | 否 | `false` | 仅提取待办（@负责人），输出 JSON。强制 `content_type=minutes`，静默模式（无 Markdown 头） |
| `reference_date` | 否 | — | AI 计算日期时的参考锚点，用于校验。当 AI 的计算依赖"今天"时必传 |

### 输出

合并 Markdown 文本（stdout），每场会议包含：

- 会议号、主题、时间、类型、时长
- 录制状态（云录制/本地录制/无录制/转码状态）
- 参会人（发起人可获取完整列表，否则显示提示文案）
- 发言人（转写模式自动提取去重）
- 转写/纪要全文

### 典型用法

```bash
# 全文转写
echo '{"start":"2026-06-01","end":"2026-07-01","keyword":"面试","content_type":"transcript"}' | scripts/fetch-records.sh

# 关键词搜索 + 上下文窗口
echo '{"start":"2026-06-01","end":"2026-07-01","keyword":"周会","content_type":"transcript","search_text":"延期","context_paragraphs":2}' | scripts/fetch-records.sh

# 仅提取待办（输出 JSON）
echo '{"start":"2026-07-01","end":"2026-07-17","todo_only":true}' | scripts/fetch-records.sh
```

### 跨会议待办看板

`fetch-records.sh --todo-only` 提取 JSON 后，用 `todo-kanban.sh` 生成自包含 HTML 看板：

```bash
echo '{"start":"2026-07-01","end":"2026-07-17","todo_only":true}' \
  | scripts/fetch-records.sh \
  | scripts/todo-kanban.sh \
  > outputs/kanban.html
```

**HTML 可直接浏览器打开**，支持三栏拖拽、筛选（会议/负责人/日期）、撤销重做、手动新增卡片。

**AI 生成后必须主动让用户查看**：
- 优先用当前客户端内置的预览/展示工具（如 WorkBuddy 的 `present_files`）
- 没有内置工具则尝试系统命令唤起浏览器（如 `open`/`start`/`xdg-open`）
- 都不行则告知文件绝对路径，请用户用浏览器打开
- 生成完立刻执行，不要等用户催

### 腾讯文档同步（需用户显式要求）

仅在用户明确说「同步到腾讯文档」时才走此路径。定位是**会议数据云端备份**——把待办、纪要、转写等沉淀到腾讯文档，方便团队共享和历史检索。

**前置条件**：`tencent-docs` 连接器已安装并启用（`skillhub install tencent-docs` + 连接器面板连接）。未安装则提示用户。

**AI 可按需调整模板**，但默认使用以下标准格式。

---

#### 模板一：在线表格（待办追踪）

推荐 `file_type: "sheet"`，不用智能表格（自带干扰字段 + 看板配置缺失）。

| 列 | A | B | C | D | E |
|------|---|---|---|---|---|
| 表头 | 待办内容 | 负责人 | 来源会议 | 日期 | 状态 |
| 默认值 | — | — | — | — | 待开始 |

AI 操作：
1. `fetch-records.sh --todo-only` 拿 todo JSON
2. `todo-to-sheet.sh` 转成 MCP values 数组
3. `manage.create_file(file_type:"sheet")` 创建表格 → 得到 `file_id` + `url`
4. `sheet.get_sheet_info` 拿 `sheet_id`
5. `sheet.set_range_value(values=<第2步输出>)` 写入
6. 返回链接
5. 返回链接

可选增强（AI 自行判断）：
- 按会议分组用空行分隔
- 行首加 checkbox（`☐ ` 前缀）
- 状态列用下拉选项替代文本
- 会议综述、负责人汇总等附属 sheet

---

#### 模板二：在线文档（会议复盘报告）

推荐 `file_type: "doc"`，用 `todo-to-doc.sh` 生成 Markdown，AI 只需 base64 编码后写入。

AI 操作：
1. `fetch-records.sh --todo-only | todo-to-doc.sh` 生成 Markdown
2. 对输出做 base64 编码
3. `doc.create_with_markdown(title="...", base64_markdown=<编码>)` 创建文档
4. 返回链接

报告模板（由脚本自动生成）：标题、日期、待办表格、会议来源列表、脚注。

**AI 加工指引**。脚本输出是标准骨架，AI 应在此基础上按用户需求润色后写入：

- **标题**：从默认「跨会议待办复盘报告」改为用户语境标题（如「Q3 排班项目跟进」「本周面试复盘」）
- **摘要**：如果有完整纪要数据，追加 `## 核心摘要` 段落，提炼 3-5 条结论
- **分组**：待办较多时，用 `### 按负责人分组` 重新组织，而非单一大表
- **精简**：用户说「只看摘要」，删掉表格只保留结论段落
- **语气**：正式汇报 vs 内部速记，调整措辞

遵循优先级：用户显式要求 > 合理推断 > 默认模板。

---

**模板不是锁死的**。AI 看到用户有具体要求（如「只给我 XX 负责人的」「要带截止时间」「按优先级高低排序」）时，应在标准模板基础上调整列数、分组方式、文案风格。

### 注意事项

- `record list` 已直接返回 `record_file_id`，无需经过 `record address`
- `report participants` 仅会议发起人及主持人/联席主持人可调用，非发起人自动跳过
- `transcript-get` 自动处理分页，逐段拼接
- `transcript-search` 搜索后自动区间合并去重，避免重复取段落
- `meeting list-ended` 最大时间范围 31 天
