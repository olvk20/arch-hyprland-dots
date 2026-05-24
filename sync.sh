#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$HOME/.config"
CONFIG_DST="$DOTFILES_DIR/config"
HOME_SRC="$HOME"
HOME_DST="$DOTFILES_DIR/home"

info()    { echo -e "\e[34m[info]\e[0m $*"; }
success() { echo -e "\e[32m[ok]\e[0m   $*"; }
warn()    { echo -e "\e[33m[warn]\e[0m $*"; }

# Files/patterns generated at runtime by matugen or other tools — never sync these
EXCLUDE=(
    --exclude="matugen_colors.json"
    --exclude="matugen_colors.lua"
    --exclude="kitty-matugen-colors.conf"
    --exclude="colors.conf"
    --exclude="colors"          # cava/colors
    --exclude="eww.css"         # compiled from eww-theme.scss by sassc
    --exclude="hyprland-gui.conf" # managed by HyprMod, not hand-edited
    --exclude=".claude"
    --exclude="*.bak"
)

sync_config() {
    local name="$1"
    local src="$CONFIG_SRC/$name"
    local dst="$CONFIG_DST/$name"

    if [[ ! -e "$src" ]]; then
        warn "skipping $name — not found in ~/.config/"
        return
    fi

    # If ~/.config/X is already a symlink into dotfiles, nothing to do
    if [[ -L "$src" ]] && [[ "$(readlink "$src")" == "$dst" ]]; then
        return
    fi

    cp -a "$src/." "$dst/"
    success "synced $name"
}

sync_home_file() {
    local name="$1"
    local src="$HOME_SRC/$name"
    local dst="$HOME_DST/$name"

    if [[ ! -f "$src" ]]; then
        warn "skipping $name — not found in ~/"
        return
    fi

    cp "$src" "$dst"
    success "synced ~/$name"
}

# ── Config directories tracked in dotfiles ─────────────────────────────────
CONFIGS=(
    btop
    cava
    eww
    fastfetch
    gtk-3.0
    gtk-4.0
    hypr
    kitty
    matugen
    networkmanager-dmenu
    nvim
    nwg-look
    qt5ct
    qt6ct
    rofi
    swaync
    swayosd
    waybar
    wlogout
    yay
)

# ── Single files in config root ─────────────────────────────────────────────
CONFIG_FILES=(
    mimeapps.list
    pavucontrol.ini
)

# ── Home dotfiles ───────────────────────────────────────────────────────────
HOME_FILES=(
    .zshrc
    .bashrc
    .bash_profile
    .profile
    .gtkrc-2.0
)

info "Syncing ~/.config/ → dotfiles/config/ ..."
for name in "${CONFIGS[@]}"; do
    sync_config "$name"
done

info "Syncing config root files..."
for name in "${CONFIG_FILES[@]}"; do
    src="$CONFIG_SRC/$name"
    dst="$CONFIG_DST/$name"
    [[ -f "$src" ]] && cp "$src" "$dst" && success "synced $name" || warn "skipping $name"
done

info "Syncing home dotfiles..."
for name in "${HOME_FILES[@]}"; do
    sync_home_file "$name"
done

success "All done. Review changes with: git -C '$DOTFILES_DIR' diff"
