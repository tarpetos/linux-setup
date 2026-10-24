# Linux Setup Script

This is an automated, idempotent monolith setup script for initializing a fresh or existing Ubuntu environment.

---

## Features
- **Sudo keep-alive**: prompts for `sudo` once at the beginning and keeps the session alive.
- **Dependencies**: Installs core utilities like `git`, `curl`, `wget`, `build-essential`, `fonts-powerline`, and `btop` (a modern resource monitor). Gracefully handles missing packages on older OS versions (like Ubuntu 20.04).
- **ZSH Setup**: installs ZSH and updates it if it is already present. Changes the default user shell to ZSH.
- **Oh My Zsh**: performs an unattended installation or upgrades an existing setup.
- **Plugins**: automatically clones or updates the `zsh-autosuggestions` and `zsh-syntax-highlighting` plugins.
- **Graceful configuration**: safely updates your existing `~/.zshrc` without overwriting custom PATHs or environmental configs to enable the `agnoster` theme and activate plugins. Automatically creates a backup of `~/.zshrc` before making changes.
- **Clean History**: Automatically disables Unix epoch timestamps in `~/.zsh_history` to keep the history file clean and human-readable.
- **UV & Python**: Installs or updates `uv`, the fast Python package installer and resolver. Also uses `uv` to automatically download and build complete, isolated distributions of **Python 3.13** and **Python 3.14** with all system dependencies natively installed.
- **Zed (optional)**: with `--zed`, sets up the [Zed](https://zed.dev) editor to look and behave like PyCharm. See [Zed setup](#zed-setup).
- **Summary Dashboard**: Displays a beautiful delta summary at the end of the script detailing what was installed, updated, failed, or already up-to-date.

---

## Usage
You can install and run the setup script with a single command without manually cloning the repository:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tarpetos/linux-setup/master/run.sh)"
```

Alternatively, if you have already cloned the repository locally:
```bash
chmod +x run.sh
./run.sh
```

### Options
| Option | Description |
| --- | --- |
| `--zed` | Run the base setup, then set up Zed |
| `--zed-only` | Set up only Zed, skip the base setup |
| `-h`, `--help` | Show usage |

Pass options after `_` when running through `curl`:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tarpetos/linux-setup/master/run.sh)" _ --zed
```

---

## Zed setup
The config lives in [`zed/`](zed):

- `settings.json`: Zed settings
  - JetBrains Islands Dark theme and JetBrains New UI icons (Zed installs the extensions on first start)
  - JetBrains Mono for code and terminal, Inter for the UI, sized and spaced to match PyCharm
  - JetBrains keymap, 120-column guide, folder arrows with icons, no compact folders
  - gitignored entries in orange; `.idea`, `.pytest_cache`, `.ruff_cache` and `__pycache__` hidden
  - terminal colours matching PyCharm's terminal for the `agnoster` prompt
  - on Windows, the terminal opens the default WSL distro
- `auto-venv.zsh`: activates a project's `.venv` when you `cd` into it and deactivates it when you leave
- `install-windows.ps1`: Windows side of the setup, used under WSL

What `--zed` does:

- **Everywhere**: installs `auto-venv.zsh` to `~/.config/zsh/` and sources it from `~/.zshrc`.
- **Linux**: installs JetBrains Mono 2.304 and Inter 4.1 to `~/.local/share/fonts` and writes `~/.config/zed/settings.json`.
- **WSL**: configures Zed on Windows through `install-windows.ps1`:
  - writes `%APPDATA%\Zed\settings.json`
  - installs the fonts for the current Windows user (no admin needed)
  - sets git `safe.directory` for `\\wsl.localhost\*`, so git does not refuse WSL repositories as "dubious ownership"
  - sets `core.fileMode=false` for Windows git through user environment variables, because Windows cannot see Linux exec bits and would show every script as modified

An existing `settings.json` is backed up to `settings.json.bak_<timestamp>` before it is replaced. Remote connections that Zed saved there (`ssh_connections`, `wsl_connections`) are kept.

On Windows, open WSL projects through **Open Remote → WSL** rather than `\\wsl.localhost` paths. Zed then runs git, file watching and the Python language server inside Linux, where they can use the project's `.venv`.
