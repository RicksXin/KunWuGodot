# 崖底循环雾

96×512×192 RGBA 帧，8列12行，12fps，8秒循环，frames.tres 为播放入口。
由 tools/build_camp_mist_sequence.py 确定性烘焙同速平移的周期雾纹，固定浓度基底与上缘渐入、底部持续浓度遮罩。上边缘 alpha 为0、下边缘保持浓度，左右边缘一致以无缝重复；独立柔雾使用线性过滤以消除放大色阶，其他像素图仍 nearest。
仅展示，不参与导航或存档。视觉候选状态见 art/candidates/camp-mist-v1/README.md。
