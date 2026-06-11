# cc-sandbox

Run [Claude Code](https://claude.com/claude-code) inside a [bubblewrap](https://github.com/containers/bubblewrap)
sandbox that exposes only what Claude needs — your project, Claude's own state, and
a read-only slice of the system. Everything else on your machine stays invisible to it.

## Why

By default Claude Code can read and write anywhere your user account can. cc-sandbox
wraps it in `bwrap` with an explicit allowlist: the project directory and Claude's
config are read-write, the system is read-only, and the rest of `$HOME` is simply not
mounted — so it cannot be touched, leaked, or deleted.

## Requirements

- `bwrap` — the [bubblewrap](https://github.com/containers/bubblewrap) sandbox
  (Debian/Ubuntu: `apt install bubblewrap`, Fedora: `dnf install bubblewrap`,
  Arch: `pacman -S bubblewrap`)
- `claude` — the Claude Code CLI, on your `PATH` (or point `CLAUDE_BIN` at it)

## Install

```sh
install -Dm755 cc-sandbox ~/.local/bin/cc-sandbox
install -Dm644 .cc-sandbox.conf ~/.local/share/cc-sandbox/.cc-sandbox.conf
```

Make sure `~/.local/bin` is on your `PATH`. (Respects `$XDG_DATA_HOME` if set.)

## Usage

```sh
cd your-project
cc-sandbox init     # one-time: drop .cc-sandbox.conf, update .gitignore
cc-sandbox          # launch Claude Code, sandboxed
```

Any arguments are passed straight through to `claude`:

```sh
cc-sandbox --help
cc-sandbox -p "explain this repo"
```

## Configuration

`cc-sandbox init` drops a `.cc-sandbox.conf` in the project root. It is sourced as bash:

| Variable | Purpose |
|---|---|
| `EXTRA_BIND_RO` | Space-separated paths to mount **read-only** into the sandbox |
| `EXTRA_BIND_RW` | Space-separated paths to mount **read-write** |
| `ENV_VARS` | Space-separated `KEY=VALUE` pairs to set inside the sandbox |
| `DEBUG` | `true` → write the full `bwrap` command to `.cc-sandbox.log` and exit without launching |

`init` also adds `.cc-sandbox.conf` and `.cc-sandbox.log` to the project's `.gitignore`
(both are local/user-specific and should not be committed).

## What the sandbox exposes

Everything below is the *complete* list of what Claude can see. Read-only unless noted.

| Path | Mode | Why exposed | Required? |
|---|---|---|---|
| `/usr` | ro | System binaries & libraries — Claude shells out to `git`, `rg`, `bash`, etc. | **Yes** |
| `/lib`, `/bin` | ro | Shells and libraries on split-`usr` systems; on merged-`usr` these are symlinks into `/usr` but the paths must still exist inside | **Yes** |
| `/lib64` | ro | The ELF dynamic linker (`/lib64/ld-linux-x86-64.so.2`) is hard-coded into every dynamically-linked binary | **Yes** |
| `/etc/resolv.conf` | ro | DNS servers — resolved via `readlink -f`, so it works with systemd-resolved, NetworkManager, or a plain file | **Yes** — no DNS, no API |
| `/etc/ssl/certs`, `/etc/pki` | ro | CA certificates for TLS; Claude talks HTTPS to the API | **Yes** — no certs, no TLS |
| `/etc/hosts` | ro | Host/localhost name resolution | Optional — degrades gracefully |
| `/etc/passwd`, `/etc/group` | ro | UID→name lookups; some tools (`git`) warn without an entry | Optional but recommended |
| `~/.claude` | **rw** | Claude's state: **auth** (`.credentials.json`), sessions, history, projects, cache, plugins, memory | **Yes** — without it Claude is logged out and stateless |
| `~/.claude.json` | **rw** | Config & metadata: `userID`, account info, onboarding flags, per-project trust & history | **Yes** for a seamless experience (not auth — that lives in `~/.claude`) |
| `$PWD` | **rw** | The project you're working on | **Yes** — the whole point |
| `/proc` | proc | Process filesystem — required by Node and many tools | **Yes** |
| `/dev` | dev | Minimal device nodes (`/dev/null`, `/dev/urandom`, tty) | **Yes** |
| `/tmp` | tmpfs | Scratch space, isolated and wiped when the sandbox exits | **Yes** |

The sandbox runs with `--unshare-all --share-net`: isolated PID/IPC/etc. namespaces,
but network **is** shared (Claude needs to reach the API).

## Debug mode

To inspect the exact `bwrap` invocation without launching Claude, set `DEBUG=true` in
`.cc-sandbox.conf` and run `cc-sandbox`. The command is written to `.cc-sandbox.log`
in the project and the script exits.
