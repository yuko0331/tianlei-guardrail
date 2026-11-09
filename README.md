# 天磊安全围栏 · WorkBuddy 插件

给 WorkBuddy 加一道大模型安全检测。安装后，用户输入、工具调用、工具返回和最终回答都会先送到防护模型检测，命中风险就拦截或提示。**使用内置模型也能生效**，不需要改成自定义模型。

| 检测点 | 触发时机 | 命中风险时 |
| --- | --- | --- |
| 用户输入 | 发送消息后、模型处理前 | 拦截本次输入 |
| 工具调用 | 执行命令、写文件等操作前 | 拒绝执行 |
| 工具返回 | 读取网页、文件等内容后 | 替换返回内容，模型看不到原文 |
| 最终回答 | 回答结束后 | 回答已显示，只弹出提示并记录 |

## 在 WorkBuddy 里导入

1. 打开 WorkBuddy 的**技能市场**，切到**插件**标签。
2. 点击插件市场那一行最后的圆形 **+** 号（添加市场）。
3. “市场源”填：

   ```
   yuko0331/tianlei-guardrail
   ```

4. 添加成功后切到 **tianlei-market** 市场，找到 **tianlei-guardrail**（天磊安全围栏），点击**安装**。
5. 新建对话，发一句明显违规的话，应该会看到 `[天磊安全围栏] 检测到……已拦截`。

插件更新后，在插件市场里点**刷新**即可拿到新版本。

## 前提

- 电脑能访问防护模型接口，默认是 `http://192.168.120.68:18000/v1/scan`（公司内网地址）。
- 每次检测会把这次的输入、工具参数或回答内容发送到这个接口。

## 修改配置

编辑 `~/.tianlei-guardrail/hook.json`（Windows 为 `%USERPROFILE%\.tianlei-guardrail\hook.json`），没有就新建。保存后立即生效，不需要重启 WorkBuddy。

```json
{
  "scanUrl": "http://192.168.120.68:18000/v1/scan",
  "failMode": "open",
  "blockLevels": ["block"],
  "timeoutMs": 5000
}
```

| 字段 | 说明 |
| --- | --- |
| `scanUrl` | 防护模型地址 |
| `failMode` | 检测服务不可用时的处理：`open` 放行，`closed` 拦截 |
| `blockLevels` | 哪些等级要拦截；加上 `"challenge"` 后，疑似风险也会被拦截 |
| `timeoutMs` | 单次检测超时时间（毫秒） |

检测日志在 `~/.tianlei-guardrail/hook.log`，每条只保留内容开头 40 个字符，用于排查问题。

## 其他安装方式

不方便访问 GitHub 时，可以用 [installer](installer) 里的安装脚本，或运行 `bash pack.sh` 生成离线安装包。详见 [installer/README.md](installer/README.md)。

## 目录结构

```
.codebuddy-plugin/marketplace.json     插件市场清单
tianlei-guardrail/
  .codebuddy-plugin/plugin.json        插件清单
  hooks/hooks.json                     挂载的 Hook 事件
  scripts/guard.mjs                    检测脚本
installer/                             离线安装脚本和说明
test/inject.md                         藏有注入指令的测试文档
pack.sh                                打包脚本
```

## 已知限制

- 当前版本直接调用防护模型，不经过安全围栏平台的策略、名单和日志。
- 每次检测会增加约 0.2–0.7 秒的耗时。
- 用户可以在 WorkBuddy 里自行停用插件。
- 最终回答在检测前已经显示给用户，只能提示，不能撤回。
