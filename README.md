# OmniPilot

OmniPilot 是一个常驻 macOS 菜单栏的个人助手。目前包含 SSH 端口转发管理和文本剪贴板历史。

- 仅支持 Apple Silicon（`arm64`）
- 最低支持 macOS 13
- 不显示 Dock 图标
- 可设置登录时启动
- 不依赖第三方运行时库

## 功能

### SSH 隧道管理

OmniPilot 只读 `~/.ssh/config`，列出声明了 `LocalForward`、`RemoteForward` 或 `DynamicForward` 的 Host，并为每个 Host 运行一个 `ssh -N <alias>` 进程。它不会修改 SSH 配置，也不管理密钥或认证。

- 菜单栏中查看隧道和转发信息（含 `Socks5 host:port`），支持点击一键复制监听地址，单独或批量启停、重启
- 意外断开后自动重连，间隔依次为 `1、2、5、10、30` 秒
- 连续失败时发送系统通知；菜单栏图标显示失败状态
- 启动时清理上次运行遗留的隧道进程
- 日志写入 `~/Library/Logs/OmniPilot/omnipilot.log`

启动命令等价于：

```sh
/usr/bin/ssh -N <alias> \
  -F ~/.ssh/config \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o BatchMode=yes \
  -o ConnectTimeout=15
```

SSH 会根据 Host 配置应用它声明的全部本地、远程和动态（SOCKS5）转发。认证使用本机已有的 `ssh-agent` 和密钥；由于后台进程没有交互式终端，认证失败会立即报错，不会等待输入密码。首次连接前，请先在终端连接目标 Host 并确认其 host key。

### 剪贴板历史

- 历史上限默认 50 条，支持快捷预设（`20、50、100、200、500`）以及 `10–500` 范围内的任意自定义条数
- 支持为条目添加行内备注（与原始内容同列缩略展示，保持两行紧凑高度），支持按内容或备注实时搜索过滤
- 支持将常用条目置顶（置顶条目排在顶部且不会被自动淘汰）；清空时支持“仅清空未置顶”或“全部清空”
- 点击历史记录会将文本写回系统剪贴板并提示已复制；之后可在目标 App 中按 `⌘V` 粘贴，不会自动模拟粘贴
- 自动过滤密码管理器等标记的敏感剪贴板内容
- 每条文本最多保存 100,000 个字符

历史文件位于：

```text
~/Library/Application Support/OmniPilot/clipboard-history.json
```

**隐私提示：** 历史文件是普通 JSON 文件，不加密，其中可能包含复制过的敏感文本。可从菜单栏面板删除单条记录或清空历史。

## 数据位置

| 数据 | 位置 |
|---|---|
| 剪贴板历史 | `~/Library/Application Support/OmniPilot/clipboard-history.json` |
| 剪贴板历史条数设置 | macOS `UserDefaults` |
| 应用日志 | `~/Library/Logs/OmniPilot/omnipilot.log` |
| SSH 配置 | `~/.ssh/config`（只读） |

## 构建与运行

需要 Xcode 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```sh
brew install xcodegen
Scripts/build-app.sh          # Debug 构建
Scripts/build-app.sh release  # Release 构建
open build/OmniPilot.app
```

也可以生成工程后用 Xcode 打开：

```sh
xcodegen generate
open OmniPilot.xcodeproj
```

`OmniPilot.xcodeproj/` 和 `Sources/OmniPilot/Info.plist` 由 XcodeGen 生成并已加入 `.gitignore`。修改工程定义时编辑根目录的 `project.yml`，然后重新运行 `xcodegen generate`。

## 测试

核心逻辑位于本地 Swift Package `Packages/OmniPilotKit`，可单独运行测试：

```sh
cd Packages/OmniPilotKit
swift test
```

## 打包分发

```sh
Scripts/package.sh            # Release + zip
Scripts/package.sh --dmg      # Release + dmg
Scripts/package.sh --all      # zip 和 dmg
```

产物输出到 `build/dist/`。脚本会使用可用的 Developer ID 证书签名；如设置了 `NOTARY_PROFILE`，还会提交公证并装订票据。分发方式和 Gatekeeper 注意事项见 [Docs/distribution.md](Docs/distribution.md)。

## 许可证

[MIT](LICENSE)
