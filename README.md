# PingPong CLI

![Version](https://img.shields.io/badge/version-0.1.0-orange)


Access your PingPong account data from the command line. The CLI provides balance, balance movement, and transaction history queries through a remote MCP server, supporting interactive exploration, scripts, and AI agents that can execute terminal commands without writing an HTTP client.

The default environment is **demo (sandbox)**. Select production with `--env production`. Current operations are read-only; available tools and permissions depend on the connected server.

## Who can use it

Installing the CLI does not require a specific account role. Sign-in and account authorization are governed by PingPong server policy. Users need the appropriate account and tool permissions.

## Before you begin

- Node.js 22+ and npm; check with `node --version` and `npm --version`.
- macOS/Linux for the installation script, with write access to its installation directories.
- A reachable MCP endpoint and an account able to complete browser authorization.

The CLI is a Node.js package, not a platform-specific native binary. Default sandbox and production domains are not yet bundled; configure your actual endpoints.

## Install

No npm registry package or GitHub Release has been published yet. Use the archive provided by your maintainer. Do not treat an identically named registry package as this project's official distribution.

### Local package

```sh
npm install -g ./pingpong-cli-0.1.0.tgz
pingpong --version
pingpong --help
```

### Installation script

Obtain `install.sh`, `pingpong-cli-0.1.0.tgz`, and `SHA256SUMS` from the same release and run from their directory:

```sh
PINGPONG_PACKAGE_FILE="$PWD/pingpong-cli-0.1.0.tgz" \
PINGPONG_CHECKSUM_FILE="$PWD/SHA256SUMS" \
sh ./install.sh
```

The script verifies SHA256 checksums, uses a separate npm installation directory, and places the command at `~/.local/bin/pingpong` by default. It does not require sudo by default or modify shell startup files. If needed:

```sh
export PATH="$HOME/.local/bin:$PATH"
command -v pingpong
```

Add this PATH setting to your shell startup file for persistence. npm and script-managed installations can coexist; inspect precedence with `which -a pingpong`.

### Download after publication

The following command will work only after the maintainer uploads all three artifacts for `v0.1.0` to [GitHub Releases](https://github.com/pingpongx-labs/pingpong-cli/releases). It is not an available download yet:

```sh
curl -fsSL https://github.com/pingpongx-labs/pingpong-cli/releases/download/v0.1.0/install.sh \
  | PINGPONG_REPO=pingpongx-labs/pingpong-cli sh
```

### Shell completion

Bash:

```bash
source <(pingpong completion bash)
```

Zsh:

```zsh
autoload -Uz compinit
compinit
source <(pingpong completion zsh)
```

Completion supplies static command and option candidates without querying remote tools. These commands affect the current shell only.

## Authenticate and inspect identity

### Sign in to sandbox

Replace the placeholder with the actual endpoint:

```sh
export PLATFORM_MCP_DEMO_URL=https://your-demo-domain.example/mcp
pingpong auth login
```

### Sign in to production

```sh
export PLATFORM_MCP_PRODUCTION_URL=https://your-production-domain.example/mcp
pingpong --env production auth login
```

Complete user sign-in, associated account selection, and tool authorization in your browser. The CLI discovers authorization endpoints from MCP metadata; the unified user system URL is configured on the server. OAuth uses authorization code flow with PKCE S256 and a local callback.

If the browser does not open automatically:

```sh
pingpong --env demo auth login --no-browser
```

Open the printed URL on the machine running the CLI. In a remote terminal or container, localhost may refer to a different machine; ensure the callback is reachable.

### Inspect your signed-in identity

```sh
pingpong --env demo auth whoami
pingpong --env production auth whoami
```

The response contains the environment, MCP URL, local sign-in status, expiry, and any available allowlisted identity claims from the stored JWT:

| Field | Meaning |
| --- | --- |
| `identity.sub` | Signed-in user's operatorId |
| `identity.email` | Sign-in email |
| `identity.department_id` | Selected account DID |
| `identity.client_id` | MCP OAuth client ID, not the user ID |
| `identity.scope` | Scopes declared in the token |

The response always includes `localOnly: true` and `identityVerified: false`. **Local decoding does not verify the signature or confirm remote token validity or authorization.** This is not a remote user profile endpoint. It does not return the access token, secrets, or the complete claims payload.

Missing, expired, or URL-mismatched credentials produce `loggedIn: false`, `identity: null`, and exit code 1. Locally valid credentials containing an opaque token, malformed JWT, or no displayable claims produce a null identity rather than invented user details.

For local authentication status without identity claims:

```sh
pingpong --env demo auth status
```

### Environments and credentials

| Environment | Selection | URL variable |
| --- | --- | --- |
| demo (default) | `--env demo` | `PLATFORM_MCP_DEMO_URL` |
| production | `--env production` | `PLATFORM_MCP_PRODUCTION_URL` |

Environment precedence is `--env` > `PLATFORM_MCP_ENV` > demo. With explicit environment selection, URL precedence is `--url` > the environment URL variable > bundled configuration; the legacy `PLATFORM_MCP_URL` is ignored. Without explicit selection, that legacy variable remains supported and takes precedence over the demo URL variable. Remote endpoints require HTTPS.

Credentials are isolated by the complete MCP URL and stored in `~/.platform-mcp/` by default; override the directory with `PLATFORM_MCP_CONFIG_DIR`. Refresh tokens are not currently supported; sign in again after expiry. The CLI does not read or modify credentials held by Codex, ChatGPT, or other clients.

## Commands

| Command | Purpose |
| --- | --- |
| `auth login / whoami / status / logout` | Sign in, inspect local identity or status, and sign out |
| `balances list` | Query account balances |
| `balance-movements list` | Query balance movements |
| `transactions list` | Query transaction history |
| `tools list / describe / call` | Discover, inspect, and invoke tools |
| `completion bash / zsh` | Generate completion scripts |

## Agent and script usage

### Discover commands and tools

```sh
pingpong --help
pingpong --tree
pingpong balances --tree
pingpong balances list --help
pingpong --env demo tools list
pingpong --env demo tools describe list_account_balances
```

### Query balances

```sh
pingpong --env demo balances list --page_no 1 --page_size 1
pingpong --env demo tools call list_account_balances \
  --args '{"page_no":1,"page_size":1}'
```

These are alternative entry points for the same query; you do not need to execute both. Business parameters use snake_case; legacy `pageNo/pageSize` are rejected. `page_no` starts at 1, and `page_size` is 1–100; both are required without defaults. Movement queries require an order ID or a complete time range of at most 365 days; transaction history also requires source. Check the relevant help before invoking a tool.

### Preview requests

```sh
pingpong --env demo balances list --page_no 1 --page_size 1 --dry-run
```

`--dry-run` previews the MCP request locally. It requires a target URL but does not access the network, read credentials, or validate complete business rules or permissions.

Server-side preview requires authentication:

```sh
pingpong --env demo tools call list_account_balances \
  --args '{"page_no":1,"page_size":1,"dry_run":true}'
```

The JSON argument `dry_run` invokes the MCP server for validation and a downstream request preview without calling the business API gateway. It differs from the local `--dry-run` option.

### Compact JSON and file input

```sh
pingpong --env demo balances list --page_no 1 --page_size 1 --compact
```

Alternatively, save arguments as `request.json`:

```json
{"page_no":1,"page_size":1}
```

```sh
pingpong --env demo tools call list_account_balances --args-file request.json
```

`--args`, `--args-file`, and business-parameter flags are mutually exclusive. Results go to stdout; errors and sign-in prompts go to stderr. Tool results with `isError=true` are still printed as JSON and produce exit code 1. Inspect the actual result; HTTP success alone does not establish a successful query.

### Inspect schemas

```sh
pingpong --env demo balances list --schema-only
```

`--api-schema-only` is an alias. Both require authentication and return the MCP tool schema, not OpenAPI, without executing the tool. The server may not provide outputSchema; some enums and cross-field rules require consulting help and server validation messages.

### Use with AI agents

Codex, Claude Code, Cursor, and other agents with terminal access can invoke an authenticated CLI. For example:

```text
Use the PingPong CLI to query demo account balances, page 1, one item per page.
Inspect local identity and the tool definition first; report the actual result or error.
```

Terminal execution permissions are controlled by the client. Using the CLI does not require registering MCP tools in the agent. To invoke tools directly in a chat, connect and authorize MCP separately in that client; CLI sign-in does not expose tools to ChatGPT or other applications.

Current operations are read-only, with no write confirmation flow. `--confirm`, `--prod`, `--scope`, `feedback`, `--data-stdin`, and `--no-telemetry` are unsupported. Use `--env production` for production.

## Sign out, revoke access, and uninstall

```sh
pingpong --env demo auth logout
```

This deletes local credentials for the selected URL only. It does not clear other URLs' credentials or revoke server-issued tokens. Contact your service maintainer for server-side revocation; no public connection-management page is currently provided.

For an npm installation:

```sh
npm uninstall -g pingpong-cli
```

For a script-managed installation, use your retained installer from the same release:

```sh
sh ./install.sh --uninstall
```

If you customized `PINGPONG_INSTALL_DIR` or `PINGPONG_STATE_DIR`, pass the same values when uninstalling. The script removes only its managed command link, preserves version and credential directories, and does not affect global npm installations.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No MCP URL configured | Configure the selected environment's URL; replace example domains |
| whoami returns identity=null | Check missing/expired local credentials; opaque or malformed JWTs cannot provide identity. The command does not establish remote validity |
| OAuth metadata does not match the URL | Ask the maintainer to check external resource/issuer settings and the loaded configuration group |
| Chat says the tool is unavailable | Check that agent's own connection, tool discovery, and plugin selection for the conversation |
| Downstream token acquisition returns 403 | Ask the maintainer to correlate diagnosticId with `gateway.token.request.failed`; reinstalling or signing in again will not fix a downstream denial |
| An old version still runs | Check PATH with `which -a pingpong`; run `rehash` in Zsh |
| Installation directory is not writable | Check npm prefix or choose a user-writable directory instead of defaulting to sudo |

## Data and feedback

The CLI currently provides no telemetry toggle and does not support `DISABLE_TELEMETRY` or `--no-telemetry`. Server-side request and diagnostic logs are separate from CLI options.

Report the version, environment, sanitized command, and error through [GitHub Issues](https://github.com/pingpongx-labs/pingpong-cli/issues) or your team's support channel. Do not publish tokens, passwords, app secrets, personal information returned by whoami, balances, or transaction records.
