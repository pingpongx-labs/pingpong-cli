# PingPong CLI

Query PingPong account data from the terminal, scripts, and AI agents.

- Inspect account balances, balance movements, and transaction history.
- Discover MCP tools, inspect schemas, and preview requests.
- Sign in with DPoP-bound OAuth and inspect locally stored identity with `auth whoami`.

Current tools are read-only. The CLI defaults to demo (sandbox); use `--env production` for production.

## Install

Requires Node.js 22+ and npm. The installer supports macOS/Linux. GitHub Releases and an npm registry package have not been published yet. Obtain the local archive from your maintainer:

```sh
npm install -g ./pingpong-cli-0.1.0.tgz
pingpong --help
```

## Quickstart

Sign in to the default demo endpoint:

```sh
pingpong --env demo auth login
pingpong --env demo auth whoami
pingpong --env demo balances list --page_no 1 --page_size 1
```

If your administrator provides a different sandbox endpoint, export `PLATFORM_MCP_DEMO_URL` before signing in.

Configure and sign in to production separately:

```sh
export PLATFORM_MCP_PRODUCTION_URL=https://mcp.pingpongx.com/mcp
pingpong --env production auth login
```

`whoami` displays local token claims only: it does not verify signatures or remote authorization, and does not print tokens. CLI sign-in is separate from direct MCP connections in Codex, ChatGPT, or other clients.

## Security

- Sign-in requires DPoP and does not fall back to Bearer tokens.
- Credentials are stored in the OS credential vault by default (macOS Keychain or Linux Secret Service). Windows and headless environments without a vault must opt into file storage explicitly.
- `auth logout` revokes the current server session and removes local credentials. Contact your service maintainer to revoke other sessions.
- The OS vault does not isolate other agents or processes running as the same OS user with shell access. Use separate OS users or sandboxes when strong isolation is required.

## Documentation

- [English CLI guide](docs/cli.md)
- [中文 CLI 使用指南](docs/cli.zh-CN.md)

The guides cover installation, environments, authentication, commands, JSON input/output, schemas, agent usage, uninstallation, and troubleshooting. Public download commands are marked as pending publication.

## Feedback

Use [GitHub Issues](https://github.com/pingpongx-labs/pingpong-cli/issues) for sanitized bug reports and feature requests. Do not include credentials, personal information, balances, or transaction data.
