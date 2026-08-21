# Meowa API 调用规范

## 1. 目的与边界

Meowa 用于开发期生成或处理地图、像素/高清图片、序列帧、UI、音效和音乐。它不进入 Godot
导出包，不参与游戏运行，不直接决定地图碰撞、战斗规则、存档或产品数据。

本规范同时约束 Meowa Skill、`meowart_api.py`、公开 API、网页工作区和任何间接调用方式。积分
包括体验积分、订阅积分和付费积分；即使余额来自赠送，也按扣分操作管理。

## 2. 默认策略

- 默认预算为 `0`。
- 先复用现有资源，再考虑本地裁切、重排、重着色、像素化、去噪或格式转换。
- 生成前冻结资产契约：用途、尺寸、数量、Alpha、帧数、FPS、锚点、格式和落盘位置。
- 一次只提交一个已批准命令。首个候选未验收前，不批量生成变体。
- 普通的“继续”“可以”“开始做”只授权继续当前开发工作，不授权消耗 Meowa 积分。

## 3. 操作分级

### 3.1 可直接执行的免费/只读操作

以下操作不创建新的收费生成 Job，可以在任务范围内执行：

- `credits-balance`
- `*-template-info`
- `map-reference-search`、`map-reference-download`
- `texture-reference-search`、`texture-reference-download`
- `video-prompt-list`、`custom-workflow-list`
- 已有 Job 的 `*-poll`、`*-history`、`*-download`
- 在用户意图明确时取消已有 Job 的 `*-cancel`
- 本地图片、音频、图集、帧数、Alpha、接缝和 Godot 导入验证

免费操作不得顺带提交生成任务。服务端价格或接口语义发生变化时，立即按未知价格处理。

### 3.2 必须逐次批准的扣分操作

所有 `*-run`、`*-submit` 和其他创建生成 Job 的操作默认视为扣分操作。提交前必须展示：

```text
用途：
Meowa 能力/命令：
输入资源：
生成数量：
输出契约：
预计积分：
本次最高积分：
失败后的处理：只恢复/轮询原 Job，不自动重提
```

有效批准应明确包含本次最高积分，例如：

```text
同意本次 Dual Grid 候选生成，最多消耗 10 点。
```

授权只覆盖一条提交命令和该命令创建的 Job。下列情况必须重新批准：

- 改提示词后重做；
- 增加图片、帧、音频或变体数量；
- 提升分辨率、模型质量或生成速度；
- 追加抠图、像素化、循环处理或其他收费后处理；
- 原 Job 失败、取消、丢失或结果不合格后重新提交。

### 3.3 默认阻止的操作

- Spine：项目没有 Godot Spine 运行时，公开 API 未提供完整稳定的定价与交付契约。
- `custom-workflow-run`：账户私有工作流的成本与输出上限不能由项目规则静态确认。
- `game-design-run`：按 token 实时增量扣费，不能可靠锁定单次最高积分。
- 任何未知命令、未知价格、无法计算最大输出数量或无法验证最终媒体的工作流。

需要使用这些能力时，先更新本规范和门禁代码，再获得用户针对该能力的单独批准。

## 4. 受控命令

免费操作示例：

```bash
python3 tools/run_meowa_guarded.py credits-balance
```

扣分操作必须同时提供人工预估、本次批准上限和可追溯批准说明：

```bash
python3 tools/run_meowa_guarded.py \
  --estimated-credits 15 \
  --approved-max-credits 15 \
  --approval-reference "用户在当前任务明确批准本次最多 15 点" \
  tileset-gen-run \
  --terrain-mode dual \
  --foreground-texture <foreground-64x64.png> \
  --background-texture <background-64x64.png> \
  --output-dir <candidate-output-dir>
```

提交前先用 `--dry-run` 检查门禁，不调用外部接口：

```bash
python3 tools/run_meowa_guarded.py \
  --dry-run \
  --estimated-credits 15 \
  --approved-max-credits 15 \
  --approval-reference "用户在当前任务明确批准本次最多 15 点" \
  tileset-gen-run --terrain-mode dual --output-dir <candidate-output-dir>
```

门禁只防止误调用，不能替代代理规则。不得为了通过门禁虚报预计积分、伪造批准说明或拆分命令规避
批次上限。

## 5. 成本核对

每次提交前重新读取 [Meowa API 文档](https://meowa.ai/api-docs) 和当前 Skill 参数。2026-08-21
文档中的典型价格仅用于初步估算：

| 能力 | 典型积分 |
|---|---:|
| Dual Grid 双材质 Tileset | 服务端本次实扣 10；项目仍按 15 点上限申请批准 |
| 自循环纹理 | 20 |
| 普通动画 | 30 / 40 / 50 |
| 关键帧动画 | 40 / 50 / 60 |
| 音效 | 每个生成秒 5 |
| 音乐试听 / 完整音频 | 25 / 50 |

价格变化、按数量累乘、后处理加价和服务端实际计费均以提交前的最新文档为准。无法确定时不得提交。

> 2026-08-21 计费校准：Map01 的 `tileset-gen-run --terrain-mode foreground`
> 搭配 `--remove-bg-method standard` 在旧文档估算和用户批准上限均为
> 10 点时，服务端实际扣除 15 点。此后项目统一按至少 15 点估算 Tileset；
> `tools/run_meowa_guarded.py` 会拒绝低于 15 点的 `tileset-gen-run` 与
> `tileset-gen-submit`。同日 Map01 双材质 `dual` 任务实际扣除 10 点，说明
> 不同模式的服务端扣费可能不同；在价格契约稳定前，每次仍须取得覆盖 15 点的
> 逐次明确批准，实际扣分按生成前后余额记录。

## 6. 产物与验收

- 原始输出和 `final_outputs.json` 保存到 `art/source_archive/meowa/<asset-id>/<date>/`。
- 待审图保存到 `art/candidates/`，不得直接覆盖正式资源。
- 像素图检查原生尺寸、有限色盘、硬 Alpha、nearest 显示和整数缩放。
- Dual Grid 检查图块顺序、四角掩码、接缝、单格、孔洞和两种对角，再转换为 TileMapDual 资源。
- 序列帧检查帧数、网格、锚点、循环边界和透明通道，再创建 Godot `SpriteFrames`；不使用
  `AnimatedTexture` 代替固定网格动画。
- 音频检查格式、时长、响度、裁切、尾音和循环点，再接入 Godot Audio Bus。
- 自动验证通过不代表美术定稿。只有用户视觉确认后才能晋升到 `assets/`。

## 7. 密钥与日志

- `MEOWART_API_KEY` 只从环境变量或本地 `.env` 读取，不通过命令参数传递。
- `.env` 必须被 Git 忽略，并建议设置为 `chmod 600 .env`。
- 不打印、转述、截图或保存密钥，不把密钥放进 Markdown、JSON、场景、资源或 Job 日志。
- 扣分调用由门禁写入 `art/source_archive/meowa/api_spend_ledger.jsonl`，只记录时间、命令、批准
  上限、预估积分、脱敏参数和退出状态。
- 任务超时后保存 Job ID，继续轮询原 Job；不得因下载失败或旧 Skill 不兼容而重新付费提交。
