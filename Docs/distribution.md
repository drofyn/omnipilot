# 分发指南

## 打包

```sh
Scripts/package.sh            # Release 构建 + zip（默认）
Scripts/package.sh --dmg      # Release 构建 + dmg
Scripts/package.sh --all      # zip + dmg
```

产物输出到 `build/dist/`，命名为 `OmniPilot-<版本>.zip` / `.dmg`。

脚本会自动检测钥匙串里的签名证书：

| 情况 | 脚本行为 |
|---|---|
| 找不到 `Developer ID Application` | 使用 **ad-hoc** 签名 |
| 找到 `Developer ID Application` | 用它签名（hardened runtime） |
| 找到证书 **且** 设置了 `NOTARY_PROFILE` | 再执行公证 + `stapler` 装订 |

## Gatekeeper 与 quarantine 的关系

macOS 的 Gatekeeper **只在文件带有 `com.apple.quarantine` 扩展属性时**才做签名/公证检查。

这个属性由**接收端的 App** 在保存文件时写入，所以**传输方式决定一切**：

| 传输方式 | 写入 quarantine？ | 未公证的 ad-hoc App |
|---|---|---|
| `scp` / `rsync` / `curl` | 否 | ✅ 直接运行 |
| U 盘拷贝 | 否 | ✅ 直接运行 |
| AirDrop | **是** | ❌ 被拦 |
| Safari / Chrome 下载 | **是** | ❌ 被拦 |
| 邮件 / iCloud Drive | **是** | ❌ 被拦 |

> `com.apple.quarantine` 的值形如 `01c1;6ac9a4c6;Chrome;<UUID>`，
> 分别是：标志位、十六进制下载时间戳、写入该标记的 App、事件 UUID。
>
> 另有 `com.apple.provenance`（macOS 14+），记录文件创建者，**不参与** Gatekeeper 拦截。

## 分发到另一台 Mac（无需证书）

在构建机上：

```sh
Scripts/package.sh
scp build/dist/OmniPilot-0.1.0.zip <user>@<另一台>:~/
```

在另一台上：

```sh
cd ~
ditto -x -k OmniPilot-0.1.0.zip .
mv OmniPilot.app /Applications/
open /Applications/OmniPilot.app
```

验证：

```sh
xattr -l /Applications/OmniPilot.app          # 不应出现 com.apple.quarantine
codesign --verify --strict /Applications/OmniPilot.app
```

## 万一已经被 quarantine 拦住

若对方是经由 AirDrop / 浏览器 / 网盘拿到的，会出现两种弹窗：

| 弹窗 | 设置里有「仍要打开」吗 | 解法 |
|---|---|---|
| “无法验证开发者 / Apple 无法检查…” | ✅ 有 | 系统设置 › 隐私与安全性 › 仍要打开 |
| “已损坏，无法打开，应将它移到废纸篓” | ❌ 没有 | 只能开终端执行下面的命令 |

```sh
xattr -dr com.apple.quarantine /Applications/OmniPilot.app
```

> 用 `ditto`（本脚本的做法）打包能完整保留签名与权限；用普通 `zip` 或
> 破坏性传输容易损坏签名，从而落到「已损坏」这一类。

## 正式分发（Developer ID + 公证）

要让**任何 Mac 双击即开、无任何警告**，需要 Apple Developer Program 会员
（99 USD/年，中国区约 ¥688/年），然后：

1. 在 Apple Developer 后台创建 **Developer ID Application** 证书并导入钥匙串
2. 创建公证凭据（只需一次）：

   ```sh
   xcrun notarytool store-credentials "omnipilot-notary" \
     --apple-id "<你的 Apple ID>" \
     --team-id "<Team ID>" \
     --password "<App 专用密码>"
   ```

3. 打包时带上 profile 名称：

   ```sh
   NOTARY_PROFILE=omnipilot-notary Scripts/package.sh --all
   ```

脚本会自动完成：Developer ID 签名 → 提交公证 → 等待结果 → 装订票据。
之后无论用哪种方式传输都能正常打开。
