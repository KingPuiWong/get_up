# GetUp

macOS 菜单栏久坐提醒工具，原生 Swift 实现，零外部依赖。

## 功能

- 站立提醒：默认每 45 分钟提醒一次，提醒后自动暂停，手动点击「开始站立提醒」恢复下一轮。
- 自定义提醒间隔：预设 20/30/45/60/90 分钟，也支持自定义输入任意分钟数。
- 菜单栏倒计时：实时显示距下次提醒的剩余时间。
- 开机启动：菜单内一键开启/关闭登录自启。
- 设置持久化：提醒间隔自动保存，重启后恢复上次设置。

## 构建

要求 macOS 13+，Xcode Command Line Tools。

```bash
make build    # 编译生成 dist/GetUp.app
make dmg      # 打包为 dist/GetUp.dmg
make run      # 编译并启动
make clean    # 清理构建产物
```

## 直接运行

```bash
./run.sh
```

或双击 `dist/GetUp.app`。

## 项目结构

```
Sources/GetUp/
├── main.swift              # 入口（显式创建 NSApplication）
├── AppDelegate.swift        # 菜单栏应用主逻辑
├── Info.plist              # App Bundle 配置
├── icon.icns               # 应用图标
├── icon.iconset/           # 图标源文件
└── generate_icon.py        # 图标生成脚本
```
