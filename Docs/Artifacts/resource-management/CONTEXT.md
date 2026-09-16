# 资源管理任务状态

更新：2026-09-16（正式灵圃本地结算修复，在线迁移仍待选择）

- 当前目标（覆盖旧独立模块交付范围）：用户要求继续接入正在玩的正式灵圃，解决停留页面库存不刷新。已说明正式页面未接入在线模块，不能把独立测试入口称为正式接入完成。已异步询问单机资源一次迁移或新在线档；答复前禁止迁移或合并余额。
- 本轮发现：Admin已有其他改动完成侧栏及统一样式，必须保留，不能用旧staging覆盖；正式camp.gd仍只在交互时结算。现已补每秒刷新Timer、库存Label更新、周期倒计时和未分配/满仓提示，真实headless场景验证通过：LING_PU_LIVE_REFRESH_OK。测试强制 --no-profile-write，不覆盖用户档。在线接入尚未完成。
- 决策：服务端权威、断网只读、满仓不继续耗粮、期初维护、个人进度/庚精余数、灵液保留比例、配置分段、后台可改余额且审计。
- 事实源：Docs/PRD/07_资源管理与灵源院前后端分离_PRD.md（产品0.2）；Docs/Tech/资源管理与灵源院前后端分离技术方案.md（实装1.0）；34/36规则、03页面。技术方案已替代原拟议表与路由。
- 环境：复用 Docker kunwu-admin-mysql，MySQL8.4.11，127.0.0.1:3307；Drizzle新增9资源表，原59表不改。ARM Node=/Users/zhangxiaoen/.nvm/versions/node/v22.22.2/bin/node。
- 后端完成：rules/settle纯结算、ResourceService聚合行锁、请求去重与重启续算、权限/环境、奖励claim去重、流水与管理审计同事务。资源配置独立草稿/审核/不可变发布，不覆盖原六模块或D0。细节和API清单见技术方案，不在此复制。
- 后台完成：/resources 三页签（玩家资源、目录与配置、模拟）；余额增减/设置、预览冲突保护、流水、资源目录筛选/详情编辑、稳定code保护、数值表校验、字段差异、历史规则载入并重新发布、逐人进度/庚精余数/维护已付模拟和停工状态。
- Godot完成：scripts/services/resource_repository.gd；scripts/scenes/resource_online_test.gd；scenes/resource_online_test.tscn；Game仅新增服务节点/隔离缓存方法；tools/run_resource_online_test.py及根.command启动；原请求恢复和离线只读。发布目录显示名随快照下发。
- 数据身份：.local/resource-development.json被忽略且权限600，严禁输出。setup生成或续期同身份；development唯一玩家 e5679b08-41f0-4bac-ad93-3b48046c5124，余额浏览器验收加10再扣10恢复。数值基线同值发布，development revision2。自动测试均 test-* 环境。
- 验证：30项全部通过（20领域含150随机分段、10真实MySQL含注入审计失败回滚）；后续补充的目录发布→玩家快照断言也通过；最终Next build、ESLint、tsc通过。HTTP验证401身份/角色、403跨源、400缺幂等key、正常同步/配置/个人进度模拟通过。
- Godot验收：完整真实HTTP E2E已在最终后台通过，同步/分配/招募/升级/余额不足/断网与pending恢复；每次对真实profile哈希，未改变。实际在线场景启动无脚本错误。未确认Godot实际窗口的最终视觉：之前Mac锁定，恢复后CUA选中用户原有Godot编辑器嵌入窗口，不能把那个营地截图当在线页验收。用户复核入口为根run_resource_online_test.command（标题“灵源院在线测试”）。
- 浏览器验收：最终管理页目录展开、改名产生1项差异后恢复、个人进度输入展开、模拟结果显示满仓停工；早期已验证真实余额调整和配置保存审核发布。tab4/iab为交付页，已markDeliverable。
- 当前进程：后台session15162在127.0.0.1:3100（最终.next-build）；Godot在线窗口session83527。旧服务/自建旧窗口均停，用户原Godot编辑器与运行窗口未关闭。
- 修改保护：保留Godot大量原改动及Admin剧情/README原内容；Admin managed文件从/private/tmp/kunwu-resources-full同步，installer+baseline.json校验hash防覆盖。只改staging再调用install.py（提权）；新增已有目标须先登记当前hash。凭据绝不复制到文档。
- 当前阻塞/下一步：等待用户回答已发出的迁移选择（备份后一次导入当前灵圃，或新在线资源档）。跨玩法读取/消费仍直接修改Game.profile.wallet；正式切换不能仅覆盖HUD，必须解决统一消费与旧档余额隔离。不要未经答复执行迁移。自动刷新修复已完成，无需重测；新增tools/validate_ling_pu_live.gd/.tscn为验收入口。
- Admin最新现状：ConfigDashboard/StoryEditor已有资源侧栏链接，ResourceManager已有admin壳与CSS变量样式（其他改动），旧/private/tmp staging中的这些文件已过期，不得覆盖。

- 2026-09-16净耗粮修复：用户实际存档灵粮800，分配粮9/木12/铁5，缓存旧规则每周期产9耗39。game.gd原maxi(grain,...)错误阻止所有净扣粮；现只用max(原余额,容量)作上限，允许扣减，保留超容量历史库存。validate_ling_pu_live覆盖增长、800→770、超容量扣粮及弹窗刷新，禁写真实存档。此前仅测增长不足以证明生产结算正确；仍不可称正式在线接入完成。

- 2026-09-16营地资源提示：camp.gd新增场景级钱包差额监听（HUD更新与帧检查），最新用户要求已覆盖原提示框方案：中下方逐资源纵列显示18px不透明深色文字，2px浅色细描边增强复杂背景可读性，无底框；1.8秒向上飘64px，后1.15秒淡出。同次变化合并、连续变化排队。不复用操作反馈框，不拦截点击，离开营地随节点销毁；初次库存不当成新增。validate_resource_notices.gd/.tscn已验证混合增减、重复刷新、排队、无底框深色文字、向上运动、淡出隐藏、反馈不覆盖与场景销毁，禁写真实档。

- 面板净变化修复：原“产量 +人数”未扣维护，已改为每周期预计库存净变化（正/负/零），负数暖红色，灵粮悬浮说明产粮/耗粮。Game.production_forecast与settle_production共享同一计算，包含维护、缺粮停工及容量限制；不另设UI算法，预览不改profile。live验证已覆盖粮9/木12/铁5时显示净变化-30、预览无副作用并与结算一致。

- 当前任务2026-09-16：用户明确要求正式营地接入新后台招募费用（只读配置接入，不要求余额迁移）。现已新增Admin公开已发布接口 /api/game-config/[channel]/recruitment（只读有效发布、校验哈希，不读草稿），Godot recruitment_config服务30秒同步/缓存，Game招募统一quote，正式camp弹窗及扣款接逐人表、每次1人、上限12。旧档实际61人原样保留并禁止继续招募，不自动删除或重置。无配置时禁招，不回退50。旧确认遇到配置变更不能新价扣款。
- 本轮文件：Admin仅新增server/services/recruitment-config.ts和app/api/game-config/[channel]/recruitment/route.ts，其他最新Admin页面/规则不覆盖。独立与标准.next-build构建均通过；旧3100 PID25872已停止，新后台session83582在3100运行。Godot validate_recruitment_config --recruitment-http-check已通过配置注入与真实HTTP验证；公开下发release69349869-3e07-4973-84e7-9e56f2008c90，费用300/450/650/900/1200/1600，上限12，每次1。非法渠道404。原profile未执行迁移/重置，测试强制禁写。
