#!/bin/bash

# BearGrubChanger - by PapaOursPolaire 
# Version 27.6

# Chemins et variables
THEMES_DIR="/boot/grub/themes"
LOCAL_DIR="$HOME/.grub-themes"
REPO_DIR="$LOCAL_DIR/BearGrubChanger"
GRUB_FILE="/etc/default/grub"
GIT_REPO="https://github.com/PapaOursPolaire/BearGrubChanger.git"
GIT_BRANCH="Projets"
PLYMOUTH_DIR="/usr/share/plymouth/themes"
SDDM_DIR="/usr/share/sddm/themes"
SDDM_CONFIG_DIR="/etc/sddm.conf.d"
SDDM_THEMES_DIR="$REPO_DIR/sddm"
SPLASHSCREEN_DIR="$REPO_DIR/splashscreens"

# Fonction pour installer Plymouth correctement
function installer_plymouth() {
    echo "📦 Installation de Plymouth..."
    if ! sudo apt install plymouth plymouth-themes plymouth-x11 -y && 
       ! sudo pacman -S plymouth --noconfirm && 
       ! sudo dnf install plymouth -y; then
        echo "❌ Échec de l'installation de Plymouth"
        return 1
    fi
    
    # Configuration supplémentaire pour garantir le fonctionnement
    sudo update-initramfs -u
    echo "✅ Plymouth installé et configuré"
}

# Fonction unifiée pour les thèmes Plymouth
function configurer_plymouth() {
    echo "🔧 Configuration Plymouth..."
    
    # Liste des thèmes disponibles
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

    read -p "🔥 Choix du thème [1-$((i-1))] : " plym_choice
    if ! [[ "$plym_choice" =~ ^[0-9]+$ ]] || ((plym_choice < 1 || plym_choice >= i)); then
        echo "❌ Choix invalide."
        return 1
    fi

    selected="${PLYM_KEYS[$plym_choice]}"
    
    # Application du thème avec vérification
    echo "⚙️ Activation du thème $selected..."
    if ! sudo plymouth-set-default-theme "$selected"; then
        echo "❌ Échec de l'application du thème"
        return 1
    fi
    
    # Mise à jour obligatoire
    sudo update-initramfs -u -k all
    echo "✅ Thème $selected appliqué avec succès"
    echo "🔄 Redémarrez pour voir les changements"
}

# Fonction unifiée pour les splashscreens KDE
function configurer_splashscreen_kde() {
    # Vérification de l'environnement KDE
    if [ "$XDG_CURRENT_DESKTOP" != "KDE" ] && [ "$DESKTOP_SESSION" != "plasma" ]; then
        echo "❌ KDE Plasma non détecté. Option réservée à KDE."
        return 1
    fi

    # Vérification du dossier
    if [ ! -d "$SPLASHSCREEN_DIR" ]; then
        echo "❌ Dossier introuvable : $SPLASHSCREEN_DIR"
        echo "→ Créez-le et placez-y vos fichiers GIF/PNG/JPG"
        return 1
    fi

    # Liste des fichiers disponibles
    shopt -s nullglob
    fichiers=("$SPLASHSCREEN_DIR"/*.{gif,GIF,png,PNG,jpg,JPG})
    
    if [ ${#fichiers[@]} -eq 0 ]; then
        echo "❌ Aucun fichier trouvé dans $SPLASHSCREEN_DIR"
        echo "Formats supportés: GIF/PNG/JPG"
        return 1
    fi

    echo -e "\n🎞️ Fichiers disponibles :"
    for i in "${!fichiers[@]}"; do
        echo "$((i+1)). $(basename "${fichiers[$i]}")"
    done

    read -p "💠 Sélection [1-${#fichiers[@]}] : " choix
    if ! [[ "$choix" =~ ^[0-9]+$ ]] || ((choix < 1 || choix > ${#fichiers[@]})); then
        echo "❌ Sélection invalide."
        return 1
    fi

    fichier="${fichiers[$((choix-1))]}"
    extension="${fichier##*.}"
    nom_theme="org.kde.bear-$(basename "$fichier" ".$extension")"

    # Création du thème
    THEME_DIR="$HOME/.local/share/plasma/look-and-feel/$nom_theme"
    mkdir -p "$THEME_DIR/contents/splash/images"
    cp "$fichier" "$THEME_DIR/contents/splash/images/splash.$extension"

    # Fichier metadata.desktop
    cat > "$THEME_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=Bear Splash $(basename "$fichier")
Comment=Personnalisé par BearGrubChanger
X-KDE-PluginInfo-Author=PapaOurs
X-KDE-PluginInfo-Name=$nom_theme
X-KDE-PluginInfo-Version=1.0
EOF

    # Fichier Splash.qml adapté
    if [[ "$extension" =~ ^(gif|GIF)$ ]]; then
        cat > "$THEME_DIR/contents/splash/Splash.qml" <<EOF
import QtQuick 2.0
import QtQuick.Controls 1.0
Item {
    AnimatedImage {
        anchors.fill: parent
        source: "images/splash.$extension"
        playing: true
    }
}
EOF
    else
        cat > "$THEME_DIR/contents/splash/Splash.qml" <<EOF
import QtQuick 2.0
Item {
    Image {
        anchors.fill: parent
        source: "images/splash.$extension"
        fillMode: Image.PreserveAspectCrop
    }
}
EOF
    fi

    # Application
    if command -v plasma-apply-lookandfeel >/dev/null; then
        plasma-apply-lookandfeel "$nom_theme"
        echo "✅ Splashscreen appliqué!"
    else
        echo "⚠️ Utilisez les paramètres KDE pour activer le thème:"
        echo "   Paramètres > Apparence > Style de démarrage"
    fi
}

# Délai GRUB à 15s par défaut
function forcer_affichage_menu_grub() {
    echo "🛠️ Configuration du menu GRUB..."
    sudo sed -i '/^GRUB_TIMEOUT_STYLE=/d' "$GRUB_FILE"
    sudo sed -i '/^GRUB_TIMEOUT=/d' "$GRUB_FILE"
    sudo sed -i '/^GRUB_HIDDEN_TIMEOUT=/d' "$GRUB_FILE"

    sudo tee -a "$GRUB_FILE" >/dev/null <<EOF
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=15
EOF
}

# Menu principal simplifié
function menu_principal() {
    while true; do
        echo -e "\n🐻 BearGrubChanger v27.6"
        echo "1. Installation complète"
        echo "2. Thème GRUB"
        echo "3. Police GRUB"
        echo "4. Icônes GRUB"
        echo "5. Configuration Plymouth"
        echo "6. Splashscreen KDE"
        echo "7. Thème SDDM"
        echo "8. Délai GRUB"
        echo "0. Quitter"
        read -p "🎮 Choix : " opt

        case "$opt" in
            1)
                verifier_et_installer_grub
                cloner_depot
                installer_tous_les_assets
                forcer_affichage_menu_grub
                installer_plymouth
                installer_sddm
                sudo update-grub
                ;;
            2) appliquer_theme ;;
            3) appliquer_police ;;
            4) remplacer_icones ;;
            5) configurer_plymouth ;;
            6) configurer_splashscreen_kde ;;
            7) choisir_theme_sddm ;;
            8) ajuster_delai_grub ;;
            0) echo "👋 À bientôt !"; exit 0 ;;
            *) echo "❌ Option invalide" ;;
        esac
    done
}

# Initialisation
clear
menu_principal
