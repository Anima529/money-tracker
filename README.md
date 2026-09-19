# 简记（money_tracker）

简记是一款纯本地 Android 个人记账 App。

## 已实现

- 首页显示本月结余、收入、支出和最近五笔账单；无数据时显示空状态。
- 使用 Material 3 NavigationBar 在首页、统计、账单、设置之间切换。
- 主题支持跟随系统、浅色、深色，并保存在本机。
- 账单 Repository / DAO 支持新增、修改、删除、全部查询、按日/月/收支类型查询及实时订阅。
- 内置 8 个支出分类和 6 个收入分类。分类以稳定 ID 存储，并预留图标、颜色及自定义分类字段。
- 金额以**整数分**存入 SQLite，例如 ¥12.50 存为 `1250`，避免浮点精度问题。
- 已建立账户、交易状态/来源和周期计划数据模型；新数据库会创建一个默认账户。
- 当前余额由账户初始余额和已确认交易动态派生；计划、候选交易不影响真实余额，账户间转账不改变总资产或月度收支。
- 数据库可从 schema v1 无损升级到 v2，旧账单自动归入默认账户并补齐稳定 UUID、确认状态与手动来源。
- 可新增、编辑和复制收入、支出与转账，选择账户、分类、日期并填写商户和备注；最近使用的账户与分类会保存在本机。
- 金额键盘支持简单加减表达式，金额解析和存储全程使用整数分，并拒绝零值、负值和越界金额。
- 账单详情支持删除和撤销；撤销会保留原 UUID 与审计时间，避免后续备份合并产生重复身份。
- 账单列表按日期分组，支持关键词、类型、分类、账户和日期范围筛选。
- 支持一次性与每周、每月、每年、自定义天数周期计划，可确认、跳过、改单次或修改后续。
- 动态预测未来 30 天每日余额、最低余额及原因，并按可支配余额、必要支出和安全垫计算“安心可花”。
- 支持“瑞幸 16 微信”“下周一房租 2500”等本地快速输入；识别结果进入普通可编辑表单，不会自动入账。
- 商户分类与账户规则只保存在本机，可在设置页查看和删除。
- 主导航为“今天 / 未来 / 时间线 / 设置”：今天页提供安心可花与快速记账，未来页展示 30 天余额曲线和计划，时间线连续展示未来事项与历史账单。
- Android 启动器图标使用仓库内的原图生成各屏幕密度资源。

账单和主题设置只保存在应用私有目录。App 不需要账号、服务器或云同步；Android 系统备份已关闭。**卸载应用或清除应用数据会删除账单**，导出与恢复功能尚未实现。

## 技术栈与结构

| 用途 | 技术 |
| --- | --- |
| UI 与主题 | Flutter、Material 3 |
| 状态管理 | Riverpod |
| 本地数据库 | Drift、SQLite |
| 页面导航 | go_router |
| 日期和金额格式 | intl |
| 后续统计图 | fl_chart（已加入依赖，尚未使用） |
| 本地主题偏好 | shared_preferences |

```text
lib/
├── app/                 # 应用入口、路由、主题
├── core/                # Drift 数据库、金额和日期工具
├── features/
│   ├── home/            # 首页与月度汇总
│   ├── accounts/        # 账户、派生余额与数据访问层
│   ├── transactions/    # 账单模型、分类、DAO、Repository、页面
│   ├── schedules/       # 周期计划模型与数据访问层
│   ├── statistics/      # 统计页骨架
│   └── settings/        # 主题设置
├── shared/widgets/      # 导航壳、空状态、异步状态组件
└── main.dart
```

数据流：页面 → Riverpod → Repository → DAO → Drift/SQLite。页面不直接执行 SQL。

数据库当前为 schema v3，包含 `accounts`、`transactions`、`schedules`、`schedule_skips` 和 `merchant_rules`。交易支持 income / expense / transfer，以及 confirmed / planned / suggested 状态和 manual / notification / import / schedule 来源。日/月查询采用包含起点、不包含下一日/月起点的范围；修改记录保留创建时间。

## 本地运行

项目只包含 Android 平台。当前开发环境为 Flutter 3.47.4 / Dart 3.13.3；Android 构建文件沿用项目初始化时的配置。

```sh
git clone https://github.com/Anima529/money-tracker.git
cd money-tracker
flutter pub get
flutter devices
flutter run -d <Android设备ID>
```

可用 `flutter devices` 输出中的 ID 替换 `<Android设备ID>`。Drift 生成文件已纳入仓库；修改数据库表结构后再运行 `dart run build_runner build`，并为 schema 变更编写迁移。

本项目的 `path_provider_android` 固定为 2.2.23，以使用现有 Flutter 编译 SDK。若在 Windows 上遇到 Kotlin 增量缓存的 `this and base files have different roots` 错误（例如项目与 Pub 缓存位于不同盘符），可仅对当次运行关闭增量编译：

```sh
flutter run -d <Android设备ID> --android-project-arg=kotlin.incremental=false
```

如需禁止构建过程自动下载 Android SDK 组件，还可以添加 `--android-project-arg=android.builder.sdkDownload=false`；本机须已具备项目依赖的 SDK 组件。这些参数不会改写 Gradle 或 SDK 配置。

启动器图标源文件为 `assets/icons/app_icon.png`。更换图片后运行 `dart run flutter_launcher_icons`，即可重新生成 Android 图标资源。

## 验证

```sh
flutter pub get
flutter analyze
flutter test
```

阶段 0 曾在 Pixel 8 / Android 16 模拟器完成启动和页面检查。当前验证结果为 `flutter analyze` 无问题、43 项测试通过，并成功构建 Android debug APK；测试覆盖 v1/v2 → v3 数据库迁移、余额与转账、月末和闰日周期、跳过实例、未来余额、安心可花、快速文本解析、模糊匹配、商户学习、金额边界、防重复提交及页面导航。

## 下一步

按当前顺序，下一阶段可继续阶段 6 的 Android 支付通知识别；阶段 3 的版本化本地备份与恢复仍是上线前必须补齐的数据安全能力。
