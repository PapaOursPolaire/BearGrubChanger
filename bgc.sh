#!/bin/bash

# BearGrubChanger - by PapaOursPolaire 
# Version 27.7

# Chemins et variables
THEMES_DIR="/boot/grub/themes"
LOCAL_DIR="$HOME/.grub-themes"
REPO_DIR="$LOCAL_DIR/BearGrubChanger"
GRUB_FILE="/etc/default/grub"
GIT_REPO="https://github.com/PapaOursPolaire/BearGrubChanger.git"
GIT_BRANCH="Projets"
PLYMOUTH_DIR="/usr/share/plymouth/themes"
PLYMOUTH_TRANSITIONS_DIR="$REPO_DIR/plymouth/transitions"
SDDM_DIR="/usr/share/sddm/themes"
SDDM_CONFIG_DIR="/etc/sddm.conf.d"
SDDM_THEMES_DIR="$REPO_DIR/sddm"

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
GRUB_TIMEOUT=15
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
    
    # Installation des transitions Plymouth
    sudo mkdir -p "$PLYMOUTH_DIR"
    sudo cp -r "$REPO_DIR/plymouth/transitions/"* "$PLYMOUTH_DIR/"
    
    # Installation des thèmes SDDM
    sudo mkdir -p "$SDDM_DIR"
    sudo cp -r "$REPO_DIR/sddm/"* "$SDDM_DIR/"
    
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

# Configration de la police GRUB
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
    echo "Packs d'icônes disponibles :"
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
    sudo apt install plymouth plymouth-themes -y || sudo pacman -S plymouth --noconfirm || sudo dnf install plymouth -y
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
    
    # Installation du thème sélectionné
    if [ -f "$PLYMOUTH_DIR/$selected/$selected.plymouth" ]; then
        sudo plymouth-set-default-theme -R "$selected"
        sudo update-initramfs -u
        echo "✅ Plymouth activé avec le thème $selected"
    else
        echo "❌ Le thème sélectionné n'est pas installé correctement."
        echo "Essayez de réinstaller Plymouth et les thèmes."
    fi
}

# SDDM
function installer_sddm() {
    echo "📦 Installation de SDDM..."
    sudo apt install sddm -y || sudo pacman -S sddm --noconfirm || sudo dnf install sddm -y
    sudo systemctl enable sddm
}

function choisir_theme_sddm() {
    echo "Thèmes SDDM disponibles :"
    local i=1
    SDDM_KEYS=()
    for theme in "$SDDM_THEMES_DIR"/*; do
        if [ -d "$theme" ]; then
            name=$(basename "$theme")
            echo "$i. $name"
            SDDM_KEYS[$i]="$name"
            ((i++))
        fi
    done

    read -p "🖥️ Choix du thème SDDM : " sddm_choice
    if ! [[ "$sddm_choice" =~ ^[0-9]+$ ]] || ((sddm_choice < 1 || sddm_choice >= i)); then
        echo "❌ Choix invalide."; exit 1
    fi

    selected="${SDDM_KEYS[$sddm_choice]}"
    echo "⚙️ Activation du thème $selected..."
    
    # Créer le dossier de configuration si inexistant
    sudo mkdir -p "$SDDM_CONFIG_DIR"
    
    # Configurer SDDM pour utiliser le thème sélectionné
    sudo tee "$SDDM_CONFIG_DIR/bear-theme.conf" >/dev/null <<EOF
[Theme]
Current=$selected
EOF

    echo "✅ Thème SDDM $selected appliqué."
    echo "🔄 Redémarrez SDDM pour voir les changements: sudo systemctl restart sddm"
}

# Splashscreen pour KDE Plasma
function activer_splashscreen_kde() {
    SPLASHSCREEN_DIR="$REPO_DIR/splashscreens"
    
    # Vérification renforcée
    if [ ! -d "$SPLASHSCREEN_DIR" ]; then
        echo "❌ Erreur : Dossier introuvable -> $SPLASHSCREEN_DIR"
        echo "Solutions possibles :"
        echo "1. Créez le dossier manuellement : mkdir -p '$SPLASHSCREEN_DIR'"
        echo "2. Vérifiez que le dépôt a bien été cloné"
        return 1
    fi

    # Debug : Affiche le contenu réel
    echo "🔍 Contenu du dossier :"
    ls -lh "$SPLASHSCREEN_DIR" || return 1

    # Détection robuste des fichiers supportés
    shopt -s nullglob
    splash_files=("$SPLASHSCREEN_DIR"/*.{png,jpg,jpeg,gif,PNG,JPG,JPEG,GIF})
    
    if [ ${#splash_files[@]} -eq 0 ]; then
        echo "❌ Aucun fichier splashscreen valide trouvé dans :"
        echo "   $SPLASHSCREEN_DIR"
        echo "   Formats supportés : PNG, JPG, GIF"
        return 1
    fi

    echo -e "\n🎞️ Splashscreens disponibles :"
    for i in "${!splash_files[@]}"; do
        echo "$((i+1)). $(basename "${splash_files[$i]}")"
    done

    read -p "💠 Sélectionnez un splashscreen [1-${#splash_files[@]}] : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#splash_files[@]})); then
        echo "❌ Sélection invalide."
        return 1
    fi

    selected="${splash_files[$((choice-1))]}"
    selected_name=$(basename "$selected")
    extension="${selected_name##*.}"
    
    echo "🖌️ Application de $selected_name..."

    # Vérification de l'environnement KDE
    if [ "$XDG_CURRENT_DESKTOP" != "KDE" ] && [ "$DESKTOP_SESSION" != "plasma" ]; then
        echo "❌ KDE Plasma non détecté. Cette option est réservée à KDE."
        return 1
    fi

    # Création du dossier du thème
    THEME_DIR="$HOME/.local/share/plasma/look-and-feel/org.kde.bear-splash"
    mkdir -p "$THEME_DIR/contents/splash/images"
    
    # Copie du fichier splashscreen
    cp "$selected" "$THEME_DIR/contents/splash/images/splash.$extension"

    # Fichier metadata.desktop
    cat > "$THEME_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=Bear Splash ($selected_name)
Comment=Splashscreen personnalisé BearGrubChanger
X-KDE-PluginInfo-Author=PapaOurs
X-KDE-PluginInfo-Name=org.kde.bear-splash
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL
X-KDE-ServiceTypes=Plasma/LookAndFeel
EOF

    # Fichier Splash.qml adapté au format
    if [[ "$extension" =~ ^(gif|GIF)$ ]]; then
        # Configuration pour GIF animé
        cat > "$THEME_DIR/contents/splash/Splash.qml" <<EOF
import QtQuick 2.0
import QtQuick.Controls 1.0

Item {
    AnimatedImage {
        id: animation
        anchors.fill: parent
        source: "images/splash.$extension"
        playing: true
    }
}
EOF
    else
        # Configuration pour image statique
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

    # Application du thème
    echo "⚙️ Activation du splashscreen..."
    if command -v plasma-apply-lookandfeel >/dev/null; then
        plasma-apply-lookandfeel org.kde.bear-splash
        echo "✅ Splashscreen appliqué avec succès!"
        echo "   Redémarrez votre session pour voir les changements."
    else
        echo "⚠️ Impossible d'appliquer automatiquement le splashscreen."
        echo "   Vous pouvez le sélectionner manuellement dans:"
        echo "   Paramètres système > Apparence > Style de démarrage"
    fi
}

function ajuster_delai_grub() {
    current_timeout=$(grep "GRUB_TIMEOUT=" "$GRUB_FILE" | cut -d'=' -f2)
    echo -e "\n⏱️ Délai actuel pour la sélection automatique : ${current_timeout:-15} secondes"
    read -p "Nouveau délai (en secondes, 0 pour désactiver) : " new_timeout

    if ! [[ "$new_timeout" =~ ^[0-9]+$ ]]; then
        echo "❌ Valeur invalide. Doit être un nombre entier."
        return 1
    fi

    sudo sed -i '/^GRUB_TIMEOUT=/d' "$GRUB_FILE"
    echo "GRUB_TIMEOUT=$new_timeout" | sudo tee -a "$GRUB_FILE"
    sudo update-grub

    echo "✅ Délai mis à jour : $new_timeout secondes"
    echo "Le système appliquera les changements au prochain démarrage."
}

# Interface utilisateur
function menu_principal() {
    while true; do
        echo -e "\n🐻 BearGrubChanger"
        echo "1. Installer tous les thèmes, polices, icônes + GRUB + Plymouth + SDDM"
        echo "2. Changer le thème GRUB"
        echo "3. Appliquer une police pour le menu grub"
        echo "4. Remplacer les icônes"
        echo "5. Activer une animation Plymouth"
        echo "6. Activer un splashscreen KDE Plasma"
        echo "7. Changer le thème SDDM"
        echo "8. Ajuster le délai de sélection GRUB"
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
                sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
                ;;
            2) appliquer_theme ;;
            3) appliquer_police ;;
            4) remplacer_icones ;;
            5) choisir_theme_plymouth ;;
            6) activer_splashscreen_kde ;;
            7) choisir_theme_sddm ;;
            8) ajuster_delai_grub ;;
            0) echo "👋 Vzy casse-toi d'là"; exit 0 ;;
            *) echo "❌ Option invalide." ;;
        esac
    done
}

menu_principal
