# 方向 5 字段探测 — 测试方案

> 目的：确认 `tmeet report participants` 返回哪些字段，判断「踢外部嘉宾」「踢没开摄像头的人」是否可行。

## 测试环境准备

**发起人**：Moray（当前 CLI 登录用户）
**参会人**：至少 1 人，越多越好
**会议要求**：
- 会议时长 > 5 分钟
- 最好包含不同类型的参会人：企业内成员、外部嘉宾、开摄像头/不开摄像头的

## 测试步骤

### Step 1：创建会议（Moray 操作）

在终端执行：

```bash
tmeet meeting create \
  --subject "方向5字段探测" \
  --start "2026-07-18T10:00:00+08:00" \
  --end "2026-07-18T10:15:00+08:00"
```

记下返回的 meeting_id。

### Step 2：入会

所有参会人（包括 Moray）进入会议。建议：
- Moray：开麦、开摄像头（主持人）
- 参会人 A：企业内成员，开麦
- 参会人 B（如有）：外部嘉宾，关摄像头

### Step 3：会中查询（会议进行中）

```bash
tmeet report participants --meeting-id <meeting_id> --format json-pretty
```

### Step 4：会议结束后查询

等待会议自然结束，再次执行 Step 3。

## 需要观察的关键字段

| 字段 | 期望值示例 | 用途 |
|------|-----------|------|
| `ms_open_id` | `"abc123..."` | `control kick` 的入参 |
| `is_enterprise_user` | `true` / `false` | 区分内外成员 |
| `user_name` | `"张三"` | 展示给用户确认 |
| `audio_state` | `0` / `1` | 判断是否开麦 |
| `video_state` | `0` / `1` | 判断是否开摄像头 |
| `instanceid` | `1` / `2` / `4` | 设备类型（PC/Mac/iPhone） |
| `join_time` / `left_time` | 时间戳 | 判断是否仍在会中 |

## 预期结论

| 场景 | 需要的字段 | 是否可行 |
|------|-----------|:--:|
| 「踢掉所有外部嘉宾」 | `is_enterprise_user==false` + `ms_open_id` | 待确认 |
| 「把没开摄像头的人都踢了」 | `video_state==0` + `ms_open_id` | 待确认 |
| 「把 10 分钟前入会的人都踢了」 | `join_time` + `ms_open_id` | 待确认 |

## 执行人

Moray 约定一位参会人后，通知 WorkBuddy 执行 Step 3。
