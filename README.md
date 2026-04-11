# GetUp 打包说明

## 功能

- 站立提醒：默认每 45 分钟提醒一次，提醒后自动暂停，手动恢复进入下一轮。
- 喝水提醒：默认每 60 分钟提醒一次，可单独开关和自定义间隔（30/45/60/90/120 分钟）。
- 菜单栏显示双倒计时：站立倒计时 + 喝水倒计时。
- 支持“现在提醒我站起来 / 现在提醒我喝水”。
- 站立与喝水提醒相互独立：暂停站立不会影响喝水提醒。

> 默认喝水提醒频率采用“少量多次”的实践方式，便于把全天饮水分散到清醒时段内完成。

## 喝水提醒依据（权威来源）

- NASEM（IOM DRI）常用成人总水分 AI：男性约 3.7L/天，女性约 2.7L/天（总水分含食物+饮品）。
- Mayo Clinic 使用同一组常见参考值：男性约 15.5 杯、女性约 11.5 杯；并强调具体需求受活动量、气候、健康状态影响。
- Mayo Clinic 脱水条目指出：口渴并不总是脱水的早期可靠信号（尤其老年人），因此主动、分次补水更稳妥。
- CDC 建议优先选择白水作为日常补水方式（零热量、无糖），以减少含糖饮料摄入。

参考链接：
- https://nap.nationalacademies.org/read/10925/chapter/6
- https://www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating/in-depth/water/art-20044256
- https://www.mayoclinic.org/diseases-conditions/dehydration/symptoms-causes/syc-20354086
- https://www.cdc.gov/healthy-weight-growth/water-healthy-drinks/index.html

## 产出 macOS App 与 DMG

1. 安装构建依赖：

```bash
make deps
```
`make deps` 会自动创建项目内 `.venv` 并在其中安装依赖。

2. 生成 `.app`（会先跑测试）：

```bash
make app
```

3. 生成 `.dmg`（会自动执行 `make app`）：

```bash
make dmg
```

默认产物位置：

- App: `dist/*.app`
- DMG: `dist/GetUp.dmg`

## 直接运行开发版

```bash
./run.sh
```
