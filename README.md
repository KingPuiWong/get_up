# GetUp 打包说明

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
