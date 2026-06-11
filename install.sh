#!/usr/bin/env bash
set -euo pipefail

# ─── paths ────────────────────────────────────────────────────────────────────
BIN_DIR="$HOME/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/cc-sandbox"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── preflight: required tools (report all that are missing, then abort) ───────
missing=0

if ! command -v bwrap >/dev/null 2>&1; then
    echo "error: bwrap (bubblewrap) is not installed." >&2
    if   command -v apt    >/dev/null 2>&1; then echo "  install it:  sudo apt install bubblewrap"   >&2
    elif command -v dnf    >/dev/null 2>&1; then echo "  install it:  sudo dnf install bubblewrap"   >&2
    elif command -v pacman >/dev/null 2>&1; then echo "  install it:  sudo pacman -S bubblewrap"     >&2
    elif command -v zypper >/dev/null 2>&1; then echo "  install it:  sudo zypper install bubblewrap" >&2
    elif command -v apk    >/dev/null 2>&1; then echo "  install it:  sudo apk add bubblewrap"       >&2
    else echo "  install the 'bubblewrap' package with your package manager." >&2
    fi
    missing=1
fi

if ! command -v claude >/dev/null 2>&1; then
    echo "error: claude (Claude Code) is not installed or not on PATH." >&2
    echo "  get it:  https://claude.com/claude-code" >&2
    missing=1
fi

if [[ "$missing" -eq 1 ]]; then
    echo "Aborting — install the missing dependencies above and re-run." >&2
    exit 1
fi

# ─── install ──────────────────────────────────────────────────────────────────
echo "Installing cc-sandbox:"

install -Dm755 "$SRC_DIR/cc-sandbox" "$BIN_DIR/cc-sandbox"
echo "  [ok]   $BIN_DIR/cc-sandbox"

install -Dm644 "$SRC_DIR/.cc-sandbox.conf" "$DATA_DIR/.cc-sandbox.conf"
echo "  [ok]   $DATA_DIR/.cc-sandbox.conf"

# ─── PATH check ────────────────────────────────────────────────────────────────
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        rc="your shell startup file"
        case "${SHELL:-}" in
            */bash) rc="~/.bashrc" ;;
            */zsh)  rc="~/.zshrc"  ;;
        esac
        echo "  [warn] $BIN_DIR is not on your PATH. Add it with:"
        echo "           echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> $rc"
        ;;
esac

echo "Done. Run 'cc-sandbox init' in a project to get started."
