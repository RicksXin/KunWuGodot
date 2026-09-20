# 议事殿同视角候选 · 单次提交方案

输入包：`art/candidates/camp-council-isometric/`。

- `references/01_identity.png`：现有议事殿，仅控制青灰重檐、深木柱、旧铜饰与石基，不控制旧正面视角。
- `references/02_geometry.png`：按当前运行灰盒生成的288×240透明几何参考，控制2:1正交投影、2×2占地、左侧可见墙门位。材质不作为美术参考。
- `references/03_context-review-only.png`和`geometry-review.png`：本地人工复核，不上传给生成器。
- `prompt.txt`、`submission-proposal.json`：完整提示词、输入哈希、数量、费用与失败处理。

选择：`pixel-gen-run`，官方已发现模板`xlarge_4_3`，单次默认1张，支持isometric方向，2K处理画布，512px级4:3像素产物。CLI按模板要求aspect-ratio 1:1、direction isometric、normal、standard背景移除。这里的2K是服务处理分辨率，不能当作最终建筑尺寸。

精确288×240自定义尺寸能力没有在当前公开价格页找到完整对应契约，因此本次不采用。固定模板的图像实际尺寸、透明度和占地需下载后检查；本地适配到288×240目标，前侧地面角锚点(144,224)。不能依靠提示词保证精确像素落点，不能为适配拉伸破坏投影；如果尺寸/结构不合格，保留候选并报告，不自动重提。

本次1个Job、1张建筑候选，正常2K生成20积分+standard去背景5积分，预计25，申请最高25。普通运行不包含另一次去背景或变体生成；失败只轮询/恢复原Job。

定价核验：2026-09-17，https://meowa.ai/api-docs#post-api-pixel-gen 。模板通过只读pixel-gen-template-info获得。候选下载到art/candidates/camp-council-isometric/meowa-v1，技术与视觉批准之前不进入正式assets。生成不改变当前通行/遮挡数据与正式Map01。
