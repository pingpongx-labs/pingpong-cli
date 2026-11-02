#!/bin/sh
# PingPong CLI installer. Requires Node.js 22+ and npm on macOS/Linux.
# Remote: PINGPONG_REPO=owner/repository sh install.sh
# Local:  PINGPONG_PACKAGE_FILE=/path/package.tgz PINGPONG_CHECKSUM_FILE=/path/SHA256SUMS sh install.sh
# Remove the managed command: sh install.sh --uninstall
set -eu

BUNDLED_VERSION="0.1.0"
VERSION="${PINGPONG_VERSION:-$BUNDLED_VERSION}"
INSTALL_DIR="${PINGPONG_INSTALL_DIR:-$HOME/.local/bin}"
STATE_DIR="${PINGPONG_STATE_DIR:-$HOME/.local/share/pingpong-cli}"
MARKER='pingpong-cli-installer-v1'
tmp=''
stage=''
link_tmp=''
locked=0

fail() { printf '错误：%s\n' "$1" >&2; exit "${2:-1}"; }
step() { printf '%s\n' "$*"; }
cleanup() {
    [ -z "$link_tmp" ] || rm -rf "$link_tmp"
    [ -z "$stage" ] || rm -rf "$stage"
    [ -z "$tmp" ] || rm -rf "$tmp"
    [ "$locked" -eq 0 ] || rmdir "$STATE_DIR/.install-lock" 2>/dev/null || true
}
trap cleanup 0
trap 'exit 1' 1 2 3 15

usage() {
    cat <<'HELP'
PingPong CLI installer (macOS/Linux, Node.js 22+ and npm)
Usage: sh install.sh [--uninstall|--help]

Environment:
  PINGPONG_REPO             GitHub owner/repository (required for remote installation)
  PINGPONG_VERSION          Release version, with optional v prefix (default: bundled version)
  PINGPONG_INSTALL_DIR      Command directory (default: ~/.local/bin)
  PINGPONG_STATE_DIR        Managed versions (default: ~/.local/share/pingpong-cli)
  PINGPONG_PACKAGE_FILE     Local npm tgz instead of GitHub download
  PINGPONG_CHECKSUM_FILE    Local SHA256SUMS, required with PACKAGE_FILE

SHA256 verification is mandatory. No shell rc files are modified.
Uninstall removes only the managed command link; versions and login credentials are kept.
Exit codes: 0 success; 1 invalid configuration/install failure; 2 unsupported runtime;
            3 checksum failure; 4 download failure.
HELP
}

validate_directory() {
    case "$1" in
        /*) ;;
        *) fail '安装和状态目录必须为绝对路径。' ;;
    esac
    case "$1" in
        /|"$HOME"|*/../*|*/..|*/./*|*/.|*'
'*) fail '安装和状态目录不能为根目录、HOME，或包含相对路径段/换行。' ;;
    esac
}

owned_state() {
    [ ! -L "$STATE_DIR" ] && [ -f "$STATE_DIR/.installer-owner" ] &&
        [ "$(cat "$STATE_DIR/.installer-owner")" = "$MARKER" ]
}

check_target() {
    if [ -e "$INSTALL_DIR/pingpong" ] || [ -L "$INSTALL_DIR/pingpong" ]; then
        [ -L "$INSTALL_DIR/pingpong" ] && owned_state ||
            fail '已有 pingpong 不属于本安装器，拒绝覆盖。请选择其他 PINGPONG_INSTALL_DIR。'
        target=$(readlink "$INSTALL_DIR/pingpong")
        case "$target" in
            "$STATE_DIR/releases/"*"/bin/pingpong") ;;
            *) fail '已有命令链接不属于本安装器，拒绝覆盖。' ;;
        esac
        release_dir=${target#"$STATE_DIR/releases/"}
        release_dir=${release_dir%/bin/pingpong}
        case "$release_dir" in ''|*/*|.|..) fail '已有命令链接路径无效。' ;; esac
    fi
}

main() {
    [ "$#" -le 1 ] || fail '参数过多；使用 --help 查看用法。'
    case "${1:-}" in
        --help|-h) usage; return ;;
        ''|--uninstall) ;;
        *) fail '未知参数；使用 --help 查看用法。' ;;
    esac
    INSTALL_DIR=${INSTALL_DIR%/}
    STATE_DIR=${STATE_DIR%/}
    validate_directory "$INSTALL_DIR"
    validate_directory "$STATE_DIR"
    [ "$INSTALL_DIR" != "$STATE_DIR" ] || fail '安装目录与状态目录不能相同。'
    check_target
    if [ "${1:-}" = '--uninstall' ]; then
        if owned_state; then
            mkdir "$STATE_DIR/.install-lock" 2>/dev/null || fail '安装器正在运行或留有锁，请检查状态目录。'
            locked=1
            check_target
        fi
        if [ -L "$INSTALL_DIR/pingpong" ]; then
            rm "$INSTALL_DIR/pingpong"
            step "已移除命令：$INSTALL_DIR/pingpong"
        else
            step '未找到本安装器的命令，无需卸载。'
        fi
        step "已保留版本目录 $STATE_DIR 和登录凭据。npm 全局安装不受影响。"
        return
    fi
    case "$(uname -s)" in Darwin|Linux) ;; *) fail '仅支持 macOS/Linux。' 2 ;; esac
    command -v node >/dev/null 2>&1 || fail '请先安装 Node.js 22+。' 2
    command -v npm >/dev/null 2>&1 || fail '请先安装 npm。' 2
    node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)' || fail '需要 Node.js 22+。' 2
    VERSION=${VERSION#v}
    node -e 'process.exit(/^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$/.test(process.argv[1]) ? 0 : 1)' "$VERSION" || fail '版本必须是明确版本号，例如 0.1.0；不支持 latest。'
    asset="pingpong-cli-$VERSION.tgz"
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/pingpong-install.XXXXXX")
    if [ -n "${PINGPONG_PACKAGE_FILE:-}" ]; then
        [ -n "${PINGPONG_CHECKSUM_FILE:-}" ] || fail '本地安装必须指定 PINGPONG_CHECKSUM_FILE。'
        cp "$PINGPONG_PACKAGE_FILE" "$tmp/$asset" || fail '无法读取本地安装包。'
        cp "$PINGPONG_CHECKSUM_FILE" "$tmp/SHA256SUMS" || fail '无法读取校验文件。'
    else
        repo="${PINGPONG_REPO:-}"
        node -e 'process.exit(/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(process.argv[1]) ? 0 : 1)' "$repo" || fail '请设置 PINGPONG_REPO=owner/repository；尚未发布时使用本地包安装。'
        command -v curl >/dev/null 2>&1 || fail '下载需要 curl。'
        base="https://github.com/$repo/releases/download/v$VERSION"
        step "下载 PingPong CLI $VERSION"
        curl --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 180 -fsSL "$base/$asset" -o "$tmp/$asset" || fail '安装包下载失败，请确认 Release 和版本已发布。' 4
        curl --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 60 -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS" || fail '校验文件下载失败。' 4
    fi
    # Verify exact asset identity and checksum before npm sees the archive.
    node - "$tmp/$asset" "$tmp/SHA256SUMS" "$asset" <<'NODE' || fail 'SHA256 校验失败，未安装下载内容。' 3
const fs = require('node:fs');
const crypto = require('node:crypto');
const [archive, manifest, asset] = process.argv.slice(2);
const lines = fs.readFileSync(manifest, 'utf8').split(/\r?\n/).filter(Boolean);
const matches = lines.map(line => /^([0-9a-fA-F]{64})  (.+)$/.exec(line)).filter(row => row && row[2] === asset);
const actual = crypto.createHash('sha256').update(fs.readFileSync(archive)).digest('hex');
if (matches.length !== 1 || matches[0][1].toLowerCase() !== actual) process.exit(1);
NODE
    step 'SHA256 校验通过。'
    if [ -e "$STATE_DIR" ] || [ -L "$STATE_DIR" ]; then
        owned_state || fail '状态目录不是本安装器管理的目录，拒绝使用。'
    else
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$MARKER" > "$STATE_DIR/.installer-owner"
    fi
    mkdir "$STATE_DIR/.install-lock" 2>/dev/null || fail '安装器正在运行或留有锁，请检查状态目录。'
    locked=1
    check_target
    mkdir -p "$STATE_DIR/releases" "$INSTALL_DIR"
    stage=$(mktemp -d "$STATE_DIR/releases/$VERSION.XXXXXX")
    npm install --global --prefix "$stage" --cache "$tmp/npm-cache" --offline --ignore-scripts --no-audit --no-fund "$tmp/$asset" || fail 'npm 安装失败，原有命令未切换。'
    node - "$stage/lib/node_modules/pingpong-cli/package.json" "$VERSION" <<'NODE' || fail '安装包身份或版本不匹配。'
const fs = require('node:fs');
const pkg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (pkg.name !== 'pingpong-cli' || pkg.version !== process.argv[3] || pkg.bin?.pingpong !== 'bin/pingpong.js') process.exit(1);
NODE
    new_target="$stage/bin/pingpong"
    [ "$("$new_target" --version)" = "$VERSION" ] || fail '安装后的 CLI 版本检查失败。'
    link_tmp=$(mktemp -d "$INSTALL_DIR/.pingpong-link.XXXXXX")
    ln -s "$new_target" "$link_tmp/pingpong"
    # Keep validated files if interrupted while atomically switching the command link.
    completed_stage=$stage
    stage=''
    if ! mv -f "$link_tmp/pingpong" "$INSTALL_DIR/pingpong"; then
        stage=$completed_stage
        fail '命令切换失败，原有版本已保留。'
    fi
    step "已安装 pingpong $VERSION：$INSTALL_DIR/pingpong"
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *) step "请把 $INSTALL_DIR 加入 PATH，然后运行 pingpong --help。未自动修改 shell 配置。" ;;
    esac
}

main "$@"
