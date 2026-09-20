# 配套泥土纹理（待单次额度批准）

- 用途：作为已批准石铺地纹理的背景材质，供后续等角双材质地块集使用。
- 命令：通过 tools/run_meowa_guarded.py 执行 texture-gen-run --self-loop。
- 输入：以下文字提示词；当前CLI不传参考图，以文字约束色调，实际匹配需检查。
- 数量：1个Job、1张泥土纹理候选及服务端随附平铺预览，不追加变体。
- 输出：目标64×64正俯视像素PNG，完全不透明、铺满画布；下载核验真实尺寸及3×3重复平铺。
- 预计积分20，本次最高20。单次授权尚未取得；此前的纹理20积分授权已使用。
- 落盘：art/candidates/camp-orthographic-slice/meowa-dirt-texture-v1/。
- 不包含后续等角地块集生成。失败只恢复原Job，不自动重提。

## 提示词

Top-down pixel-art texture of compacted gray-brown earth in an ancient mountain settlement, to sit beside muted warm gray-brown stone paving. Fine soil grain with sparse tiny gravel, low contrast, slightly darker than the paving so the stone path remains readable. Fill the entire 64 by 64 square with opaque earth and compatible edges for seamless repetition. No large rocks, paving slabs, grass, moss, plants, footprints, ruts, border, perspective, or cast shadows.

费用依据：Meowa官方API文档 texture_gen 开启self_loop为20积分。
