# 双台地连通验证

设置→营地TileMap实验默认进入“双台地连通验证”（index13）。既有单台地和全营地预览仍在下拉菜单。命令参数--connected-preview可直接进入。

复用两份camp_continuous_terrace.tscn和已确认台阶，以九格现有泥土地块连接；这是组件集成验证，不替换正式营地，不将重复L岛视为最终地图布局。

## 作者接口

布局来自data/prototypes/camp_connected_terraces.json：modules.position、name、road_index及road_origin、按相邻顺序排列的road_cells。当前两个模块位移(0,0)/(512,0)，同为48高差。配置扩展仍须满足已确认组件形状，不支持任意变形。

脚本scripts/prototypes/camp_connected_terraces.gd导入每个组件的15节点图，ID偏移index×100，道路从1000起。lower port为组件节点14，必须与指定道路中心完全对齐，加载时assert检查。碰撞和道路连接由配置与图表达，不读取视觉像素。

## 交互与验证

点击台地或道路，或使用三个目的地按钮。路线线条与空心菱形标记目的地；途中改道先完成当前边，不穿岩壁。到达后清除路线并反馈，复位返回左台地；切换场景暂停该组件。

tools/validate_camp_connected_terraces.gd验证：2模块/9道路格/39节点，跨组件路线经过双方全部阶梯站点；断开道路即不可达；途中改道不瞬移；鼠标选择、往返、空地拒绝、复位和显隐暂停。--capture-connected输出实机截图。测试均加--no-profile-write --ignore-config-cache。

本轮复用了全部已有Approved素材，未生成美术或使用Meowa积分。全营地三层/七建筑仍由旧全景结构预览验证，并未在本场景完成新的全营地美术。
