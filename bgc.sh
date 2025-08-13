#!/bin/bash

# BearGrubChanger - by PapaOursPolaire 
# Version 27.8

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
    echo "Polices disponibles pour GRUB:"
    local i=1
    FONTS_KEYS=()
    for font in "$LOCAL_DIR/fonts"/*.{pf2,ttf,otf}; do
        [ -f "$font" ] || continue
        name=$(basename "$font")
        echo "$i. $name"
        FONTS_KEYS[$i]="$name"
        ((i++))
    done

    if [ $i -eq 1 ]; then
        echo "❌ Aucune police trouvée dans $LOCAL_DIR/fonts/"
        return 1
    fi

    read -p "✒️ Choix de la police GRUB : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "❌ Choix invalide."; return 1
    fi

    selected="${FONTS_KEYS[$choice]}"
    current_theme=$(grep GRUB_THEME "$GRUB_FILE" | cut -d'=' -f2 | tr -d '"')

    if [ ! -f "$current_theme" ]; then
        echo "❌ Thème actif introuvable."; return 1
    fi

    sudo sed -i '/^terminal-font:/d' "$current_theme"
    echo "terminal-font: \"$LOCAL_DIR/fonts/$selected\"" | sudo tee -a "$current_theme"
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "✅ Police GRUB $selected appliquée."
}

# Police système
function appliquer_police_systeme() {
    echo -e "\n⚠️ Cette option va installer des polices système supplémentaires."
    read -p "Voulez-vous utiliser la même police que GRUB? (o/n) " same_font
    
    if [[ "$same_font" =~ ^[oO]$ ]]; then
        if [ -z "$selected" ]; then
            echo "❌ Aucune police GRUB sélectionnée. Utilisez d'abord l'option 3."
            return 1
        fi
        font_path="$LOCAL_DIR/fonts/$selected"
    else
        echo "Polices système disponibles:"
        local i=1
        SYS_FONTS_KEYS=()
        for font in /usr/share/fonts/* "$LOCAL_DIR/fonts"/*.{ttf,otf}; do
            [ -f "$font" ] || continue
            name=$(basename "$font")
            echo "$i. $name"
            SYS_FONTS_KEYS[$i]="$font"
            ((i++))
        done

        read -p "✒️ Choix de la police système : " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
            echo "❌ Choix invalide."; return 1
        fi
        font_path="${SYS_FONTS_KEYS[$choice]}"
    fi

    echo "📋 Installation de la police système..."
    sudo mkdir -p /usr/share/fonts/custom
    sudo cp "$font_path" /usr/share/fonts/custom/
    sudo fc-cache -fv
    echo "✅ Police système installée. Vous pouvez la sélectionner dans les paramètres de votre bureau."
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
    for theme in "$PLYMOUTH_TRANSITIONS_DIR"/*; do
        if [ -d "$theme" ]; then
            name=$(basename "$theme")
            echo "$i. $name"
            PLYM_KEYS[$i]="$name"
            ((i++))
        fi
    done

    if [ $i -eq 1 ]; then
        echo "❌ Aucun thème Plymouth trouvé dans $PLYMOUTH_TRANSITIONS_DIR"
        return 1
    fi

    read -p "🔥 Choix du thème Plymouth : " plym_choice
    if ! [[ "$plym_choice" =~ ^[0-9]+$ ]] || ((plym_choice < 1 || plym_choice >= i)); then
        echo "❌ Choix invalide."; return 1
    fi

    selected="${PLYM_KEYS[$plym_choice]}"
    echo "⚙️ Activation du thème $selected..."
    
    # Copie du thème dans le dossier Plymouth
    sudo cp -r "$PLYMOUTH_TRANSITIONS_DIR/$selected" "$PLYMOUTH_DIR/"
    
    if [ -f "$PLYMOUTH_DIR/$selected/$selected.plymouth" ]; then
        sudo plymouth-set-default-theme -R "$selected"
        sudo update-initramfs -u
        echo "✅ Plymouth activé avec le thème $selected"
    else
        echo "❌ Le thème sélectionné n'est pas installé correctement."
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
    
    if [ ! -d "$SPLASHSCREEN_DIR" ]; then
        echo "❌ Dossier splashscreens introuvable."
        return 1
    fi

    # Liste des fichiers splashscreen sans afficher le contenu du dossier
    splash_files=()
    while IFS= read -r -d $'\0' file; do
        splash_files+=("$file")
    done < <(find "$SPLASHSCREEN_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" \) -print0)

    if [ ${#splash_files[@]} -eq 0 ]; then
        echo "❌ Aucun splashscreen valide trouvé."
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
    
    # Solution plus fiable pour KDE Plasma
    echo "🖌️ Application de $selected_name..."
    
    # Méthode alternative pour KDE 5
    if command -v ksplashqml >/dev/null; then
        sudo cp "$selected" /usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents/splash/images/splash.png
        echo "✅ Splashscreen appliqué (méthode système)"
    else
        # Méthode utilisateur
        THEME_DIR="$HOME/.local/share/plasma/look-and-feel/org.kde.bear-splash"
        mkdir -p "$THEME_DIR/contents/splash/images"
        cp "$selected" "$THEME_DIR/contents/splash/images/splash.png"
        
        # Metadata obligatoire
        cat > "$THEME_DIR/metadata.desktop" <<EOF
[Desktop Entry]
Name=Bear Splash
Comment=Custom Splashscreen
X-KDE-PluginInfo-Author=PapaOurs
X-KDE-PluginInfo-Name=org.kde.bear-splash
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL
X-KDE-PluginInfo-Website=
X-KDE-ServiceTypes=Plasma/LookAndFeel
EOF

        # Fichier Splash.qml minimal
        cat > "$THEME_DIR/contents/splash/Splash.qml" <<EOF
import QtQuick 2.0
Image {
    source: "images/splash.png"
    anchors.fill: parent
}
EOF

        # Appliquer le thème
        if command -v lookandfeeltool >/dev/null; then
            lookandfeeltool -a org.kde.bear-splash
            echo "✅ Splashscreen appliqué! Redémarrez votre session."
        else
            echo "⚠️ Utilisez les paramètres système > Apparence > Style de démarrage"
            echo "   et sélectionnez 'Bear Splash'"
        fi
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
        echo "3. Appliquer une police pour le menu GRUB"
        echo "4. Changer la police système"
        echo "5. Remplacer les icônes GRUB"
        echo "6. Activer une animation Plymouth"
        echo "7. Activer un splashscreen KDE Plasma"
        echo "8. Changer le thème SDDM"
        echo "9. Ajuster le délai de sélection GRUB"
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
            4) appliquer_police_systeme ;;
            5) remplacer_icones ;;
            6) choisir_theme_plymouth ;;
            7) activer_splashscreen_kde ;;
            8) choisir_theme_sddm ;;
            9) ajuster_delai_grub ;;
            0) echo "👋 Vzy casse-toi d'là"; exit 0 ;;
            *) echo "❌ Option invalide." ;;
        esac
    done
}

menu_principal
