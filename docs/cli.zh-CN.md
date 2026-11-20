# PingPong CLI

[English](cli.md) | 简体中文

> **安全升级**：本版 CLI 登录要求服务端支持 DPoP，凭据默认保存在系统凭据库，`auth logout` 会撤销当前服务端会话。升级前请先确认服务端已完成对应部署；源码修改不会自动更新已有的 `dist` 包或已安装版本。

从命令行访问 PingPong 账户数据。CLI 通过远程 MCP 服务提供余额、余额流水和交易流水查询，可用于交互探索、脚本及能够执行终端命令的 AI Agent，无需自行编写 HTTP 客户端。

默认连接 **demo（沙箱）**，正式环境使用 `--env production`。当前仅提供只读查询；可用工具和权限以所连接服务为准。

## 谁可以使用

安装 CLI 不要求特定账户角色。登录和账号授权由 PingPong 服务端策略决定，需要用户具有目标账号及工具的相应权限。

## 开始前准备

- Node.js 22+ 和 npm，可用 `node --version`、`npm --version` 检查。
- macOS/Linux 安装脚本及其安装目录的写权限。
- 可访问的 MCP 地址和可完成浏览器授权的账户。
- 默认凭据存储依赖系统凭据库：macOS Keychain，或已安装并解锁的 Linux Secret Service（`secret-tool`）。Windows 和无凭据库的无头环境会明确失败，只有在接受风险后显式设置 `PLATFORM_MCP_CREDENTIAL_STORE=file` 才能使用文件存储。

CLI 是 Node.js 包，不是按 CPU 架构分发的独立二进制。demo 默认地址为 `https://demo-mcp.pingpongx.com/mcp`，生产地址为 `https://mcp.pingpongx.com/mcp`；如果部署地址不同，可用对应环境变量或 `--url` 覆盖。

## 安装

当前未发布 npm registry 包或 GitHub Release。先使用维护者提供的 tgz；不要把同名 npm 包视为本项目的官方分发。

### 本地安装包

```sh
npm install -g ./pingpong-cli-0.1.0.tgz
pingpong --version
pingpong --help
```

### 安装脚本

取得同一版本的 `install.sh`、`pingpong-cli-0.1.0.tgz` 和 `SHA256SUMS`，在该目录执行：

```sh
PINGPONG_PACKAGE_FILE="$PWD/pingpong-cli-0.1.0.tgz" \
PINGPONG_CHECKSUM_FILE="$PWD/SHA256SUMS" \
sh ./install.sh
```

脚本验证 SHA256，使用独立 npm 安装目录，默认命令为 `~/.local/bin/pingpong`。不需要默认使用 sudo，也不自动修改 shell 启动文件。如该目录不在 PATH：

```sh
export PATH="$HOME/.local/bin:$PATH"
command -v pingpong
```

需要持久生效时自行写入 shell 启动文件。npm 与脚本安装可以共存，通过 `which -a pingpong` 检查实际优先使用的版本。

### 发布后的下载方式

以下命令仅在维护者向 [GitHub Releases](https://github.com/pingpongx-labs/pingpong-cli/releases) 上传 `v0.1.0` 的三个产物后可用，目前不能作为可用下载入口：

```sh
curl -fsSL https://github.com/pingpongx-labs/pingpong-cli/releases/download/v0.1.0/install.sh \
  | PINGPONG_REPO=pingpongx-labs/pingpong-cli sh
```

### 命令补全

Bash：

```bash
source <(pingpong completion bash)
```

Zsh：

```zsh
autoload -Uz compinit
compinit
source <(pingpong completion zsh)
```

补全提供静态命令与参数候选，不查询远端工具。上述命令仅作用于当前 shell。

## 登录与身份

### 沙箱登录

使用默认 demo 地址可直接登录：

```sh
pingpong --env demo auth login
```

如需连接其他沙箱地址，先覆盖 `PLATFORM_MCP_DEMO_URL` 再登录：

```sh
export PLATFORM_MCP_DEMO_URL=https://your-demo-domain.example/mcp
pingpong --env demo auth login
```

### 单独配置浏览器登录地址

每个环境 profile 支持可选的 `authorizationEndpoint`，可通过 `PLATFORM_MCP_DEMO_AUTHORIZATION_ENDPOINT` 或 `PLATFORM_MCP_PRODUCTION_AUTHORIZATION_ENDPOINT` 覆盖。未配置或为空时，使用 OAuth metadata 返回的授权地址。

该项只改变浏览器打开的登录地址；客户端注册和 token 兑换仍使用发现的 OAuth 服务。`state`、PKCE、`scope`、`resource` 和 `bu=open-platform` 保持原有参数。指定页面需要支持接续此 OAuth 流程。

### 正式环境登录

```sh
export PLATFORM_MCP_PRODUCTION_URL=https://mcp.pingpongx.com/mcp
pingpong --env production auth login
```

浏览器中完成用户登录、关联账号选择与工具授权。CLI 使用环境配置的授权页面，正式环境默认为 `https://oauth.pingpongx.com/auth/authorize/mcp/environment?bu=open-platform`，可用 `PLATFORM_MCP_PRODUCTION_AUTHORIZATION_ENDPOINT` 覆盖。OAuth 使用授权码 + PKCE S256，完成本机回调。

浏览器无法自动打开时：

```sh
pingpong --env demo auth login --no-browser
```

在运行 CLI 的机器上手动打开输出链接。远程终端/容器的 localhost 不一定是浏览器所在机器，需确保回调可达。

### 查看登录身份

```sh
pingpong --env demo auth whoami
pingpong --env production auth whoami
```

返回当前环境、MCP URL、本地登录状态、到期时间，以及本地 JWT 中存在的白名单身份字段：

| 字段 | 含义 |
| --- | --- |
| `identity.sub` | 登录用户 operatorId |
| `identity.email` | 登录邮箱 |
| `identity.department_id` | 授权选择的账号 DID |
| `identity.client_id` | MCP OAuth 客户端 ID，不是用户 ID |
| `identity.scope` | token 中声明的权限范围 |

输出固定包含 `localOnly: true`、`identityVerified: false`。**本地解码不验签，不确认服务端 token 或授权仍有效**；不是远端用户资料接口。不返回 access token、secret 或完整 claims。

没有凭据、已过期或凭据 URL 不匹配时，`loggedIn` 为 false、`identity` 为 null，退出码为 1。有效本地凭据使用 opaque token、损坏 JWT 或没有可展示字段时，身份为 null，不据此编造用户信息。

仅检查本地登录状态时仍可使用：

```sh
pingpong --env demo auth status
```

### 环境与凭据

| 环境 | 选择 | 地址变量 |
| --- | --- | --- |
| demo（默认） | `--env demo` | `PLATFORM_MCP_DEMO_URL` |
| production | `--env production` | `PLATFORM_MCP_PRODUCTION_URL` |

环境优先级为 `--env` > `PLATFORM_MCP_ENV` > demo。显式选择环境时，地址优先级为 `--url` > 对应环境变量 > 内置配置，并忽略旧 `PLATFORM_MCP_URL`。未显式选择环境时，兼容旧变量，其优先于 demo 地址变量。远程地址要求 HTTPS。

凭据按完整 MCP URL 隔离，默认保存到系统凭据库；`~/.platform-mcp/` 只存非敏感标记，可用 `PLATFORM_MCP_CONFIG_DIR` 指定目录。显式设置 `PLATFORM_MCP_CREDENTIAL_STORE=file` 才使用该目录存明文凭据；文件模式使用 0700 目录和 0600 文件，但不隔离同一系统用户下的其他进程。旧版 JSON 凭据会在首次读取时迁移到系统凭据库。登录要求服务端声明并签发 DPoP token，不会自动降级为 Bearer。当前没有 refresh token，到期后重新登录。CLI 不读取或改写 Codex、ChatGPT 等其他客户端凭据。

## 命令概览

| 命令 | 用途 |
| --- | --- |
| `auth login / whoami / status / logout` | 登录、本地身份、状态和退出 |
| `balances list` | 查询账户余额 |
| `balance-movements list` | 查询余额流水 |
| `transactions list` | 查询交易流水 |
| `tools list / describe / call` | 工具发现、定义和调用 |
| `completion bash / zsh` | 生成补全脚本 |

## Agent 与脚本使用

### 发现命令和工具

```sh
pingpong --help
pingpong --tree
pingpong balances --tree
pingpong balances list --help
pingpong --env demo tools list
pingpong --env demo tools describe list_account_balances
```

### 查询余额

```sh
pingpong --env demo balances list --page_no 1 --page_size 1
pingpong --env demo tools call list_account_balances \
  --args '{"page_no":1,"page_size":1}'
```

这两个命令是同一查询的不同入口，不必都执行。业务参数使用 snake_case；旧 `pageNo/pageSize` 不再接受。`page_no` 从 1 开始，`page_size` 为 1–100，均无默认值。流水需订单号或最多 365 天的完整时间范围；交易流水另需 source，执行前查看对应帮助。

### 预览请求

```sh
pingpong --env demo balances list --page_no 1 --page_size 1 --dry-run
```

`--dry-run` 仅本地预览 MCP 请求，需要目标 URL，但不联网、不读取凭据、不验证完整业务规则或权限。

服务端预览需要登录：

```sh
pingpong --env demo tools call list_account_balances \
  --args '{"page_no":1,"page_size":1,"dry_run":true}'
```

JSON 参数 `dry_run` 会调用 MCP 服务执行校验，返回下游请求预览，但不调用业务网关；不同于本地选项 `--dry-run`。

### 紧凑 JSON 与文件参数

```sh
pingpong --env demo balances list --page_no 1 --page_size 1 --compact
```

也可以将参数写入 `request.json`：

```json
{"page_no":1,"page_size":1}
```

```sh
pingpong --env demo tools call list_account_balances --args-file request.json
```

`--args`、`--args-file` 和业务参数 flags 不能混用。结果写 stdout，错误和登录提示写 stderr。工具返回 `isError=true` 时仍输出 JSON，退出码为 1。必须检查实际结果，不能仅以 HTTP 成功判断查询成功。

### 查看 Schema

```sh
pingpong --env demo balances list --schema-only
```

`--api-schema-only` 是别名，两者都需要登录，返回 MCP 工具 Schema，不是 OpenAPI，不执行工具。当前服务可能没有 outputSchema，部分枚举和跨字段约束需结合帮助及服务端错误提示。

### 与 AI Agent 配合

能执行终端命令的 Codex、Claude Code、Cursor 等可以直接使用已登录的 CLI。例如：

```text
通过 PingPong CLI 查询 demo 账户余额，第 1 页、每页 1 条。
先查看登录身份与工具定义；报告实际查询结果或错误，不推测余额。
```

终端执行权限由客户端控制。直接调用 CLI 不要求 Agent 同时注册 MCP。若希望在对话中直接使用 MCP 工具，必须在对应客户端独立连接和授权；CLI 登录不会自动为 ChatGPT 等提供工具。

当前只读，无写入确认流程，不支持 `--confirm`、`--prod`、`--scope`、`feedback`、`--data-stdin` 或 `--no-telemetry`。正式环境使用 `--env production`。

## 退出、撤销与卸载

```sh
pingpong --env demo auth logout
```

撤销所选 URL 的当前服务端会话并清除本地凭据，不影响其他会话。远端撤销失败会明确提示并以非零状态退出；本地没有凭据不代表此前的所有授权都已撤销。CLI 只撤销当前登录会话，其他会话的撤销请联系服务维护者。

npm 安装卸载：

```sh
npm uninstall -g pingpong-cli
```

脚本安装使用保留的同版安装脚本：

```sh
sh ./install.sh --uninstall
```

自定义 `PINGPONG_INSTALL_DIR`、`PINGPONG_STATE_DIR` 时，卸载传入相同值。脚本只移除自管命令链接，保留版本及凭据目录，不影响 npm 全局安装。

## 排障

| 现象 | 检查方向 |
| --- | --- |
| 未配置 MCP URL | 配置所选环境地址；示例域名必须替换 |
| whoami 返回 identity=null | 检查本地凭据是否存在/过期；opaque 或损坏 JWT 不提供身份；不意味着已有远端验证 |
| OAuth metadata 与 URL 不匹配 | 维护者检查外部 resource/issuer 和实际加载的配置组 |
| 对话提示未提供工具 | 检查该 Agent 自己的连接、工具发现和会话插件选择 |
| 获取下游 access token 403 | 维护者按 diagnosticId 查询 `gateway.token.request.failed`；重装或登录不能修复下游拒绝 |
| 仍运行旧版本 | `which -a pingpong` 检查 PATH；Zsh 用 `rehash` 刷新 |
| 目录不可写 | 检查 npm prefix 或选择用户可写目录，不默认使用 sudo |

## 数据与反馈

当前 CLI 未提供遥测开关，不支持 `DISABLE_TELEMETRY` 或 `--no-telemetry`。服务端可能记录请求和诊断日志，这与 CLI 选项不同。

通过 [GitHub Issues](https://github.com/pingpongx-labs/pingpong-cli/issues) 或团队支持渠道反馈版本、环境、脱敏命令和错误。不要公开 token、密码、appSecret、whoami 中的用户信息、余额或流水。

系统凭据库不能隔离同一系统用户下拥有 Shell 权限的其他 Agent 或进程。需要强隔离时，应为不同 Agent 使用不同系统用户或沙箱，并分别登录、分别配置凭据目录。
