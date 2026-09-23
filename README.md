<p align="center">
  <img src="assets/icons/app_icon.png" width="112" alt="简记应用图标">
</p>

<h1 align="center">简记</h1>

<p align="center">
  一款完全在本地运行的 Android 现金流助手。<br>
  <strong>打开两秒，就知道今天能不能花。</strong>
</p>

<p align="center">
  Flutter · Material 3 · Riverpod · Drift / SQLite
</p>

> [!IMPORTANT]
> 简记目前处于开发阶段。卸载或清除数据前，请在“设置 → 数据管理 → 导出备份”保存 ZIP 文件；应用不会自动把账本同步到云端。备份文件包含完整财务记录，请妥善保管。

## 为什么做简记

传统记账 App 擅长告诉你“过去花了多少”，却不一定能回答更迫切的问题：**接下来还有哪些支出，今天到底可以安心花多少？**

简记围绕这个问题组织首页、未来现金流与账单时间线：

| 今天 | 未来 | 本地优先 |
| --- | --- | --- |
| 根据当前余额、近期必要支出和安全垫计算“安心可花” | 展示未来 30 天余额曲线、最低余额与周期计划 | 无需账号和服务器，账单、规则与偏好均保存在本机 |

## 核心功能

### 今天

- 汇总本月收入、支出与结余。
- 根据可支配余额、必要支出和安全垫计算“安心可花”。
- 通过普通表单或一句话快速记账，例如 `瑞幸 16 微信`、`下周一房租 2500`。
- 一句话识别结果始终进入可编辑表单，不会自动写入账本。

### 未来

- 创建一次性或每周、每月、每年、自定义间隔的收支计划。
- 预测未来 30 天的每日余额、最低余额及其成因。
- 通过余额曲线直观看到现金流拐点。
- 对计划执行确认、跳过、仅修改本次或修改后续操作。

### 时间线

- 连续查看未来事项与历史账单。
- 新增、编辑、复制和删除收入、支出及账户间转账。
- 按日期分组，并按关键词、类型、分类、账户和日期范围筛选。
- 删除的账单先进入回收站，可恢复或确认后永久删除。

### 个性化

- 内置常用收入与支出分类，并记录最近使用的账户和分类。
- 商户分类规则与账户规则仅保存在本机，可随时查看和删除。
- 支持跟随系统、浅色和深色主题。

### 本地备份

- 在设置页通过 Android 文件选择器导出和读取版本化 ZIP 备份，包含账户、账单（含回收站）、周期计划、跳过记录、商户规则及必要偏好。
- 导入前显示备份时间和各类记录数；支持覆盖恢复或按 UUID 合并。合并时保留同 UUID 的本地记录，重复导入不会重复生成账单。
- 恢复前会要求先保存当前账本快照；取消保存就不会修改数据。导入在数据库事务内执行，失败时回滚。
- 备份由用户在设置页手动导出，保存位置由用户选择。

## 数据与隐私

- 不需要注册或登录，不依赖云端服务。
- 账单存入应用私有目录中的 SQLite 数据库。
- Android 系统备份已关闭，避免账本被系统自动同步到云端；手动导出时可以自行选择存放位置。
- 金额使用整数分存储，例如 `¥12.50` 存为 `1250`，避免浮点精度问题。
- 真实余额由账户初始余额和已确认交易动态派生；计划与候选交易不会提前改变余额。
- 账户间转账不会改变总资产，也不会计入月度收入或支出。
- 当前数据库 schema 为 v4，并包含从旧版本无损升级的迁移逻辑。

## 技术栈

| 领域 | 方案 |
| --- | --- |
| UI | Flutter、Material 3 |
| 状态管理 | Riverpod |
| 本地数据库 | Drift、SQLite |
| 页面导航 | go_router |
| 图表 | fl_chart |
| 本地偏好 | shared_preferences |
| 日期与金额格式 | intl |

项目遵循单向数据流，页面不直接执行 SQL：

```text
Widget
  ↓
Riverpod Provider
  ↓
Repository
  ↓
DAO
  ↓
Drift / SQLite
```

主要目录：

```text
lib/
├── app/              # 应用入口、路由与主题
├── core/             # 数据库、通用工具与基础能力
├── features/
│   ├── accounts/     # 账户与余额
│   ├── cash_flow/    # 现金流预测与安心可花
│   ├── home/         # 今天页
│   ├── quick_input/  # 本地一句话记账
│   ├── schedules/    # 周期计划
│   ├── settings/     # 设置与本地规则
│   ├── statistics/   # 未来余额图表
│   └── transactions/ # 账单领域与时间线
└── shared/           # 跨功能共享组件
```

## 快速开始

### 环境要求

- Flutter 3.47 或兼容版本
- Dart 3.13 或兼容版本
- Android SDK 与一台 Android 模拟器或真机

### 运行项目

```bash
git clone https://github.com/Anima529/money-tracker.git
cd money-tracker
flutter pub get
flutter run
```

修改 Drift 表或生成代码后，执行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

<details>
<summary>Windows 下首次构建停在 Gradle 下载怎么办？</summary>

Gradle 首次构建需要下载依赖。若网络不稳定，可先设置镜像后重新运行：

```powershell
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:GRADLE_OPTS = "-Dorg.gradle.internal.http.connectionTimeout=120000 -Dorg.gradle.internal.http.socketTimeout=120000"
flutter run
```

</details>

## 质量检查

提交改动前建议运行：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

当前测试覆盖金额解析与格式化、Repository/DAO、数据库迁移、账户与余额、转账语义、周期展开、未来现金流、“安心可花”、快速输入及核心界面流程。

## 路线图

- [x] 本地账单、账户与转账
- [x] 周期计划与未来现金流预测
- [x] 一句话快速记账与本地规则
- [x] 今天 / 未来 / 时间线信息架构
- [x] 数据导出、恢复与冲突处理
- [ ] 通知解析与候选账单
- [ ] 月度洞察与异常提醒
- [ ] 无障碍、性能优化与正式发布准备

## 参与贡献

欢迎通过 [Issues](https://github.com/Anima529/money-tracker/issues) 报告问题或提出建议。准备提交代码时：

1. Fork 仓库并从最新分支创建功能分支。
2. 保持改动聚焦，并为核心逻辑补充测试。
3. 确保 `flutter analyze` 与 `flutter test` 通过。
4. 在 Pull Request 中说明问题、实现方式与验证结果；界面改动请附截图。

## 许可证

本仓库目前尚未添加开源许可证。在许可证明确前，代码仍受默认版权约束；欢迎先通过 Issue 参与讨论。
