# 天磊安全围栏 WorkBuddy 插件

安装后，WorkBuddy 里的对话会先经过天磊安全围栏检测。**用内置模型也能生效**，不需要改成自定义模型。

| 检测点 | 触发时机 | 命中风险时 |
| --- | --- | --- |
| 用户输入 | 发送消息后、模型处理前 | 拦截本次输入 |
| 工具调用 | 执行命令、写文件等操作前 | 拒绝执行 |
| 工具返回 | 读取网页、文件等内容后 | 替换返回内容，模型看不到原文 |
| 最终回答 | 回答结束后 | 回答已显示，只弹出提示并记录 |

## 前提

- 已安装 WorkBuddy，并至少打开过一次。
- 电脑能访问防护模型接口（默认 `http://192.168.120.68:18000/v1/scan`）。

## 安装方式一：在 WorkBuddy 里直接导入（推荐）

不需要运行脚本。

1. 打开 WorkBuddy 的**插件管理**，点击**添加市场**。
2. 在“市场源”里填写以下任意一种：
   - **GitHub**：`yuko0331/tianlei-guardrail`
   - **内网地址**（由管理员提供），例如 `http://内网服务器/tianlei-market.zip`
   - **内网 Git 仓库**，例如 `git@gitlab.example.com:team/tianlei-market.git`
   - **本地文件夹**：本压缩包解压后里面的 `market` 文件夹的**绝对路径**。WorkBuddy 会直接使用这个文件夹，所以请先把它放到一个固定位置，不要放在下载目录或临时目录里。
3. 添加成功后，在市场里找到 **tianlei-guardrail**（说明为“天磊安全围栏：……”），点击**安装（用户）**。
4. 新建一个对话进行验证；如果没有生效，完全退出 WorkBuddy 再重新打开。

用这种方式导入时，插件默认连接 `http://192.168.120.68:18000/v1/scan`。如果要改成其他地址，参见下面的“修改配置”一节。

## 安装方式二：运行安装脚本

适合批量安装，或者需要在安装时指定防护模型地址的情况。解压后，在解压目录里执行。

**macOS**

```bash
bash install.sh
```

**Windows**（PowerShell）

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

可选参数：

| 参数 | macOS | Windows | 说明 |
| --- | --- | --- | --- |
| 防护模型地址 | `--scan-url URL` | `-ScanUrl URL` | 默认 `http://192.168.120.68:18000/v1/scan` |
| 检测失败处理 | `--fail-mode closed` | `-FailMode closed` | 默认 `open`，即检测服务不可用时放行；`closed` 表示不可用时拦截 |

安装完成后，**完全退出 WorkBuddy 再重新打开**。

## 验证

新建对话，发送一句明显违规的话，比如越狱指令。正常情况下消息会被拦截，并提示“[天磊安全围栏] 检测到……已拦截”。

每次检测都会记录到本地日志：

- macOS：`~/.tianlei-guardrail/hook.log`
- Windows：`%USERPROFILE%\.tianlei-guardrail\hook.log`

日志里只保留内容开头 40 个字符，用于排查问题。

## 修改配置

编辑 `~/.tianlei-guardrail/hook.json`（Windows 为 `%USERPROFILE%\.tianlei-guardrail\hook.json`），保存后立即生效，不需要重启 WorkBuddy。

```json
{
  "scanUrl": "http://192.168.120.68:18000/v1/scan",
  "failMode": "open",
  "blockLevels": ["block"],
  "timeoutMs": 5000
}
```

`blockLevels` 里加上 `"challenge"`，疑似风险也会被拦截。

## 管理员：通过内网统一分发和更新

1. 把 `tianlei-market.zip` 放到内网 HTTP 服务器上，或者把它解压后的内容提交到内网 Git 仓库。
2. 把地址发给大家，大家按“安装方式一”添加。
3. 插件有新版本时，替换服务器上的 `tianlei-market.zip`（文件名保持不变）。大家在 WorkBuddy 的插件市场里点击**刷新**即可更新，不需要重新安装。

## 卸载

通过界面导入的，在 WorkBuddy 插件管理里卸载插件、删除市场即可。通过脚本安装的，执行：

```bash
bash install.sh --uninstall
```

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

卸载后同样需要重启 WorkBuddy。

## 安装脚本改了什么

1. 把插件复制到 `~/.tianlei-guardrail/market`。
2. 首次安装时写入 `~/.tianlei-guardrail/hook.json`；如果已经存在，保留原配置。
3. 备份 `~/.workbuddy/settings.json`，备份文件名为 `settings.json.bak-tianlei-guardrail-时间`。然后在 settings.json 里加入两项：在 `extraKnownMarketplaces` 中登记插件市场，在 `enabledPlugins` 中启用插件。

## 已知限制

- 这是 PoC 版本，插件直接调用防护模型，不经过围栏平台的策略、名单和日志。
- 每次检测会增加约 0.2–0.7 秒的耗时。
- 员工可以在 WorkBuddy 里自行停用插件，目前还没有强制启用的办法。
- Windows 安装脚本还没有在 Windows 电脑上实际测试过。
