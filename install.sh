#!/bin/bash

# BearGrubChanger - by PapaOursPolaire 
# Version 27.4

# Chemins et variables
THEMES_DIR="/boot/grub/themes"
LOCAL_DIR="$HOME/.grub-themes"
REPO_DIR="$LOCAL_DIR/BearGrubChanger"
GRUB_FILE="/etc/default/grub"
GIT_REPO="https://github.com/PapaOursPolaire/BearGrubChanger.git"
GIT_BRANCH="Projets"
PLYMOUTH_DIR="/usr/share/plymouth/themes"

# Menu GRUB
function verifier_et_installer_grub() {
    if ! command -v grub-install &>/dev/null; then
        echo "🔧 GRUB n'est pas installé. Installation..."
        sudo apt install grub2-common grub-pc -y || \
        sudo pacman -S grub --noconfirm || \
        sudo dnf install grub2 -y || {
            echo "❌ Échec de l'installation de GRUB."; exit 1;
        }
    else
        echo "✅ GRUB est déjà installé."
    fi
}

function forcer_affichage_menu_grub() {
    echo "🛠️ Forçage affichage menu GRUB..."
    sudo sed -i '/^GRUB_TIMEOUT_STYLE=/d' "$GRUB_FILE"
    sudo sed -i '/^GRUB_TIMEOUT=/d' "$GRUB_FILE"
    sudo sed -i '/^GRUB_HIDDEN_TIMEOUT=/d' "$GRUB_FILE"

    sudo tee -a "$GRUB_FILE" >/dev/null <<EOF
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
EOF
}

# Clonage de mon dépot GitHub
function cloner_depot() {
    mkdir -p "$LOCAL_DIR"
    if [ ! -d "$REPO_DIR" ]; then
        echo "📥 Clonage du dépôt BearGrubChanger..."
        git clone --depth 1 --branch "$GIT_BRANCH" "$GIT_REPO" "$REPO_DIR" || {
            echo "❌ Clonage échoué."; exit 1;
        }
    else
        echo "🔄 Mise à jour du dépôt..."
        git -C "$REPO_DIR" pull
    fi
}

# Installation des fichiers
function installer_tous_les_assets() {
    echo "📂 Copie des thèmes, icônes et polices..."
    sudo mkdir -p "$THEMES_DIR"
    sudo cp -r "$REPO_DIR/themes/"* "$THEMES_DIR/"
    mkdir -p "$LOCAL_DIR/icons"
    cp -r "$REPO_DIR/icons/"* "$LOCAL_DIR/icons/"
    mkdir -p "$LOCAL_DIR/fonts"
    cp -r "$REPO_DIR/fonts/"* "$LOCAL_DIR/fonts/"
    echo "✅ Fichiers installés."
}

# Thème GRUB
function appliquer_theme() {
    echo "Thèmes disponibles :"
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
    echo "🖌️ Application du thème $selected..."
    sudo sed -i '/^GRUB_THEME=/d' "$GRUB_FILE"
    echo "GRUB_THEME=\"$THEMES_DIR/$selected/theme.txt\"" | sudo tee -a "$GRUB_FILE"
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "✅ Thème $selected appliqué."
}

# Configration de la police GRUB (uniquement, peut-etre ajouter dans le futur la police de l'OS et pas seulement du GRUB à voir si j'ai le temps)
function appliquer_police() {
    echo "Polices disponibles :"
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

# Icones GRUB
function remplacer_icones() {
    echo "Packs d'icones disponibles :"
    local i=1
    ICONS_KEYS=()
    for pack in "$LOCAL_DIR/icons"/*; do
        name=$(basename "$pack")
        echo "$i. $name"
        ICONS_KEYS[$i]="$name"
        ((i++))
    done

    read -p "🖼️ Choix du pack : " choice
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

# Plymouth
function installer_plymouth() {
    echo "📦 Installation de Plymouth..."
    sudo apt install plymouth -y || sudo pacman -S plymouth --noconfirm || sudo dnf install plymouth -y
}

function choisir_theme_plymouth() {
    echo "Thèmes Plymouth disponibles :"
    local i=1
    PLYM_KEYS=()
    for theme in "$PLYMOUTH_DIR"/*; do
        if [ -d "$theme" ]; then
            name=$(basename "$theme")
            echo "$i. $name"
            PLYM_KEYS[$i]="$name"
            ((i++))
        fi
    done

    read -p "🔥 Choix du thème Plymouth : " plym_choice
    if ! [[ "$plym_choice" =~ ^[0-9]+$ ]] || ((plym_choice < 1 || plym_choice >= i)); then
        echo "❌ Choix invalide."; exit 1
    fi

    selected="${PLYM_KEYS[$plym_choice]}"
    echo "⚙️ Activation du thème $selected..."
    sudo plymouth-set-default-theme "$selected"
    sudo update-initramfs -u
    echo "✅ Plymouth activé avec le thème $selected"
}

# Splashscreen pour les OS sous moteur graphique KDE Plasma
function activer_splashscreen_kde() {
    if [ "$XDG_CURRENT_DESKTOP" != "KDE" ] && [ "$DESKTOP_SESSION" != "plasma" ]; then
        echo "❌ KDE Plasma non détecté. Cette option est réservée à KDE."
        return
    fi

    echo "🎞️ Détection d'animations splashscreen GIF pour KDE Plasma..."
    local i=1
    SPLASH_KEYS=()

    for splash in "$SPLASHSCREEN_DIR"/*.gif; do
        [ -f "$splash" ] || continue
        name=$(basename "$splash")
        echo "$i. $name"
        SPLASH_KEYS[$i]="$splash"
        ((i++))
    done

    if [ "$i" -eq 1 ]; then
        echo "⚠️ Aucun fichier GIF trouvé dans $SPLASHSCREEN_DIR"
        return
    fi

    read -p "💠 Choix du splashscreen KDE : " splash_choice
    if ! [[ "$splash_choice" =~ ^[0-9]+$ ]] || ((splash_choice < 1 || splash_choice >= i)); then
        echo "❌ Choix invalide."; return
    fi

    selected="${SPLASH_KEYS[$splash_choice]}"
    echo "🖼️ Application du splashscreen $(basename "$selected")..."

    # Création d’un look-and-feel temporaire pour Plasma
    TEMP_DIR="$HOME/.local/share/plasma/look-and-feel/org.kde.bear-splash"
    mkdir -p "$TEMP_DIR/contents/splash/images"
    cp "$selected" "$TEMP_DIR/contents/splash/images/splash.gif"

    # Fichier metadata
    cat > "$TEMP_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=Bear Splash
Comment=Splashscreen personnalisé BearGrubChanger
X-KDE-PluginInfo-Author=PapaOurs
X-KDE-PluginInfo-Name=org.kde.bear-splash
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL
X-KDE-ServiceTypes=Plasma/LookAndFeel
EOF

    # Fichier de configuration de splash
    cat > "$TEMP_DIR/contents/splash/Splash.qml" <<EOF
import QtQuick 2.0

Item {
    Image {
        anchors.fill: parent
        source: "images/splash.gif"
    }
}
EOF

    # Activation du look & feel
    if command -v plasma-apply-lookandfeel &>/dev/null; then
        plasma-apply-lookandfeel org.kde.bear-splash
        echo "✅ Splashscreen KDE appliqué."
    else
        echo "⚠️ Impossible d'appliquer automatiquement le splashscreen. Utilise les paramètres KDE > Démarrage."
    fi
}

# Interface utilisateur
function menu_principal() {
    while true; do
        echo -e "\n🐻 BearGrubChanger"
        echo "1. Installer tous les thèmes, polices, icônes + GRUB + Plymouth"
        echo "2. Changer le thème GRUB"
        echo "3. Appliquer une police"
        echo "4. Remplacer les icônes"
        echo "5. Activer une animation Plymouth"
        echo "6. Activer un splashscreen KDE Plasma (.gif)"
        echo "0. Quitter"
        read -p "🎮 Choix : " opt

        case "$opt" in
            1)
                verifier_et_installer_grub
                cloner_depot
                installer_tous_les_assets
                forcer_affichage_menu_grub
                installer_plymouth
                sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
                ;;
            2) appliquer_theme ;;
            3) appliquer_police ;;
            4) remplacer_icones ;;
            5) choisir_theme_plymouth ;;
            6) activer_splashscreen_kde ;;
            0) echo "👋 Vzy casse-toi d'là"; exit 0 ;;
            *) echo "❌ Option invalide." ;;
        esac
    done
}

menu_principal