# tmeet-skill-pro 开发计划

> **当前版本**：v0.0.3（已发布至 SkillHub，slug: `tmeet-skill-pro`）
> **项目根目录**：`~/Desktop/Moray/MyOpenSource/腾讯会议增强/skills/tmeet-skill-pro/`

---

## 一、已完成

### v0.0.1 ~ v0.0.3 内容

| 能力 | 实现方式 | 说明 |
|------|---------|------|
| **官方 tmeet-skill 全部能力** | 继承自 `connectors-marketplace/connectors/tmeet/skills/` | 会议管理、录制、通讯录、会中控制、反馈 |
| **方向 1：智能日程编排** | `scripts/check-conflict.sh` | stdin 接日程 JSON → 按日期分组调 `tmeet meeting list` → 时间交集检测 → 输出冲突报告 |
| **方向 2：录制深度消费** | `scripts/fetch-records.sh` | stdin 接查询条件 → `list-ended` + 关键词过滤 → `record list` → `transcript-get`/`smart-minutes` → 合并 Markdown。支持 transcript-search 关键词搜索 + 上下文窗口 + 区间合并。支持 `todo_only` 模式提取 @负责人 待办 |
| **方向 3：受邀者继承** | `scripts/transfer-invitees.sh` | 源 meeting_id → 自动翻页 `invitees-list` → 提取 open_id → `invitees-add` |
| **待办看板** | `scripts/todo-kanban.sh` | 待办 JSON → 自包含 HTML 看板（三栏拖拽 + 筛选 + 撤销重做 + 新增卡片） |
| **腾讯文档同步** | `scripts/todo-to-sheet.sh` / `scripts/todo-to-doc.sh` | 待办 JSON → sheet values 数组或 Markdown 报告。依赖 `tencent-docs` MCP 连接器写入，AI 只做 base64 编码 + 一次 MCP 调用 |

### 文件结构

```
tmeet-skill-pro/
├── SKILL.md                    # slug: tmeet-skill-pro, v0.0.3
├── README.md
├── DEVPLAN.md
├── scripts/
│   ├── check-conflict.sh        # 13/13 单元测试通过 + 真实 CLI 集成通过
│   ├── fetch-records.sh          # 批量捞转写/纪要 + 关键词搜索，合并 Markdown（22 用例）
│   ├── transfer-invitees.sh      # 受邀人自动转移，Python HEREDOC 重写，支持 mock（8 用例）
│   ├── todo-kanban.sh              # 待办 JSON → 可拖拽 HTML 看板
│   ├── todo-to-sheet.sh            # 待办 JSON → 腾讯文档 sheet values 数组
│   ├── todo-to-doc.sh              # 待办 JSON → Markdown 复盘报告
│   ├── test-check-conflict.sh    # 冲突检测单元测试（mock，13 用例）
│   ├── test-fetch-records.sh     # 录制消费单元测试（mock，22 用例）
│   ├── test-fetch-records-data.json
│   ├── test-transfer-invitees.sh  # 受邀人转移单元测试（mock，8 用例）
│   └── test-transfer-invitees-data.json
└── references/
    ├── tmeet-auth.md
    ├── tmeet-meeting.md          # 末尾新增「批量创建」和「受邀者继承」小节
    ├── tmeet-record.md           # 末尾新增「批量录制消费」小节
    ├── tmeet-contact.md
    ├── tmeet-control.md
    ├── tmeet-report.md
    └── tmeet-tshoot.md
```

### 关键发现

- **会议参数模板（方向 4）**：已放弃。AI 本来就在填 CLI 参数，JSON 预设无额外价值。
- **脚本定位原则**：只做 AI 不擅长的确定性计算（时间交集、分页遍历、ID 提取），不做语义理解。
- **SKILL.md 原则**：增强能力写在对应的 `references/tmeet-xxx.md` 中与相关原生命令平级，不在 SKILL.md 堆大段 workflow 描述。
- **tmeet CLI 路径**：WorkBuddy 的沙箱环境下 tmeet 不在 `PATH`，脚本需自动探测（所有脚本均已内置）。
- **测试策略**：单元测试用 `--data-file` mock 模式（零 API 调用），集成测试用真实 tmeet CLI + 真实账号。
- **录制相关 CLI 实际行为**（v0.0.2 实测）：
  - `record list` 直接返回 `record_file_id`，无需经过 `record address`（pipeline 从 5 步简化为 4 步）
  - transcript 一场 56 分钟会议约 334KB，`max_meetings` 默认值 5
  - `report participants` 非发起人返回 9042 无权限，不存在授权机制
  - `transcript-search` 返回命中 pid/sid/offset，需 `transcript-get --pid --limit` 取原文
- **SkillHub 搜索机制**（v0.0.2 实测）：不索引 `description` 字段，仅匹配 `slug` + `displayName`。需将核心关键词放入 `displayName`。
- **待办提取**（v0.0.3）：正则匹配「- task。 @owner」模式，5 行代码。`smart-minutes` 纪要尾部有标准化待办格式。
- **腾讯文档集成**（v0.0.3）：MCP 支持 sheet（在线表格）和 doc（文档）两种产物。不推荐 smartsheet（默认字段干扰 + MCP 不支持配置看板分组）。写入前由 `todo-to-sheet.sh`/`todo-to-doc.sh` 生成标准化格式，AI 只需 base64 编码 + 一次 MCP 调用。

---

## 二、待开发方向

### 方向 5：会中控制上下文感知

**场景**：「把会议室里所有外部嘉宾踢掉」「把没开摄像头的人都踢了」

**当前状态**：
- `report participants` 对非发起人返回 9042 无权限，但发起人可以调用
- 返回字段仍未实测（人员信息、设备状态、组织归属等）
- **下一步**：以一个发起人身份调 `report participants` 看完整字段，判断方向可行性

### 方向 6：反馈闭环

`tmeet tshoot feedback` 是单向上报，无状态查询 API。除非平台提供反馈状态接口，否则不可行。

---

## 三、知识依赖

### 发布流程

1. 修改 Desktop 项目目录的 SKILL.md（改版本号、changelog 等）
2. 运行 `skillhub publish ./tmeet-skill --changelog "..." --version x.x.x`
3. 如果 skillhub token 过期：`skillhub auth login --token skh_xxx`

### 本地测试

tmeet CLI 安装位置（WorkBuddy 管理的 Node）：
```
~/.workbuddy/binaries/node/versions/22.22.2/bin/tmeet
```

真实 CLI 测试前需登录：
```bash
~/.workbuddy/binaries/node/versions/22.22.2/bin/tmeet auth login --no-browser
```

脚本自动探测此路径（所有脚本均已内置）。

### tmeet CLI 官方文档（references/ 目录）

| 文件 | 内容 |
|------|------|
| `tmeet-meeting.md` | create/update/cancel/get/list/list-ended/invitees-* |
| `tmeet-record.md` | list/address/smart-minutes/transcript-*/permission-* |
| `tmeet-report.md` | participants/waiting-room-log |
| `tmeet-contact.md` | search/lookup-by-phone/lookup-by-email |
| `tmeet-control.md` | call/kick |
| `tmeet-tshoot.md` | log/feedback |
| `tmeet-auth.md` | login/logout/status |
