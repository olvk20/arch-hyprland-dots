#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DOTFILES_DIR/config"
HOME_SRC="$DOTFILES_DIR/home"

GPU_PACKAGES=()
GPU_NAME="none"
KB_LAYOUT="us"
KB_OPTIONS=""
KB_LABEL="US"
TIMEZONE="UTC"
WB_BACKEND="iwd"
WB_LABEL="iwd"
EXTRA_PACKAGES=()

# Review tracking — all must be "true" before Install is allowed
REVIEWED_PACKAGES="false"
REVIEWED_DRIVERS="false"
REVIEWED_KEYBOARD="false"
REVIEWED_TIMEZONE="false"
REVIEWED_WIFI="false"

# ── Colors ─────────────────────────────────────────────────────────────────
G='\e[32m'; Y='\e[33m'; B='\e[34m'; C='\e[36m'; RED='\e[31m'
BOLD='\e[1m'; DIM='\e[2m'; R='\e[0m'

info()    { echo -e "  ${B}[info]${R}  $*"; }
success() { echo -e "  ${G}[ ok ]${R}  $*"; }
warn()    { echo -e "  ${Y}[warn]${R}  $*"; }
error()   { echo -e "  ${RED}[ err]${R}  $*" >&2; }

symlink() {
    local src="$1" dst="$2"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Backing up existing $dst → ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    success "linked $dst"
}

# ── OS check ───────────────────────────────────────────────────────────────
check_os() {
    if [[ ! -f /etc/arch-release ]]; then
        error "Unsupported OS — this script only runs on Arch Linux."
        exit 1
    fi
}

# ── Header ─────────────────────────────────────────────────────────────────
print_header() {
    echo -e ""
    echo -e "  ${BOLD}╔══════════════════════════════════════════════════════════════╗${R}"
    echo -e "  ${BOLD}║                   olvk20's dots - Installer                  ║${R}"
    echo -e "  ${BOLD}╚══════════════════════════════════════════════════════════════╝${R}"
    echo -e ""
    echo -e "  ${G}✓${R}  Arch Linux detected — proceeding to installation"
    echo -e ""
    echo -e "  ${DIM}contact@olvk.pl  ·  Discord: 0x4f6c656b${R}"
    echo -e ""
}

# ── Helpers ────────────────────────────────────────────────────────────────
review_marker() {
    if [[ "$1" == "true" ]]; then
        echo -e "${G}[✓]${R}"
    else
        echo -e "${RED}[✗]${R}"
    fi
}

all_reviewed() {
    local ok=true
    [[ "$REVIEWED_PACKAGES" == "true" ]] || ok=false
    [[ "$REVIEWED_DRIVERS"  == "true" ]] || ok=false
    [[ "$REVIEWED_KEYBOARD" == "true" ]] || ok=false
    [[ "$REVIEWED_TIMEZONE" == "true" ]] || ok=false
    [[ "$REVIEWED_WIFI"     == "true" ]] || ok=false
    echo "$ok"
}

# ── Package viewer ─────────────────────────────────────────────────────────
screen_packages() {
    clear
    print_header
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    echo -e "  ${BOLD}Base packages (pacman)${R}"
    echo -e ""
    grep -v '^\s*#' "$DOTFILES_DIR/packages/pacman.txt" | grep -v '^\s*$' | \
        grep -v -E '^(vulkan-radeon|xf86-video-amdgpu|libva-mesa-driver)$' | \
        column | sed 's/^/    /'
    echo -e ""
    echo -e "  ${BOLD}AUR packages${R}"
    echo -e ""
    grep -v '^\s*#' "$DOTFILES_DIR/packages/aur.txt" | grep -v '^\s*$' | \
        column | sed 's/^/    /'
    echo -e ""
    if [[ ${#GPU_PACKAGES[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}GPU drivers  ${C}${GPU_NAME}${R}"
        echo -e ""
        printf '    %s\n' "${GPU_PACKAGES[@]}"
    else
        echo -e "  ${DIM}GPU drivers: none selected${R}"
    fi
    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    read -rp "  Press Enter to go back..." _
    REVIEWED_PACKAGES="true"
}

# ── Driver selection ───────────────────────────────────────────────────────
screen_drivers() {
    clear
    print_header
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    echo -e "  ${BOLD}GPU Driver Selection${R}"
    echo -e ""
    echo -e "   ${BOLD}1${R}  AMD    — vulkan-radeon, xf86-video-amdgpu, libva-mesa-driver"
    echo -e "   ${BOLD}2${R}  NVIDIA — nvidia-dkms, nvidia-utils, egl-wayland"
    echo -e "              (also configures Wayland env vars and initramfs)"
    echo -e "   ${BOLD}3${R}  Intel  — vulkan-intel, intel-media-driver, libva-intel-driver"
    echo -e "   ${BOLD}4${R}  Skip   — no GPU drivers"
    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    read -rp "  Choice [1-4]: " gpu_choice

    case "$gpu_choice" in
        1) GPU_PACKAGES=(vulkan-radeon xf86-video-amdgpu libva-mesa-driver mesa); GPU_NAME="AMD" ;;
        2) GPU_PACKAGES=(nvidia-dkms nvidia-utils egl-wayland);                   GPU_NAME="NVIDIA" ;;
        3) GPU_PACKAGES=(vulkan-intel intel-media-driver libva-intel-driver mesa); GPU_NAME="Intel" ;;
        *) GPU_PACKAGES=(); GPU_NAME="none" ;;
    esac
    REVIEWED_DRIVERS="true"
}

# ── Keyboard selection ─────────────────────────────────────────────────────
screen_keyboard() {
    clear
    print_header
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    echo -e "  ${BOLD}Keyboard Layout${R}"
    echo -e ""
    echo -e "   ${BOLD}1${R}  US              English (United States)"
    echo -e "   ${BOLD}2${R}  PL              Polish"
    echo -e "   ${BOLD}3${R}  US + PL         Toggle with Alt+Shift"
    echo -e "   ${BOLD}4${R}  DE              German"
    echo -e "   ${BOLD}5${R}  FR              French"
    echo -e "   ${BOLD}6${R}  GB              English (United Kingdom)"
    echo -e "   ${BOLD}7${R}  Custom          Enter layout code manually"
    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    read -rp "  Choice [1-7]: " kb_choice

    case "$kb_choice" in
        1) KB_LAYOUT="us";    KB_OPTIONS="";                     KB_LABEL="US" ;;
        2) KB_LAYOUT="pl";    KB_OPTIONS="";                     KB_LABEL="PL" ;;
        3) KB_LAYOUT="us,pl"; KB_OPTIONS="grp:alt_shift_toggle"; KB_LABEL="US + PL" ;;
        4) KB_LAYOUT="de";    KB_OPTIONS="";                     KB_LABEL="DE" ;;
        5) KB_LAYOUT="fr";    KB_OPTIONS="";                     KB_LABEL="FR" ;;
        6) KB_LAYOUT="gb";    KB_OPTIONS="";                     KB_LABEL="GB" ;;
        7)
            echo ""
            read -rp "  Layout code (e.g. 'es', 'ru', 'us,ru'): " custom_layout
            KB_LAYOUT="${custom_layout:-us}"
            KB_OPTIONS=""
            KB_LABEL="$KB_LAYOUT"
            ;;
        *) KB_LAYOUT="us"; KB_OPTIONS=""; KB_LABEL="US" ;;
    esac
    REVIEWED_KEYBOARD="true"
}

# ── Timezone selection ─────────────────────────────────────────────────────
screen_timezone() {
    clear
    print_header
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    echo -e "  ${BOLD}Timezone${R}"
    echo -e ""
    echo -e "   ${BOLD}1${R}  Europe/Warsaw"
    echo -e "   ${BOLD}2${R}  Europe/London"
    echo -e "   ${BOLD}3${R}  Europe/Berlin"
    echo -e "   ${BOLD}4${R}  Europe/Paris"
    echo -e "   ${BOLD}5${R}  America/New_York"
    echo -e "   ${BOLD}6${R}  America/Chicago"
    echo -e "   ${BOLD}7${R}  America/Los_Angeles"
    echo -e "   ${BOLD}8${R}  UTC"
    echo -e "   ${BOLD}9${R}  Custom   — enter timezone manually"
    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    read -rp "  Choice [1-9]: " tz_choice

    case "$tz_choice" in
        1) TIMEZONE="Europe/Warsaw" ;;
        2) TIMEZONE="Europe/London" ;;
        3) TIMEZONE="Europe/Berlin" ;;
        4) TIMEZONE="Europe/Paris" ;;
        5) TIMEZONE="America/New_York" ;;
        6) TIMEZONE="America/Chicago" ;;
        7) TIMEZONE="America/Los_Angeles" ;;
        8) TIMEZONE="UTC" ;;
        9)
            echo ""
            read -rp "  Timezone (e.g. 'Asia/Tokyo'): " custom_tz
            TIMEZONE="${custom_tz:-UTC}"
            ;;
        *) TIMEZONE="UTC" ;;
    esac
    REVIEWED_TIMEZONE="true"
}

# ── WiFi backend selection ─────────────────────────────────────────────────
screen_wifi() {
    clear
    print_header
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    echo -e "  ${BOLD}WiFi Backend (NetworkManager)${R}"
    echo -e ""
    echo -e "   ${BOLD}1${R}  iwd             Modern backend, reliable autoconnect  ${G}(recommended)${R}"
    echo -e "   ${BOLD}2${R}  wpa_supplicant  ${RED}Legacy — causes autoconnect issues${R}"
    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    read -rp "  Choice [1-2]: " wb_choice

    case "$wb_choice" in
        2) WB_BACKEND="wpa_supplicant"; WB_LABEL="wpa_supplicant" ;;
        *) WB_BACKEND="iwd";            WB_LABEL="iwd" ;;
    esac
    REVIEWED_WIFI="true"
}

# ── Extra packages ─────────────────────────────────────────────────────────
screen_extra_packages() {
    clear
    print_header
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    echo -e "  ${BOLD}Additional Packages${R}   ${DIM}optional — installed after the base setup${R}"
    echo -e ""
    echo -e "  ${DIM}Suggestions (pacman):${R}"
    echo -e "   firefox  chromium  vlc  gimp  obs-studio  steam  libreoffice-fresh"
    echo -e "   telegram-desktop  transmission-gtk  mpv  kdenlive"
    echo -e ""
    echo -e "  ${DIM}Suggestions (AUR — also work here):${R}"
    echo -e "   mullvad-vpn  spotify  discord  visual-studio-code-bin  zen-browser-bin"
    echo -e ""
    echo -e "  ${RED}${BOLD}┌──────────────────────────────────────────────────────────────┐${R}"
    echo -e "  ${RED}${BOLD}│  ⚠  CAUTION — READ BEFORE TYPING                            │${R}"
    echo -e "  ${RED}${BOLD}│                                                              │${R}"
    echo -e "  ${RED}${BOLD}│  If you misspell a package name or enter one that does       │${R}"
    echo -e "  ${RED}${BOLD}│  not exist, it WILL crash the script mid-installation.       │${R}"
    echo -e "  ${RED}${BOLD}│  If this happens during a critical step it could leave       │${R}"
    echo -e "  ${RED}${BOLD}│  your system broken and potentially require a full Arch      │${R}"
    echo -e "  ${RED}${BOLD}│  Linux reinstall to use this script again.                  │${R}"
    echo -e "  ${RED}${BOLD}│                                                              │${R}"
    echo -e "  ${RED}${BOLD}│  Verify every package name on wiki.archlinux.org first.     │${R}"
    echo -e "  ${RED}${BOLD}└──────────────────────────────────────────────────────────────┘${R}"
    echo -e ""
    if [[ ${#EXTRA_PACKAGES[@]} -gt 0 ]]; then
        echo -e "  ${G}Currently selected:${R}  ${EXTRA_PACKAGES[*]}"
        echo -e ""
    fi
    echo -e "  Enter packages separated by spaces, or press Enter to skip / clear selection."
    echo -e ""
    read -rp "  > " extra_input

    if [[ -z "$extra_input" ]]; then
        EXTRA_PACKAGES=()
        echo ""
        echo -e "  ${DIM}No additional packages selected.${R}"
    else
        read -ra EXTRA_PACKAGES <<< "$extra_input"
        echo ""
        echo -e "  ${G}Queued:${R}  ${EXTRA_PACKAGES[*]}"
    fi
    echo ""
    read -rp "  Press Enter to go back..." _
}

# ── Keybinds viewer (read-only) ────────────────────────────────────────────
screen_keybinds() {
    clear
    print_header
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e "  ${BOLD}Keybindings${R}   ${DIM}Super = Windows key   ·   read-only${R}"
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    echo -e "  ${BOLD}${C}── Windows${R}"
    echo -e "   ${BOLD}Super + C${R}                  Close window"
    echo -e "   ${BOLD}Super + Shift + F${R}           Toggle floating"
    echo -e "   ${BOLD}Super + L${R}                  Lock screen"
    echo -e "   ${BOLD}Super + Shift + M${R}           Hyprland GUI settings"
    echo -e ""
    echo -e "  ${BOLD}${C}── Focus & Movement${R}"
    echo -e "   ${BOLD}Super + Arrows${R}              Move focus"
    echo -e "   ${BOLD}Super + Ctrl + Arrows${R}       Move window"
    echo -e "   ${BOLD}Super + Shift + Arrows${R}      Resize window"
    echo -e "   ${BOLD}Super + Tab${R}                 Switch monitor"
    echo -e ""
    echo -e "  ${BOLD}${C}── Workspaces${R}"
    echo -e "   ${BOLD}Super + 1–9${R}                Switch to workspace"
    echo -e "   ${BOLD}Super + Shift + 1–9${R}        Move window to workspace"
    echo -e ""
    echo -e "  ${BOLD}${C}── Apps${R}"
    echo -e "   ${BOLD}Super + Q${R}                  Terminal (kitty)"
    echo -e "   ${BOLD}Super + E${R}                  Files (Nautilus)"
    echo -e "   ${BOLD}Super + Space${R}               App launcher (rofi)"
    echo -e "   ${BOLD}Super + Shift + C${R}           Clipboard history"
    echo -e "   ${BOLD}Super + R${R}                  Reload config"
    echo -e "   ${DIM}Super + F                  Browser (Firefox — install separately)${R}"
    echo -e ""
    echo -e "  ${BOLD}${C}── Panels & Menus${R}"
    echo -e "   ${BOLD}Super + W${R}                  Wallpaper picker"
    echo -e "   ${BOLD}Super + A${R}                  Music menu"
    echo -e "   ${BOLD}Super + V${R}                  Volume menu"
    echo -e "   ${BOLD}Super + N${R}                  WiFi menu"
    echo -e "   ${BOLD}Super + B${R}                  Power menu"
    echo -e "   ${BOLD}Super + Shift + N${R}           Notifications"
    echo -e "   ${BOLD}Super + Escape${R}              Close all menus"
    echo -e ""
    echo -e "  ${BOLD}${C}── Screenshots${R}"
    echo -e "   ${BOLD}Print${R}                      Capture region"
    echo -e "   ${BOLD}Super + Shift + S${R}           Capture region + annotate"
    echo -e "   ${BOLD}Super + Shift + P${R}           Full screenshot"
    echo -e "   ${BOLD}Super + Shift + Print${R}       Full screenshot + annotate"
    echo -e ""
    echo -e "  ${BOLD}${C}── Media${R}"
    echo -e "   ${BOLD}Super + Shift + Space${R}       Play / Pause"
    echo -e "   ${BOLD}XF86AudioPlay/Pause${R}         Play / Pause (media key)"
    echo -e "   ${BOLD}XF86 Volume keys${R}            Volume control"
    echo -e "   ${BOLD}XF86 Brightness keys${R}        Screen brightness"
    echo -e "   ${BOLD}XF86AudioMicMute${R}            Mute microphone"
    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    read -rp "  Press Enter to go back..." _
}

# ── Install confirmation ───────────────────────────────────────────────────
screen_install() {
    clear
    print_header
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    echo -e "  ${BOLD}Ready to install${R}"
    echo -e ""
    if [[ "$GPU_NAME" == "none" ]]; then
        echo -e "   GPU drivers   ${DIM}none${R}"
    else
        echo -e "   GPU drivers   ${C}${GPU_NAME}${R}"
    fi
    echo -e "   Keyboard      ${C}${KB_LABEL}${R}  ${DIM}(${KB_LAYOUT})${R}"
    echo -e "   Timezone      ${C}${TIMEZONE}${R}"
    echo -e "   WiFi backend  ${C}${WB_LABEL}${R}"
    if [[ ${#EXTRA_PACKAGES[@]} -gt 0 ]]; then
        echo -e "   Extra pkgs    ${C}${EXTRA_PACKAGES[*]}${R}"
    else
        echo -e "   Extra pkgs    ${DIM}none${R}"
    fi
    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    echo -e ""
    read -rp "  Are you sure? [y/N]: " confirm
    confirm="${confirm:-n}"
    if [[ "${confirm,,}" != "y" ]]; then
        return
    fi

    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    info "Starting installation..."
    echo -e ""

    install_packages
    link_configs
    link_home
    copy_wallpapers
    generate_colors
    setup_zsh
    apply_keyboard
    apply_timezone
    setup_locale
    setup_xdg_dirs
    setup_nvidia
    setup_sddm_wayland
    apply_wifi_backend
    enable_services
    install_extra_packages

    echo -e ""
    echo -e "  ────────────────────────────────────────────────────────────────"
    success "All done! Reboot to start into Hyprland."
    if [[ "$GPU_NAME" == "NVIDIA" ]]; then
        info "NVIDIA: verify 'nvidia-drm.modeset=1' is in your bootloader kernel params."
    fi
    echo -e ""
    read -rp "  Press Enter to exit..." _
    exit 0
}

# ── Main menu ──────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        clear
        print_header
        echo -e "  ────────────────────────────────────────────────────────────────"
        echo -e ""

        local m_pkg m_drv m_kb m_tz m_wifi
        m_pkg="$(review_marker "$REVIEWED_PACKAGES")"
        m_drv="$(review_marker "$REVIEWED_DRIVERS")"
        m_kb="$(review_marker "$REVIEWED_KEYBOARD")"
        m_tz="$(review_marker "$REVIEWED_TIMEZONE")"
        m_wifi="$(review_marker "$REVIEWED_WIFI")"

        local gpu_label
        if [[ "$GPU_NAME" == "none" ]]; then
            gpu_label="${DIM}none${R}"
        else
            gpu_label="${C}${GPU_NAME}${R}"
        fi

        echo -e "   ${m_pkg}  ${BOLD}1${R}  View packages"
        echo -e "   ${m_drv}  ${BOLD}2${R}  Select drivers              [ ${gpu_label} ]"
        echo -e "   ${m_kb}  ${BOLD}3${R}  Select keyboard             [ ${C}${KB_LABEL}${R} ]"
        echo -e "   ${m_tz}  ${BOLD}4${R}  Select timezone             [ ${C}${TIMEZONE}${R} ]"
        echo -e "   ${m_wifi}  ${BOLD}5${R}  Select WiFi backend         [ ${C}${WB_LABEL}${R} ]"

        local extra_label
        if [[ ${#EXTRA_PACKAGES[@]} -gt 0 ]]; then
            extra_label="${C}${#EXTRA_PACKAGES[@]} selected${R}"
        else
            extra_label="${DIM}none${R}"
        fi
        echo -e "        ${BOLD}6${R}  Additional packages         [ ${extra_label} ]"
        echo -e "        ${BOLD}7${R}  ${DIM}View keybinds${R}"
        echo -e ""

        local ready
        ready="$(all_reviewed)"
        if [[ "$ready" == "true" ]]; then
            echo -e "        ${BOLD}8  Install${R}"
        else
            echo -e "        ${DIM}8  Install  ${RED}— review all items first${R}"
        fi

        echo -e ""
        echo -e "        ${DIM}9  Exit${R}"
        echo -e ""
        echo -e "  ────────────────────────────────────────────────────────────────"
        echo -e ""
        read -rp "  Choice: " choice

        case "$choice" in
            1) screen_packages ;;
            2) screen_drivers ;;
            3) screen_keyboard ;;
            4) screen_timezone ;;
            5) screen_wifi ;;
            6) screen_extra_packages ;;
            7) screen_keybinds ;;
            8)
                if [[ "$ready" == "true" ]]; then
                    screen_install
                else
                    echo ""
                    warn "Review all items marked ${RED}[✗]${R}${Y} before installing."
                    read -rp "  Press Enter to continue..." _
                fi
                ;;
            9|q|Q) echo ""; exit 0 ;;
            *) ;;
        esac
    done
}

# ── Install steps ──────────────────────────────────────────────────────────
install_yay() {
    if command -v yay &>/dev/null; then return; fi
    info "Installing yay..."
    local tmp
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    success "yay installed"
}

install_packages() {
    local base_pkgs
    base_pkgs=$(grep -v '^\s*#' "$DOTFILES_DIR/packages/pacman.txt" | grep -v '^\s*$' | \
        grep -v -E '^(vulkan-radeon|xf86-video-amdgpu|libva-mesa-driver)$')

    info "Installing base pacman packages..."
    echo "$base_pkgs" | sudo pacman -S --needed --noconfirm -

    if [[ ${#GPU_PACKAGES[@]} -gt 0 ]]; then
        info "Installing $GPU_NAME drivers: ${GPU_PACKAGES[*]}"
        sudo pacman -S --needed --noconfirm "${GPU_PACKAGES[@]}"
    fi

    install_yay

    info "Installing AUR packages..."
    grep -v '^\s*#' "$DOTFILES_DIR/packages/aur.txt" | grep -v '^\s*$' | \
        yay -S --needed --noconfirm -

    info "Refreshing font cache..."
    fc-cache -fv &>/dev/null
    success "Font cache updated"
}

link_configs() {
    info "Linking config directories..."
    mkdir -p "$HOME/.config"
    for item in "$CONFIG_SRC"/*/; do
        name="$(basename "$item")"
        symlink "$item" "$HOME/.config/$name"
    done
    for item in "$CONFIG_SRC"/*; do
        [ -d "$item" ] && continue
        name="$(basename "$item")"
        symlink "$item" "$HOME/.config/$name"
    done
}

link_home() {
    info "Linking home dotfiles..."
    for f in "$HOME_SRC"/.*; do
        [ "$(basename "$f")" = "." ] && continue
        [ "$(basename "$f")" = ".." ] && continue
        symlink "$f" "$HOME/$(basename "$f")"
    done
}

copy_wallpapers() {
    info "Copying wallpapers..."
    mkdir -p "$HOME/Pictures/Wallpapers"
    cp -n "$DOTFILES_DIR/wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true

    local cache_file="$HOME/.cache/current_wallpaper"
    if [[ ! -f "$cache_file" ]]; then
        local first_wall
        first_wall=$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
            | sort | head -1)
        if [[ -n "$first_wall" ]]; then
            mkdir -p "$HOME/.cache"
            echo "$first_wall" > "$cache_file"
            success "Initial wallpaper set: $(basename "$first_wall")"
        else
            warn "No wallpapers found in dotfiles/wallpapers/ — wallpaper cache not written"
        fi
    fi

    success "Wallpapers ready in ~/Pictures/Wallpapers"
}

# Pre-generate matugen color scheme so waybar/eww/rofi/hyprland have correct
# styles on first boot without waiting for init.sh to run on first login.
generate_colors() {
    local cache_file="$HOME/.cache/current_wallpaper"
    if [[ ! -f "$cache_file" ]]; then
        warn "No wallpaper cache — skipping color generation"
        return
    fi
    local wallpaper
    wallpaper=$(cat "$cache_file")
    if [[ ! -f "$wallpaper" ]]; then
        warn "Cached wallpaper not found — skipping color generation"
        return
    fi

    info "Generating initial color scheme from wallpaper..."
    # matugen writes: colors.conf, waybar/style.css, eww-theme.scss, rofi themes,
    # swaync/style.css, qt5ct/qt6ct colors, hyprlock.conf, etc.
    if ! matugen image "$wallpaper" --source-color-index 0 2>/dev/null; then
        warn "matugen failed — styles will be generated on first login instead"
        return
    fi

    # Flatten any {"color":"#hex"} objects matugen v4 emits, then compile SCSS
    local reload_script="$HOME/.config/hypr/scripts/matugen_reload.sh"
    if [[ -f "$reload_script" ]]; then
        # Run reload script; pkill/killall targets won't exist yet — that's fine
        bash "$reload_script" 2>/dev/null || true
    fi

    success "Color scheme generated"
}

setup_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    local zsh_path
    zsh_path="$(which zsh)"
    if [ "$SHELL" != "$zsh_path" ]; then
        info "Setting zsh as default shell..."
        chsh -s "$zsh_path"
        success "Default shell set to zsh — takes effect on next login"
    fi
}

apply_keyboard() {
    info "Applying keyboard layout: $KB_LAYOUT"
    sudo localectl set-keymap "$KB_LAYOUT"
    sudo localectl set-x11-keymap "$KB_LAYOUT" "" "" "${KB_OPTIONS:-}"

    local settings="$DOTFILES_DIR/config/hypr/config/settings.conf"
    if [[ -f "$settings" ]]; then
        sed -i "s|kb_layout = .*|kb_layout = ${KB_LAYOUT}|" "$settings"
        if [[ -n "$KB_OPTIONS" ]]; then
            sed -i "s|kb_options = .*|kb_options = ${KB_OPTIONS}|" "$settings"
        else
            sed -i "s|kb_options = .*|kb_options =|" "$settings"
        fi
        success "Keyboard layout applied to Hyprland"
    fi
}

apply_timezone() {
    info "Setting timezone: $TIMEZONE"
    sudo timedatectl set-timezone "$TIMEZONE"
    sudo timedatectl set-ntp true
    success "Timezone set to $TIMEZONE, NTP enabled"
}

# Ensure locale is configured — a minimal Arch install may not have one set.
setup_locale() {
    if grep -q "^LANG=" /etc/locale.conf 2>/dev/null; then
        local current_lang
        current_lang=$(grep "^LANG=" /etc/locale.conf | head -1)
        success "Locale already configured: $current_lang"
        return
    fi

    info "Configuring locale (en_US.UTF-8)..."
    if ! grep -q "^en_US.UTF-8" /etc/locale.gen 2>/dev/null; then
        sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    fi
    sudo locale-gen
    echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf > /dev/null
    success "Locale set to en_US.UTF-8"
}

# Create standard XDG user directories (~/Downloads, ~/Documents, etc.)
setup_xdg_dirs() {
    info "Creating XDG user directories..."
    xdg-user-dirs-update
    success "XDG directories created"
}

setup_nvidia() {
    if [[ "$GPU_NAME" != "NVIDIA" ]]; then return; fi

    info "Configuring NVIDIA for Wayland/Hyprland..."

    if ! grep -q "nvidia_drm" /etc/mkinitcpio.conf; then
        sudo sed -i \
            's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' \
            /etc/mkinitcpio.conf
        sudo sed -i 's/MODULES=( /MODULES=(/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
        success "NVIDIA modules added to initramfs"
    fi

    if [[ -f /etc/default/grub ]]; then
        if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
            sudo sed -i \
                's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1 nvidia.NVreg_UsePageAttributeTable=1"/' \
                /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            success "NVIDIA DRM modeset kernel parameter added to GRUB"
        fi
    else
        warn "GRUB config not found — manually add 'nvidia-drm.modeset=1' to your bootloader kernel parameters"
    fi

    local env_conf="$HOME/.config/hypr/config/env.conf"
    if [[ -f "$env_conf" ]] && ! grep -q "GBM_BACKEND" "$env_conf"; then
        cat >> "$env_conf" <<'EOF'

# NVIDIA Wayland (added by install.sh)
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = ELECTRON_OZONE_PLATFORM_HINT,auto
EOF
        success "NVIDIA Wayland env vars written to hyprland env.conf"
    fi

    success "NVIDIA Wayland setup complete"
    warn "If using systemd-boot instead of GRUB, add 'nvidia-drm.modeset=1' to your boot entry manually"
}

install_extra_packages() {
    if [[ ${#EXTRA_PACKAGES[@]} -eq 0 ]]; then return; fi
    info "Installing additional packages: ${EXTRA_PACKAGES[*]}"
    yay -S --needed --noconfirm "${EXTRA_PACKAGES[@]}"
    success "Additional packages installed"
}

apply_wifi_backend() {
    info "Configuring NetworkManager WiFi backend: $WB_BACKEND"
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/wifi_backend.conf > /dev/null <<EOF
[device]
wifi.backend=$WB_BACKEND
EOF

    if [[ "$WB_BACKEND" == "iwd" ]]; then
        sudo systemctl enable --now iwd 2>/dev/null || true
        success "iwd enabled as NetworkManager WiFi backend"
    else
        sudo pacman -S --needed --noconfirm wpa_supplicant
        sudo systemctl disable --now iwd 2>/dev/null || true
        sudo systemctl mask iwd 2>/dev/null || true
        success "wpa_supplicant configured as NetworkManager WiFi backend"
    fi
}

setup_sddm_wayland() {
    info "Forcing SDDM Wayland backend..."
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null <<'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF
    success "SDDM Wayland backend configured"
}

enable_services() {
    info "Enabling system services..."

    local system_services=(NetworkManager bluetooth cups tuned ufw fstrim.timer)
    for svc in "${system_services[@]}"; do
        if sudo systemctl enable --now "$svc" 2>/dev/null; then
            success "enabled $svc"
        else
            warn "Could not enable $svc"
        fi
    done

    if sudo systemctl enable sddm 2>/dev/null; then
        success "enabled sddm (starts on next boot)"
    else
        warn "Could not enable sddm"
    fi

    info "Enabling user services (pipewire)..."
    local user_services=(pipewire pipewire-pulse wireplumber)
    for svc in "${user_services[@]}"; do
        if systemctl --user enable "$svc" 2>/dev/null; then
            success "enabled user: $svc"
        else
            warn "Could not enable user service $svc"
        fi
    done

    success "All services configured"
}

# ── Entry point ────────────────────────────────────────────────────────────
check_os
main_menu
