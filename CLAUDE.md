# dotzsh

Shell configuration dotfiles for zsh, fish, and bash, distributed as a Nix flake with home-manager integration.

## Project Structure

```
.
├── flake.nix              # Nix flake: homeManagerModules + packages + devshell
├── zshrc                  # Main zsh entry point (sourced by home-manager)
├── zsh-config.zsh         # Zsh options, keybindings, completion, prompt, hooks
├── common.sh.in           # Template: generates common.sh (bash/zsh shared aliases & functions)
├── common.fish.in         # Template: generates common.fish (fish shared aliases & functions)
├── plugins/               # Bundled Zsh-only plugins (git submodules or vendored)
│   ├── fast-syntax-highlighting/
│   ├── zsh-autosuggestions/
│   ├── zsh-history-substring-search/
│   └── zsh-syntax-highlighting/
├── plugsfile/             # Custom plugins (.plugin.sh shared, .plugin.zsh Zsh-only)
│   ├── colored-man-pages.plugin.sh
│   ├── copybuffer.plugin.sh
│   ├── copypath.plugin.sh
│   └── docker-compose.plugin.sh
└── scripts/
    └── newuser            # Zsh new-user install script
```

`plugins/` is Zsh-only. Files named `plugsfile/*.plugin.sh` must remain source-compatible with both Bash and Zsh; both shells load the same file directly. Use `.plugin.zsh` for fragments that require Zsh-specific syntax.

## Architecture

### Template Generation Pattern

The `.in` files are bash scripts that **generate** shell-specific config files at build/install time:

- `common.sh.in` → generates `common.sh` (sourced by zsh and bash)
- `common.fish.in` → generates `common.fish` (sourced by fish)

They use a buffer pattern (`_dotzsh_append_buffer << 'EOF'`) to assemble output, with conditional blocks based on detected commands (`_dotzsh_cmd_exists`) and OS (`_dotzsh_is_linux`).

**Output destinations** (controlled by flags):
- `-1`: `~/.cache/dotzsh/common.{sh,fish}` (default for home-manager activation)
- `-2`: current directory
- `-3`: `/tmp/common.{sh,fish}`
- `stdout`: stdout

### Zsh Loading Order

1. `zshrc` resolves its own real path (handles symlinks)
2. Sources `localpre/*.sh` from `./localpre/` or `~/.cache/dotzsh/localpre/`
3. Loads plugins: `zsh-autosuggestions`, `fast-syntax-highlighting`
4. Sources shared `plugsfile/*.plugin.sh` and Zsh-only `plugsfile/*.plugin.zsh`
5. Sources `zsh-config.zsh` (options, keybindings, prompt, hooks)
6. Sources generated `common.sh` from `./common.sh`, `~/.cache/dotzsh/common.sh`, or `/tmp/common.sh`
7. Sources `localpost/*.sh`
8. Initializes zoxide if available

### Fish Loading Order

1. `common.fish.in` generates `common.fish` (via `dotzsh-fish -1[gp]`)
2. Home-manager sets `programs.fish.shellInitLast` to source `~/.cache/dotzsh/common.fish`

### Nix Flake Structure

- **homeManagerModules.default**: Provides `programs.dotzsh` with options:
  - `enable` — master switch
  - `enableZshIntegration` — sources `zshrc` via `programs.zsh.initContent` (order 1200)
  - `enableFishIntegration` — sources `common.fish` via `programs.fish.shellInitLast`
  - `enableFishPrompt` — generates custom fish prompt
  - `fishGreetingMode` — `null` (fish default) / `"empty"` (suppress) / `"custom"` (dotzsh nix-aware greeting)
- **packages**: `cm-init` (dotzsh-cm), `fish-init` (dotzsh-fish)
- **devshell**: exposes `cm-init` and `fish-init` commands
- **Systems**: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin

## Key Functions & Aliases

Both `common.sh.in` and `common.fish.in` define equivalent functions:

| Function | Purpose |
|----------|---------|
| `fwh` | Find Where — traces command origin (alias → function → executable → symlink) |
| `gaa` / `groa` / `grga` | git add/restore/staged-restore from repo root |
| `gitur` | git add + commit + pull --rebase + push all remotes |
| `gcldi` | Interactive cleanup of untracked files |
| `cdt` | cd to file's parent directory |
| `upd N` | Go up N directories |
| `swap2file` | Swap two files |
| `dkex` | Exec into docker container with best available shell |
| `htdel` | Delete history entries matching pattern |
| `dus` | Disk usage sorted |
| `qip` | Query IP geolocation (requires jq for formatted output) |

## Conventions

- **Commit format**: Conventional Commits — `type(scope): subject`
  - Types: feat, fix, refactor, docs, style, chore
  - Subject: lowercase, no period
- **Shell portability**: Functions are written in parallel for bash/zsh (in `.sh.in`) and fish (in `.fish.in`)
- **Conditional generation**: Both `.in` files check for command availability before generating tool-specific functions (e.g., `jq`, `eza`, `pigz`, `rsync`, `systemctl`/`launchctl`)
- **Platform detection**: `uname` → `_dotzsh_is_linux` flag; Linux vs Darwin paths diverge for `sed -i`, `du`, `ps`, clipboard, etc.
- **No hardcoded paths**: Uses `$HOME`, `$XDG_CACHE_HOME`, nix store paths

## Development

```bash
# Enter devshell
nix develop

# Regenerate common.sh locally
cm-init

# Regenerate common.fish locally
fish-init -gp

# Test zsh config without installing
zsh -d -f -c "source ./zshrc"
```

## Adding a New Alias/Function

1. Add to **both** `common.sh.in` and `common.fish.in` (maintain parity)
2. Use `_dotzsh_cmd_exists <tool>` guard if it depends on an external tool
3. Use `_dotzsh_is_linux` / else blocks for platform-specific code
4. Place in the appropriate section (git, docker, tar, package management, etc.)

## Adding a New Zsh Plugin

1. Add plugin to `plugins/` directory
2. Source it in `zshrc` in the `plug_arr` array
