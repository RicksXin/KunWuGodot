# 下一次 Meowa 提交草案（已授权并完成单次提交）

- 用途：验证营地石铺地与泥土的双材质过渡，改善首份样本的草绿色边带、青蓝描边和过强波瓣。
- 命令：通过 `tools/run_meowa_guarded.py` 执行 `isometric-tileset-run --terrain-mode dual`，普通速度，一次一个 Job。
- 输入：以下文字提示词与服务端 Dual Grid 模板；不上传整张营地或已拼好的图集。此次属于文字驱动的过渡样本，不承诺精确复制原纹理。
- 数量：1 组等角地块集，不追加变体或收费后处理。
- 输出目标：与用户首份样本一致的 2:1 等角、4×4 排列、每格 128×64、512×256 RGBA PNG；下载后核验模板顺序、实际尺寸及透明度，不满足则不接入。静态单帧，无动画；预览统一采用菱形中心锚点。
- 落盘：`art/candidates/camp-orthographic-slice/meowa-stone-dirt-v2/`，保留原始产物与 Job 信息。未经视觉批准不进入正式 assets。
- 费用：2026-09-17 官方 API 文档标注普通 dual 模式 10 点；项目依据历史计费差异按 15 点预算申请。本次最高 15 点，须单独获得用户批准。
- 失败处理：只轮询、恢复或下载原 Job，不自动重提。
- 限制：当前 CLI 未暴露网页的“边缘腐蚀”开关，因此只能用提示词约束过渡，不能声称已关闭开关。此样本验证标准 2:1 投影，不代表此前 35°/15°试制投影已获替换批准。
- 账户：本机 API Key 的只读余额为 1960；网页页头显示 394，两者不一致，原因未确认。若提交会使用本机 Key 对应账户。

## 提示词

Create a pixel-art dual-grid isometric terrain tileset with exactly two terrain materials. Foreground: old weathered gray-brown stone paving, irregular but mostly flat stones, restrained cracks, muted warm gray, low contrast. Background: compacted gray-brown earth with sparse tiny gravel, subdued saturation. A grounded ancient mountain settlement aesthetic. Preserve the supplied template masks and tile layout exactly. Keep transitions restrained and natural with small chipped edges; avoid exaggerated circular lobes. No grass, moss, plants, green bands, cyan outlines, blue borders, decorative rims, buildings, cliffs, objects, shadows cast across tile boundaries, text, or water. Consistent texture scale and lighting across all tiles. Seamless compatible neighboring edges. Transparent outside each isometric tile footprint.

官方契约与价格：<https://meowa.ai/api-docs#post-api-workflows-isometric_tileset_gen-run>

## 执行结果

用户已明确批准最高15积分，门禁dry-run通过后提交一次，成功下载。余额减少10积分；详细核验及Job见候选目录validation.json。本次授权已使用，不延续至下一轮。
