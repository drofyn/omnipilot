# OmniPilot

一个 macOS 菜单栏常驻的 **SSH 本地端口转发管理器**。

它读取 `~/.ssh/config`（**只读，永不修改**），把其中声明了 `LocalForward` /
`RemoteForward` 的 Host 列出来，并为每个 Host 守护一个 `ssh -N <alias>` 进程：
断线自动重连，菜单栏可随时启停。

## 特性

- 菜单栏常驻，无 Dock 图标
- 数据源就是 ssh config，不引入任何额外配置文件
- 每个 Host 一个守护进程，异常退出按 `1 → 2 → 5 → 10 → 30s` 退避重连
- 反复重连失败时发送系统通知
- 日志写入 `~/Library/Logs/OmniPilot/omnipilot.log`
- 仅支持 Apple Silicon（arm64），最低 macOS 13

## 工作原理

```
~/.ssh/config
      │  Host 别名扫描 + ssh -G <alias> 解析出最终生效配置
      ▼
有 LocalForward / RemoteForward 的 Host
      │  每个 Host：/usr/bin/ssh -N <alias>
      ▼
ProcessSupervisor（启动 / 监督 / 退避重连 / 日志）
```

启动命令等价于：

```sh
ssh -N <alias> \
  -F ~/.ssh/config \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o BatchMode=yes \
  -o ConnectTimeout=15
```

`ssh -N <alias>` 会让 ssh 自己应用该 Host 上声明的全部转发，因此无需我们重建
`-L` / `-R` 参数。

## 认证

本工具**完全不管理认证**。它依赖你本机已经配置好的 ssh-agent / 密钥。
由于守护进程没有 TTY，使用了 `BatchMode=yes`：连不上会**立即失败并报错**，
而不会卡在交互式密码提示上。请确保：

- 私钥已加入 ssh-agent（`ssh-add --apple-use-keychain <key>`）
- 目标主机的 host key 已在 `known_hosts` 中（先手动 `ssh <alias>` 一次）

## 构建

需要 Xcode 与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```sh
brew install xcodegen
Scripts/build-app.sh            # Debug
Scripts/build-app.sh release    # Release
open build/OmniPilot.app
```

或直接使用 Xcode：

```sh
xcodegen generate
open OmniPilot.xcodeproj
```

## 测试核心逻辑

核心逻辑在本地 Swift Package `Packages/OmniPilotKit` 中：

```sh
cd Packages/OmniPilotKit
swift test
```

## 打包分发

```sh
Scripts/package.sh            # Release 构建 + zip
Scripts/package.sh --dmg      # Release 构建 + dmg
Scripts/package.sh --all      # zip + dmg
```

产物输出到 `build/dist/`。脚本会自动检测钥匙串中的 `Developer ID Application`
证书：有则签名（并可配合 `NOTARY_PROFILE` 公证），无则使用 ad-hoc 签名。

分发方式、Gatekeeper 与 `quarantine` 的关系详见 [Docs/distribution.md](Docs/distribution.md)。

## 图标

应用图标与菜单栏图标来自 `Design/OmniPilot.svg`，菜单栏失败态图标来自
`Design/OmniPilotError.svg`（在菱形上镂空感叹号），均用系统自带工具生成（零依赖）：

```sh
Scripts/make-icon.sh          # 生成 Resources/AppIcon.icns 与 Resources/MenuBarIcon*.png / MenuBarIconError*.png
```

菜单栏图标以 **模板图** 方式使用：macOS 只取 alpha 通道并随浅色/深色菜单栏自动反色。
当有隧道持续重连失败时，菜单栏会切换为镂空感叹号的失败态图标。

## 目录结构

```
omnipilot/
├─ project.yml                     # XcodeGen 工程定义
├─ Sources/OmniPilot/              # App 目标（菜单栏 + 设置窗口）
├─ Packages/OmniPilotKit/          # 核心逻辑（可单测）
│  ├─ Models/                      # PortSpec / PortForward / SSHHost / TunnelState
│  ├─ SSH/                         # ssh config 解析、命令构建
│  └─ Runtime/                     # 进程守护、日志、孤儿进程清理
├─ Design/OmniPilot.svg            # 图标设计源
├─ Design/OmniPilotError.svg       # 菜单栏失败态图标设计源
├─ Resources/                      # AppIcon.icns / MenuBarIcon*.png / MenuBarIconError*.png（由脚本生成）
├─ Scripts/
│  ├─ build-app.sh                 # 开发构建 → build/OmniPilot.app
│  ├─ make-icon.sh                 # SVG → 应用图标 + 菜单栏图标
│  └─ package.sh                   # 分发打包 → build/dist/
└─ Docs/distribution.md            # 分发与 Gatekeeper 说明
```

> `OmniPilot.xcodeproj` 与 `Sources/OmniPilot/Info.plist` 均由 XcodeGen 生成，
> 已加入 `.gitignore`；克隆后执行 `xcodegen generate` 即可。

## 许可证

[MIT](LICENSE)
