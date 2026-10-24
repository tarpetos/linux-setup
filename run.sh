#!/usr/bin/env bash
set -e

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
NEEDS_RESTART=0
REPO_RAW_URL="https://raw.githubusercontent.com/tarpetos/linux-setup/master"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"

SETUP_BASE=1
SETUP_ZED=0
SETUP_MOUSE_FIX=0
SETUP_SLEEP_FIX=0

SUMMARY_INSTALLED=()
SUMMARY_FAILED=()
SUMMARY_UPDATED=()
SUMMARY_UP_TO_DATE=()

log_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

usage() {
    cat <<EOF
Usage: run.sh [options]

Options:
  --zed               Also set up Zed with the PyCharm-like config from zed/
  --mouse-scroll-fix  Also install a service that drops jumpy mouse wheel scrolls
  --sleep-fix         Also install a service that stops the PC waking up right after sleep
  --skip-base         Skip the base setup, run only the options above
  --zed-only          Same as --zed --skip-base
  -h, --help          Show this help
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --zed) SETUP_ZED=1 ;;
            --mouse-scroll-fix) SETUP_MOUSE_FIX=1 ;;
            --sleep-fix) SETUP_SLEEP_FIX=1 ;;
            --skip-base) SETUP_BASE=0 ;;
            --zed-only) SETUP_ZED=1; SETUP_BASE=0 ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
        shift
    done
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# Prints a local directory holding the given files from a repository directory.
# Running through curl leaves no repository on disk, so the files are downloaded.
repo_files() {
    local dir="$1"
    shift
    if [ -f "$SCRIPT_DIR/$dir/$1" ]; then
        echo "$SCRIPT_DIR/$dir"
        return
    fi
    local tmp file
    tmp="$(mktemp -d)"
    for file in "$@"; do
        curl -fsSL "$REPO_RAW_URL/$dir/$file" -o "$tmp/$file" || return 1
    done
    echo "$tmp"
}

# Installs a root-owned file; fails when the installed file is already identical
install_system_file() {
    local src="$1" dest="$2" mode="$3"
    if sudo cmp -s "$src" "$dest"; then
        return 1
    fi
    sudo install -m "$mode" "$src" "$dest"
}

prepare_sudo() {
    log_info "Requesting administrative privileges upfront..."
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

install_dependencies() {
    log_info "Updating package lists..."
    sudo apt-get update -y

    local deps=(git curl wget fonts-powerline build-essential btop libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncurses-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev)
    log_info "Installing dependencies: ${deps[*]}"
    
    for dep in "${deps[@]}"; do
        if ! dpkg -s "$dep" >/dev/null 2>&1; then
            log_info "Installing $dep..."
            if ! sudo apt-get install -y "$dep"; then
                log_error "Failed to install $dep. It might not be available in your OS repositories (e.g., btop on Ubuntu 20.04)."
                SUMMARY_FAILED+=("$dep")
            else
                SUMMARY_INSTALLED+=("$dep")
            fi
        else
            log_success "$dep is already installed."
            SUMMARY_UP_TO_DATE+=("$dep")
        fi
    done
}

install_uv() {
    log_info "Checking for uv..."
    if ! command_exists uv; then
        log_info "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        log_success "uv installed successfully."
        SUMMARY_INSTALLED+=("uv")
    else
        log_info "uv is already installed. Attempting update..."
        local uv_output
        uv_output=$(uv self update 2>&1 || true)
        if echo "$uv_output" | grep -q "already on version"; then
            SUMMARY_UP_TO_DATE+=("uv")
            log_info "uv is up to date."
        else
            SUMMARY_UPDATED+=("uv")
        fi
    fi
}

install_python_versions() {
    log_info "Installing full builds of Python 3.13 and 3.14 using uv..."
    export PATH="$HOME/.local/bin:$PATH"
    
    if command_exists uv; then
        local uv_out
        uv_out=$(uv python install 3.13 3.14 2>&1 || true)
        if echo "$uv_out" | grep -Eq "already installed|All requested versions already installed"; then
            log_success "Python 3.13 and 3.14 already installed."
            SUMMARY_UP_TO_DATE+=("Python 3.13 & 3.14")
        else
            log_success "Python 3.13 and 3.14 installed successfully."
            SUMMARY_INSTALLED+=("Python 3.13 & 3.14")
        fi
    else
        log_error "uv not found in PATH. Skipping Python installation."
        SUMMARY_FAILED+=("Python 3.13 & 3.14")
    fi
}

install_zsh() {
    log_info "Checking for ZSH..."
    if ! command_exists zsh; then
        log_info "Installing ZSH..."
        sudo apt-get install -y zsh
        SUMMARY_INSTALLED+=("ZSH")
    else
        log_info "ZSH is already installed. Attempting upgrade..."
        sudo apt-get install --only-upgrade -y zsh
        SUMMARY_UP_TO_DATE+=("ZSH")
    fi
    
    local user_shell
    user_shell=$(basename "$SHELL")
    if [ "$user_shell" != "zsh" ]; then
        log_info "Changing default shell to ZSH for $USER..."
        sudo chsh -s "$(which zsh)" "$USER"
        SUMMARY_UPDATED+=("Default Shell -> ZSH")
        NEEDS_RESTART=1
    else
        log_success "ZSH is already the default shell."
    fi
}

install_oh_my_zsh() {
    log_info "Checking for Oh My Zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log_success "Oh My Zsh installed."
        SUMMARY_INSTALLED+=("Oh My Zsh")
        NEEDS_RESTART=1
    else
        log_info "Oh My Zsh already installed. Attempting upgrade..."
        local omz_out
        omz_out=$(env ZSH="$HOME/.oh-my-zsh" bash "$HOME/.oh-my-zsh/tools/upgrade.sh" 2>&1 || true)
        if echo "$omz_out" | grep -q "already at the latest version"; then
            SUMMARY_UP_TO_DATE+=("Oh My Zsh")
        else
            SUMMARY_UPDATED+=("Oh My Zsh")
        fi
    fi
}

install_zsh_plugins() {
    log_info "Installing ZSH plugins..."
    
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        SUMMARY_INSTALLED+=("zsh-autosuggestions")
        NEEDS_RESTART=1
    else
        log_info "Updating zsh-autosuggestions..."
        local git_out
        git_out=$(git -C "$ZSH_CUSTOM/plugins/zsh-autosuggestions" pull 2>&1)
        if echo "$git_out" | grep -q "Already up to date"; then
            SUMMARY_UP_TO_DATE+=("zsh-autosuggestions")
        else
            SUMMARY_UPDATED+=("zsh-autosuggestions")
        fi
    fi
    
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        SUMMARY_INSTALLED+=("zsh-syntax-highlighting")
        NEEDS_RESTART=1
    else
        log_info "Updating zsh-syntax-highlighting..."
        local git_out
        git_out=$(git -C "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" pull 2>&1)
        if echo "$git_out" | grep -q "Already up to date"; then
            SUMMARY_UP_TO_DATE+=("zsh-syntax-highlighting")
        else
            SUMMARY_UPDATED+=("zsh-syntax-highlighting")
        fi
    fi
}

configure_zshrc() {
    log_info "Configuring .zshrc..."
    if [ -f "$HOME/.zshrc" ]; then
        log_info "Backing up existing .zshrc to .zshrc.bak_$(date +%s)..."
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak_$(date +%s)"
    else
        if [ -f "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" ]; then
            cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
        else
            touch "$HOME/.zshrc"
        fi
    fi
    
    local changed=0
    
    if ! grep -q '^ZSH_THEME="agnoster"' "$HOME/.zshrc"; then
        if grep -q '^ZSH_THEME=' "$HOME/.zshrc"; then
            sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
        else
            echo 'ZSH_THEME="agnoster"' >> "$HOME/.zshrc"
        fi
        changed=1
    fi
    
    if ! grep -q '^HIST_STAMPS="yyyy-mm-dd"' "$HOME/.zshrc"; then
        if grep -q 'HIST_STAMPS=' "$HOME/.zshrc"; then
            sed -i 's/^#* *HIST_STAMPS=.*/HIST_STAMPS="yyyy-mm-dd"/' "$HOME/.zshrc"
        else
            echo 'HIST_STAMPS="yyyy-mm-dd"' >> "$HOME/.zshrc"
        fi
        changed=1
    fi
    
    if ! grep -q '^plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' "$HOME/.zshrc"; then
        if grep -q '^plugins=' "$HOME/.zshrc"; then
            sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
        else
            echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> "$HOME/.zshrc"
        fi
        changed=1
    fi
    
    if ! grep -q '^unsetopt EXTENDED_HISTORY' "$HOME/.zshrc"; then
        echo 'unsetopt EXTENDED_HISTORY' >> "$HOME/.zshrc"
        changed=1
    fi
    
    if [ "$changed" -eq 1 ]; then
        SUMMARY_UPDATED+=(".zshrc configuration")
        NEEDS_RESTART=1
    else
        SUMMARY_UP_TO_DATE+=(".zshrc configuration")
    fi
    
    log_success ".zshrc configured."
}

fetch_zed_config() {
    ZED_SRC="$(repo_files zed settings.json auto-venv.zsh install-windows.ps1)"
}

install_venv_hook() {
    log_info "Installing .venv auto-activation hook..."
    local dest="$HOME/.config/zsh/auto-venv.zsh"
    local line='source "$HOME/.config/zsh/auto-venv.zsh"'
    local changed=0

    mkdir -p "$(dirname "$dest")"
    if ! cmp -s "$ZED_SRC/auto-venv.zsh" "$dest"; then
        cp "$ZED_SRC/auto-venv.zsh" "$dest"
        changed=1
    fi
    if ! grep -qF "$line" "$HOME/.zshrc" 2>/dev/null; then
        printf '\n%s\n' "$line" >> "$HOME/.zshrc"
        changed=1
    fi

    if [ "$changed" -eq 1 ]; then
        SUMMARY_UPDATED+=(".venv auto-activation hook")
        NEEDS_RESTART=1
    else
        SUMMARY_UP_TO_DATE+=(".venv auto-activation hook")
    fi
}

install_zed_fonts() {
    log_info "Checking for JetBrains Mono and Inter fonts..."
    if fc-list : family | grep -q "^JetBrains Mono" && fc-list : family | grep -q "^Inter"; then
        log_success "Fonts are already installed."
        SUMMARY_UP_TO_DATE+=("JetBrains Mono & Inter fonts")
        return
    fi

    if ! command_exists unzip; then
        sudo apt-get install -y unzip
    fi
    local tmp font_dir="$HOME/.local/share/fonts"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/jbm.zip" https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip
    curl -fsSL -o "$tmp/inter.zip" https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
    unzip -qo "$tmp/jbm.zip" -d "$tmp/jbm"
    unzip -qo "$tmp/inter.zip" -d "$tmp/inter"
    mkdir -p "$font_dir"
    cp "$tmp"/jbm/fonts/ttf/JetBrainsMono-*.ttf "$tmp"/inter/extras/ttf/Inter-*.ttf "$font_dir/"
    rm -rf "$tmp"
    fc-cache -f "$font_dir" >/dev/null
    log_success "Fonts installed to $font_dir."
    SUMMARY_INSTALLED+=("JetBrains Mono & Inter fonts")
}

install_zed_settings() {
    log_info "Configuring Zed settings..."
    local dir="$HOME/.config/zed" merged
    merged="$(mktemp)"
    # Keep the remote connections Zed saves into settings.json
    {
        sed -n '1,/^{$/p' "$ZED_SRC/settings.json"
        if [ -f "$dir/settings.json" ]; then
            awk '/^  "(ssh|wsl)_connections": \[/ { keep = 1 }
                 keep { if ($0 == "  ]") $0 = "  ],"; print }
                 keep && /^  \],?$/ { keep = 0 }' "$dir/settings.json"
        fi
        sed '1,/^{$/d' "$ZED_SRC/settings.json"
    } > "$merged"

    if cmp -s "$merged" "$dir/settings.json"; then
        rm -f "$merged"
        log_success "Zed settings are already up to date."
        SUMMARY_UP_TO_DATE+=("Zed settings")
        return
    fi

    mkdir -p "$dir"
    if [ -f "$dir/settings.json" ]; then
        log_info "Backing up existing Zed settings to settings.json.bak_$(date +%s)..."
        cp "$dir/settings.json" "$dir/settings.json.bak_$(date +%s)"
    fi
    mv "$merged" "$dir/settings.json"
    log_success "Zed settings configured."
    SUMMARY_UPDATED+=("Zed settings")
}

setup_zed() {
    fetch_zed_config
    install_venv_hook

    if is_wsl; then
        # Zed runs on Windows and opens projects in WSL, so configure the Windows side
        log_info "WSL detected. Configuring Zed on Windows..."
        if powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$ZED_SRC/install-windows.ps1")"; then
            SUMMARY_UPDATED+=("Zed on Windows (settings, fonts, git for WSL)")
        else
            log_error "Configuring Zed on Windows failed."
            SUMMARY_FAILED+=("Zed on Windows")
        fi
    else
        install_zed_fonts
        install_zed_settings
    fi
}

# Installs a script to /usr/local/bin with its systemd service, then enables the service
install_service_fix() {
    local name="$1" dir="$2" script="$3" service="$4"
    log_info "Setting up the $name..."
    if is_wsl; then
        log_info "Skipping the $name: it fixes hardware, which WSL does not manage."
        return
    fi

    local src changed=0 existed=0
    src="$(repo_files "$dir" "$script" "$service")"
    [ -f "/etc/systemd/system/$service" ] && existed=1
    install_system_file "$src/$script" "/usr/local/bin/$script" 755 && changed=1
    install_system_file "$src/$service" "/etc/systemd/system/$service" 644 && changed=1

    if [ "$changed" -eq 0 ]; then
        sudo systemctl enable "$service"
        log_success "The $name is already up to date."
        SUMMARY_UP_TO_DATE+=("${name^}")
        return
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable "$service"
    sudo systemctl restart "$service"
    log_success "The $name is installed. Check it with: systemctl status $service"
    if [ "$existed" -eq 1 ]; then
        SUMMARY_UPDATED+=("${name^}")
    else
        SUMMARY_INSTALLED+=("${name^}")
    fi
}

install_mouse_scroll_fix() {
    if ! is_wsl && ! dpkg -s python3-evdev >/dev/null 2>&1; then
        log_info "Installing python3-evdev..."
        sudo apt-get install -y python3-evdev || { sudo apt-get update -y && sudo apt-get install -y python3-evdev; }
    fi
    install_service_fix "mouse scroll wheel fix" mouse-scroll-fix mouse-scroll-fix.py mouse-scroll-fix.service
}

install_sleep_fix() {
    install_service_fix "sleep fix" sleep-fix disable-wake.sh disable-acpi-wake.service
}

print_summary() {
    echo ""
    echo -e "\e[1m==================================================\e[0m"
    echo -e "\e[1m                 SETUP SUMMARY                    \e[0m"
    echo -e "\e[1m==================================================\e[0m"
    
    if [ ${#SUMMARY_INSTALLED[@]} -gt 0 ]; then
        echo -e "\e[32m[INSTALLED]\e[0m"
        for item in "${SUMMARY_INSTALLED[@]}"; do echo "  - $item"; done
        echo ""
    fi
    
    if [ ${#SUMMARY_UPDATED[@]} -gt 0 ]; then
        echo -e "\e[34m[UPDATED]\e[0m"
        for item in "${SUMMARY_UPDATED[@]}"; do echo "  - $item"; done
        echo ""
    fi
    
    if [ ${#SUMMARY_UP_TO_DATE[@]} -gt 0 ]; then
        echo -e "\e[32m[UP TO DATE]\e[0m"
        for item in "${SUMMARY_UP_TO_DATE[@]}"; do echo "  - $item"; done
        echo ""
    fi
    
    if [ ${#SUMMARY_FAILED[@]} -gt 0 ]; then
        echo -e "\e[31m[FAILED]\e[0m"
        for item in "${SUMMARY_FAILED[@]}"; do echo "  - $item"; done
        echo ""
    fi
    echo -e "\e[1m==================================================\e[0m"
    echo ""
}

main() {
    parse_args "$@"

    if [ "$SETUP_BASE" -eq 1 ] || [ "$SETUP_MOUSE_FIX" -eq 1 ] || [ "$SETUP_SLEEP_FIX" -eq 1 ]; then
        prepare_sudo
    fi

    if [ "$SETUP_BASE" -eq 1 ]; then
        install_dependencies
        install_zsh
        install_oh_my_zsh
        install_zsh_plugins
        configure_zshrc
        install_uv
        install_python_versions
    fi

    if [ "$SETUP_ZED" -eq 1 ]; then
        setup_zed
    fi

    if [ "$SETUP_MOUSE_FIX" -eq 1 ]; then
        install_mouse_scroll_fix
    fi

    if [ "$SETUP_SLEEP_FIX" -eq 1 ]; then
        install_sleep_fix
    fi

    print_summary
    
    if [ "$NEEDS_RESTART" -eq 1 ]; then
        log_success "Setup complete! Restarting your terminal into ZSH..."
        exec zsh -l
    else
        log_success "Everything is already installed and up to date! No restart required."
    fi
}

main "$@"
