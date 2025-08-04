#!/bin/bash

# Made by PapaOursPolaire - available on GitHub

THEMES_DIR="/boot/grub/themes"
LOCAL_DIR="$HOME/.grub-themes"
GRUB_FILE="/etc/default/grub"

# Dictionnaire des thèmes : Nom -> URL du dossier contenant le thème
declare -A THEMES_URLS=(
    ["Arcade"]="https://raw.githubusercontent.com/PapaOursPolaire/BearGrubChanger/Projets/themes/Arcade"
    ["Fallout"]="https://raw.githubusercontent.com/PapaOursPolaire/BearGrubChanger/Projets/themes/Fallout"
    ["CRT-Amber"]="https://raw.githubusercontent.com/PapaOursPolaire/BearGrubChanger/Projets/themes/CRT-Amber"
)

# URL de base pour les packs d'icônes
ICONS_BASE_URL="https://raw.githubusercontent.com/PapaOursPolaire/BearGrubChanger/Projets/icons"

# Liste des packs d'icônes disponibles (actuellement, ce ne sont que des exemples)
ICONS_PACKS=("Default" "SciFi" "Minimal" "Neon" "TuxStyle")

# fonctions

function telecharger_theme() {
    local theme_name="$1"
    local url="${THEMES_URLS[$theme_name]}"
    local local_path="$LOCAL_DIR/$theme_name"

    mkdir -p "$local_path/icons"

    echo "📥 Téléchargement de $theme_name..."
    curl -fsSL "$url/theme.txt" -o "$local_path/theme.txt" || { echo "❌ theme.txt introuvable."; exit 1; }
    curl -fsSL "$url/background.png" -o "$local_path/background.png" || echo "⚠️ background.png manquant."
    curl -fsSL "$url/icons/icon.png" -o "$local_path/icons/icon.png" 2>/dev/null || echo "⚠️ icons par défaut manquant."
}

function telecharger_icons() {
    local pack_name="$1"
    local local_icons_path="$LOCAL_DIR/icons/$pack_name"

    echo "📥 Téléchargement du pack d'icônes : $pack_name..."
    mkdir -p "$local_icons_path"
    for icon in entry_ubuntu.png entry_windows.png entry_default.png; do
        curl -fsSL "$ICONS_BASE_URL/$pack_name/$icon" -o "$local_icons_path/$icon" || echo "⚠️ $icon manquant dans $pack_name"
    done
}

function installer_theme() {
    local theme_name="$1"
    local theme_src="$LOCAL_DIR/$theme_name"
    local theme_dest="$THEMES_DIR/$theme_name"

    echo "📂 Installation dans $theme_dest..."
    sudo mkdir -p "$theme_dest"
    sudo cp "$theme_src/theme.txt" "$theme_dest/"
    sudo cp "$theme_src/background.png" "$theme_dest/" 2>/dev/null
    sudo cp -r "$theme_src/icons" "$theme_dest/"

    echo "🛠️ Application du thème dans grub..."
    sudo sed -i '/^GRUB_THEME=/d' "$GRUB_FILE"
    echo "GRUB_THEME=\"$theme_dest/theme.txt\"" | sudo tee -a "$GRUB_FILE"

    if command -v update-grub &>/dev/null; then
        sudo update-grub
    elif command -v grub-mkconfig &>/dev/null; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi

    echo "✅ Thème $theme_name activé."
}

function remplacer_icons() {
    echo "=== Packs d'icônes disponibles ==="
    for i in "${!ICONS_PACKS[@]}"; do
        echo "$((i+1)). ${ICONS_PACKS[$i]}"
    done
    read -p "Choisissez un pack d'icônes : " ic

    if ! [[ "$ic" =~ ^[0-9]+$ ]] || ((ic < 1 || ic > ${#ICONS_PACKS[@]})); then
        echo "❌ Choix invalide."
        exit 1
    fi

    selected_pack="${ICONS_PACKS[$((ic-1))]}"
    telecharger_icons "$selected_pack"

    # Appliquer sur le thème actuellement actif
    current_theme=$(grep GRUB_THEME "$GRUB_FILE" | cut -d'=' -f2 | tr -d '"')
    if [ -z "$current_theme" ] || [ ! -d "$(dirname "$current_theme")" ]; then
        echo "❌ Aucun thème actif détecté."
        exit 1
    fi

    theme_path=$(dirname "$current_theme")
    sudo cp -r "$LOCAL_DIR/icons/$selected_pack"/* "$theme_path/icons/" || echo "⚠️ Erreur lors de la copie des icônes."

    echo "♻️ Mise à jour GRUB..."
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "✅ Icônes remplacées par le pack : $selected_pack"
}

# Interface graphique si l'on puis dire du shell script

mkdir -p "$LOCAL_DIR"

echo "=== Gestionnaire de thème GRUB ==="
echo "1. Changer de thème GRUB"
echo "2. Remplacer uniquement les icônes"
read -p "Choix : " choix

if [ "$choix" = "1" ]; then
    echo "=== Thèmes disponibles ==="
    i=1
    for key in "${!THEMES_URLS[@]}"; do
        echo "$i. $key"
        THEMES_KEYS[$i]="$key"
        ((i++))
    done
    read -p "Entrez le numéro du thème : " num

    selected_theme="${THEMES_KEYS[$num]}"
    if [ -z "$selected_theme" ]; then
        echo "❌ Thème invalide."
        exit 1
    fi

    telecharger_theme "$selected_theme"
    installer_theme "$selected_theme"

elif [ "$choix" = "2" ]; then
    remplacer_icons
else
    echo "❌ Choix invalide."
fi
