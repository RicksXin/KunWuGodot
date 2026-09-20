# 石铺地纹理生成提案（本次已批准并完成）

- 用途：给营地石铺地/泥土过渡图集提供清楚的石块纹理，替代上一轮文字生成中过平的灰土地表现。
- 能力：门禁执行 `texture-gen-run --self-loop`。
- 输入：纯文字提示词；不上传用户文件。
- 数量：1个Job、1张纹理候选；服务可能另交付自循环版本，均保留在同一任务，不另提交生成。
- 输出目标：64×64正俯视像素纹理PNG，无透明留白，四边可平铺。官方self-loop另含512×512四向自循环处理；实际返回文件、尺寸与平铺性下载后核验，不把512图直接当64图使用。
- 费用：2026-09-17官网 texture_gen 文档标价开启self_loop为20点，关闭为10点；本次开启，预计20，申请最高20积分。
- 落盘：`art/candidates/camp-orthographic-slice/meowa-stone-texture-v1/`。
- 验收：整数倍率查看单张及3×3平铺，检查石块可读性、重复、四边接缝、灰褐色调与无草/无蓝绿色描边。不通过不自动重提。
- 不包含下一次等角地块集生成；不得沿用上一轮15积分授权。

## 提示词

Top-down pixel-art texture of weathered gray-brown stone paving for an ancient mountain settlement. Flat irregular stones with clearly readable narrow dark seams, muted warm gray tones, subtle wear and restrained highlights. Stones should remain recognizable at 64 by 64 pixels. Fill the entire square with paving, with compatible edges for seamless repetition. No grass, moss, plants, cyan outlines, decorative border, perspective, or cast shadows.

价格依据：<https://meowa.ai/api-docs#post-api-workflows-texture_gen-run>

执行结果：用户明确批准最高20积分，已通过门禁提交一个Job并下载。余额减少20积分。真实主纹理64×64 RGBA、全不透明；验证记录见候选目录submission.json。本次授权已使用。
