# tmeet-skill-pro

腾讯会议 CLI 增强版 — 在官方 tmeet-skill 基础上新增：批量创建+冲突检测、录制深度消费（跨会议转写/纪要汇总）、受邀者继承。

## 增强功能

### 1. 智能批量创建 + 冲突检测
一句话批量创建会议，自动检测时间冲突。

```
用户: "下周一到周五每天上午9点安排站会，跳过周三"
AI:  解析 → scripts/check-conflict.sh 冲突检测 → 展示报告 → 逐条创建
```

### 2. 录制深度消费
跨会议批量获取转写/纪要，合并输出供 AI 语义分析。支持全文模式和关键词搜索模式（带上下文窗口、区间合并）。

```
用户: "过去一个月所有面试的转写汇总一下"
AI:  构造查询 → scripts/fetch-records.sh → Markdown 合并文本 → AI 分析回答

用户: "谁在最近的周会里提过延期"
AI:  构造查询(search_text="延期") → scripts/fetch-records.sh → 命中段落+上下文 → AI 分析回答
```

### 3. 受邀者继承
从历史会议一键复制受邀人列表到新会议。

```
用户: "把上次项目复盘会的受邀人拉进这次会议"
AI:  匹配会议 → scripts/transfer-invitees.sh 自动翻页提取 → 添加受邀人
```

## 文件结构

```
tmeet-skill-pro/
├── SKILL.md                         # 主技能定义
├── README.md                        # 本文件
├── DEVPLAN.md                       # 开发计划
├── scripts/
│   ├── check-conflict.sh            # 批量会议冲突检测
│   ├── fetch-records.sh             # 跨会议录制内容消费
│   ├── transfer-invitees.sh         # 受邀人自动转移
│   ├── test-check-conflict.sh       # 冲突检测单元测试 (13 用例)
│   ├── test-fetch-records.sh        # 录制消费单元测试 (22 用例)
│   ├── test-fetch-records-data.json # 录制消费 mock 数据
│   ├── test-transfer-invitees.sh     # 受邀人转移单元测试 (8 用例)
│   └── test-transfer-invitees-data.json
└── references/
    ├── tmeet-auth.md
    ├── tmeet-meeting.md             # 含批量创建和受邀者继承工作流
    ├── tmeet-record.md              # 含批量录制消费工作流
    ├── tmeet-contact.md
    ├── tmeet-control.md
    ├── tmeet-report.md
    └── tmeet-tshoot.md
```

## 依赖

- `tmeet` CLI (`npm install -g @tencentcloud/tmeet`)
- `python3`

## 安装

```bash
skillhub install tmeet-skill-pro
```

## 版本

v0.0.3 — 基于官方 tmeet-skill，新增三个增强脚本、关键词搜索、完整测试覆盖。
