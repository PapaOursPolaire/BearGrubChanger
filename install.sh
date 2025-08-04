#!/bin/bash

# 🐻 BearGrubChanger by PapaOursPolaire
# Version 14.2

# 📁 Chemins
THEMES_DIR="/boot/grub/themes"
LOCAL_DIR="$HOME/.grub-themes"
REPO_DIR="$LOCAL_DIR/BearGrubChanger"
GRUB_FILE="/etc/default/grub"
GIT_REPO="https://github.com/PapaOursPolaire/BearGrubChanger.git"
GIT_BRANCH="Projets"

# 📦 Vérifie si GRUB est installé, sinon l'installe
function verifier_et_installer_grub() {
    if ! command -v grub-install &>/dev/null; then
        echo "🔧 GRUB n'est pas installé. Installation en cours..."
        sudo apt install grub2-common grub-pc -y || \
        sudo pacman -S grub --noconfirm || \
        sudo dnf install grub2 -y || {
            echo "❌ Échec de l'installation de GRUB."; exit 1;
        }
    else
        echo "✅ GRUB est déjà installé."
    fi
}

# 🔍 Forcer l'affichage du menu GRUB
function forcer_affichage_menu_grub() {
    echo "🛠️ Configuration de l'affichage du menu GRUB..."
    sudo sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' "$GRUB_FILE" || echo 'GRUB_TIMEOUT_STYLE=menu' | sudo tee -a "$GRUB_FILE"
    sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' "$GRUB_FILE" || echo 'GRUB_TIMEOUT=5' | sudo tee -a "$GRUB_FILE"
}

# 🧬 Clone ou met à jour le dépôt
function cloner_depot() {
    mkdir -p "$LOCAL_DIR"
    if [ ! -d "$REPO_DIR" ]; then
        echo "📥 Clonage du dépôt BearGrubChanger..."
        git clone --depth 1 --branch "$GIT_BRANCH" "$GIT_REPO" "$REPO_DIR" || {
            echo "❌ Échec du clonage."; exit 1;
        }
    else
        echo "🔄 Mise à jour du dépôt..."
        git -C "$REPO_DIR" pull
    fi
}

# 🎨 Installe tous les thèmes, icônes, polices
function installer_tous_les_assets() {
    echo "📂 Installation des thèmes, icônes et polices..."
    sudo mkdir -p "$THEMES_DIR"
    sudo cp -r "$REPO_DIR/themes/"* "$THEMES_DIR/"
    mkdir -p "$LOCAL_DIR/icons"
    cp -r "$REPO_DIR/icons/"* "$LOCAL_DIR/icons/"
    mkdir -p "$LOCAL_DIR/fonts"
    cp -r "$REPO_DIR/fonts/"* "$LOCAL_DIR/fonts/"
    echo "✅ Installation terminée."
}

# 🎭 Appliquer un thème
function appliquer_theme() {
    echo "=== Thèmes disponibles ==="
    local i=1
    THEMES_KEYS=()
    for theme in "$THEMES_DIR"/*; do
        name=$(basename "$theme")
        echo "$i. $name"
        THEMES_KEYS[$i]="$name"
        ((i++))
    done

    read -p "🎨 Choix du thème : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "❌ Choix invalide."; exit 1
    fi

    selected="${THEMES_KEYS[$choice]}"
    echo "🛠️ Application du thème $selected..."
    sudo sed -i '/^GRUB_THEME=/d' "$GRUB_FILE"
    echo "GRUB_THEME=\"$THEMES_DIR/$selected/theme.txt\"" | sudo tee -a "$GRUB_FILE"
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "✅ Thème $selected appliqué."
}

# ✏️ Appliquer une police
function appliquer_police() {
    echo "=== Polices disponibles ==="
    local i=1
    FONTS_KEYS=()
    for font in "$LOCAL_DIR/fonts"/*; do
        name=$(basename "$font")
        echo "$i. $name"
        FONTS_KEYS[$i]="$name"
        ((i++))
    done

    read -p "✒️ Choix de la police : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "❌ Choix invalide."; exit 1
    fi

    selected="${FONTS_KEYS[$choice]}"
    current_theme=$(grep GRUB_THEME "$GRUB_FILE" | cut -d'=' -f2 | tr -d '"')

    if [ ! -f "$current_theme" ]; then
        echo "❌ Thème actif introuvable."; exit 1
    fi

    sudo sed -i '/^terminal-font:/d' "$current_theme"
    echo "terminal-font: $LOCAL_DIR/fonts/$selected" | sudo tee -a "$current_theme"
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "✅ Police $selected appliquée."
}

# 🖼️ Remplacer les icônes
function remplacer_icones() {
    echo "=== Packs d'icônes disponibles ==="
    local i=1
    ICONS_KEYS=()
    for pack in "$LOCAL_DIR/icons"/*; do
        name=$(basename "$pack")
        echo "$i. $name"
        ICONS_KEYS[$i]="$name"
        ((i++))
    done

    read -p "🖌️ Choix du pack : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "❌ Choix invalide."; exit 1
    fi

    selected="${ICONS_KEYS[$choice]}"
    current_theme=$(grep GRUB_THEME "$GRUB_FILE" | cut -d'=' -f2 | tr -d '"')
    theme_path=$(dirname "$current_theme")

    if [ ! -d "$theme_path/icons" ]; then
        mkdir -p "$theme_path/icons"
    fi

    sudo cp -r "$LOCAL_DIR/icons/$selected/"* "$theme_path/icons/"
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "✅ Icônes $selected appliquées."
}

# 🎛️ Menu principal
function menu_principal() {
    while true; do
        echo -e "\n==== 🐻 BearGrubChanger ===="
        echo "1. Installer tous les thèmes, icônes et polices"
        echo "2. Changer le thème GRUB"
        echo "3. Changer la police d'écriture"
        echo "4. Remplacer les icônes"
        echo "0. Quitter"
        read -p "🎮 Choix : " opt

        case "$opt" in
            1)
                verifier_et_installer_grub
                cloner_depot
                installer_tous_les_assets
                forcer_affichage_menu_grub
                ;;
            2)
                appliquer_theme
                ;;
            3)
                appliquer_police
                ;;
            4)
                remplacer_icones
                ;;
            0)
                echo "👋 À bientôt !"
                exit 0
                ;;
            *)
                echo "❌ Option invalide."
                ;;
        esac
    done
}

# ▶ Lancement
menu_principal
