# 营地装饰候选预览

唯一运行图片：atlas-v2.png，1536×2048 RGBA，nearest，不新增序列帧图。
atlas.json定义15个裁剪区域及脚底锚点；所有实例共享同一纹理。
石灯使用camp_decor_light.gdshader让亮琥珀区域轻微呼吸；几何与阴影不晃动。

布局：data/prototypes/camp_tile_rebuild.json → decorations，当前30件。
编辑器下拉框带“装饰 · ”前缀，可直接透明拾取、像素微调、整格移动、缩放、翻转、旋转、撤销及保存。
origin/door在装饰记录中是相同的视觉落点格，不表示可互动建筑入口。
苔草/落叶绘于地面上、建筑下；实体道具按脚底深度排序。
本阶段为纯视觉装饰，不更改现有寻路碰撞；NPC工作需单独配置道具避让。

来源与唯一任务状态：art/candidates/camp-decor-20260923/README.md。
基础装饰及追加阵旗/阵灯/魂龛分别内置生图一次，共用图集；无Meowa调用。等待用户在营地编辑器视觉复核。
验证：tools/validate_camp_decor.gd（运行需带 -- --no-profile-write --ignore-config-cache）。
