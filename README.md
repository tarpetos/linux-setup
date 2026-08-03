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
