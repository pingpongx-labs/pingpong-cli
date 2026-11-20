# PingPong CLI


从终端、脚本和 AI Agent 查询 PingPong 账户数据。

- 查询账户余额、余额流水和交易流水。
- 发现 MCP 工具、查看 Schema、预览请求。
- 使用带 DPoP 的 OAuth 登录，通过 `auth whoami` 查看本地身份信息。

当前工具均为只读。默认 demo（沙箱），正式环境使用 `--env production`。

## 安装

需要 Node.js 22+ 和 npm；安装脚本面向 macOS/Linux。目前未发布 GitHub Releases 或 npm registry 包，请使用维护者提供的本地安装包：

```sh
npm install -g ./pingpong-cli-0.1.0.tgz
pingpong --help
```

## 快速开始

使用默认 demo 地址登录：

```sh
pingpong --env demo auth login
pingpong --env demo auth whoami
pingpong --env demo balances list --page_no 1 --page_size 1
```

如需连接管理员提供的其他沙箱地址，请在登录前覆盖 `PLATFORM_MCP_DEMO_URL`。

生产环境单独配置并登录：

```sh
export PLATFORM_MCP_PRODUCTION_URL=https://mcp.pingpongx.com/mcp
pingpong --env production auth login
```

`whoami` 只展示本地 token 的身份字段，不验签、不验证远端授权、不打印 token。CLI 登录与 Codex、ChatGPT 等直接 MCP 连接相互独立。

## 安全说明

- 登录要求 DPoP，不会自动降级为 Bearer token。
- 凭据默认保存在系统凭据库（macOS Keychain 或 Linux Secret Service）。Windows 和无凭据库的无头环境需显式选择文件存储。
- `auth logout` 会撤销当前服务端会话并清除本地凭据；其他会话的撤销请联系服务维护者。
- 系统凭据库不隔离同一系统用户下拥有 Shell 权限的其他 Agent 或进程。需要强隔离时，请使用不同系统用户或沙箱。

## 文档

- [中文 CLI 使用指南](docs/cli.zh-CN.md)
- [English CLI guide](docs/cli.md)

包含安装、环境、认证、命令、JSON 输入输出、Schema、Agent 使用、卸载与排障。公网下载命令已标注为待发布。

## 反馈

通过 [GitHub Issues](https://github.com/pingpongx-labs/pingpong-cli/issues) 提交脱敏问题或功能建议，不要包含凭据、个人信息、余额或流水。
