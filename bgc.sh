#!/bin/bash

# BearGrubChanger - by PapaOursPolaire 
# Version 48.8, mise à jour le 20/08/2025 à 19:07

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

# Clonage de mon dépôt GitHub
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

    read -p "✏️ Choix de la police GRUB : " choice
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

# Police système avec application automatique
function appliquer_police_systeme() {
    echo -e "\n⚙️ Configuration automatique de la police système"
    
    echo "Polices système disponibles:"
    local i=1
    SYS_FONTS_KEYS=()
    SYS_FONTS_NAMES=()
    
    # Parcourir les polices du repo LOCAL, du repo GIT et système
    for font in "$LOCAL_DIR/fonts"/*.{ttf,otf} "$REPO_DIR/fonts"/*.{pf2,ttf,otf} /usr/share/fonts/*/*.{pf2,ttf,otf}; do
        [ -f "$font" ] || continue
        name=$(basename "$font")
        # Extraire le nom de famille de la police
        family_name=$(fc-query --format='%{family}' "$font" 2>/dev/null | head -n1)
        if [ -n "$family_name" ]; then
            echo "$i. $name ($family_name)"
            SYS_FONTS_KEYS[$i]="$font"
            SYS_FONTS_NAMES[$i]="$family_name"
            ((i++))
        fi
    done

    if [ $i -eq 1 ]; then
        echo "❌ Aucune police trouvée."
        echo "💡 Astuce: Exécutez d'abord l'option 1 pour installer les polices"
        return 1
    fi

    read -p "✏️ Choix de la police système : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "❌ Choix invalide."; return 1
    fi

    local font_path="${SYS_FONTS_KEYS[$choice]}"
    local font_family="${SYS_FONTS_NAMES[$choice]}"
    
    echo "📋 Installation et configuration de la police système..."
    
    # Installe la police dans le système
    sudo mkdir -p /usr/share/fonts/custom
    sudo cp "$font_path" /usr/share/fonts/custom/
    sudo fc-cache -fv > /dev/null 2>&1

    # Application automatique selon l'environnement de bureau
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        # KDE Plasma
        echo "🔧 Configuration automatique pour KDE Plasma..."
        kwriteconfig5 --file kdeglobals --group General --key font "$font_family,11,-1,5,50,0,0,0,0,0"
        kwriteconfig5 --file kdeglobals --group General --key menuFont "$font_family,11,-1,5,50,0,0,0,0,0"
        kwriteconfig5 --file kdeglobals --group General --key smallestReadableFont "$font_family,9,-1,5,50,0,0,0,0,0"
        kwriteconfig5 --file kdeglobals --group General --key toolBarFont "$font_family,11,-1,5,50,0,0,0,0,0"
        kwriteconfig5 --file kdeglobals --group WM --key activeFont "$font_family,11,-1,5,50,0,0,0,0,0"
        
        # Force le rechargement de KDE
        qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
        kquitapp5 plasmashell && kstart plasmashell &
        
    elif pgrep -x "gnome-shell" >/dev/null 2>&1; then
        # GNOME
        echo "🔧 Configuration automatique pour GNOME..."
        gsettings set org.gnome.desktop.interface font-name "$font_family 11"
        gsettings set org.gnome.desktop.interface document-font-name "$font_family 11"
        gsettings set org.gnome.desktop.wm.preferences titlebar-font "$font_family Bold 11"
        gsettings set org.gnome.desktop.interface monospace-font-name "$font_family Mono 10"
        
    elif pgrep -x "xfce4-panel" >/dev/null 2>&1; then
        # XFCE
        echo "🔧 Configuration automatique pour XFCE..."
        xfconf-query -c xsettings -p /Gtk/FontName -s "$font_family 11"
        xfconf-query -c xfwm4 -p /general/title_font -s "$font_family Bold 11"
        
    else
        echo "⚠️ Environnement de bureau non reconnu."
        echo "💡 Police installée dans le système. Sélectionnez-la manuellement dans les paramètres."
    fi

    echo "✅ Police système '$font_family' configurée automatiquement."
    echo "🔄 Les changements seront visibles après redémarrage de la session."
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
    echo "📦 Installation complète de Plymouth..."
    
    # Installation selon la distribution
    if command -v apt >/dev/null; then
        sudo apt update
        sudo apt install plymouth plymouth-themes plymouth-x11 -y
    elif command -v pacman >/dev/null; then
        sudo pacman -S plymouth --noconfirm
    elif command -v dnf >/dev/null; then
        sudo dnf install plymouth plymouth-scripts plymouth-plugin-* -y
    else
        echo "❌ Distribution non supportée pour l'installation automatique"
        return 1
    fi
    
    # Activer Plymouth dans GRUB
    echo "⚙️ Configuration de GRUB pour Plymouth..."
    sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' "$GRUB_FILE"
    sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg
    
    echo "✅ Plymouth installé et configuré"
}

function choisir_theme_plymouth() {
    # Vérifier que Plymouth est installé
    if ! command -v plymouth >/dev/null; then
        echo "❌ Plymouth n'est pas installé. Utilisez l'option pour l'installer."
        return 1
    fi
    
    # Vérifier d'abord si les thèmes ont été clonés
    if [ ! -d "$REPO_DIR/plymouth" ]; then
        echo "⚠️ Dossier Plymouth non trouvé. Exécutez d'abord l'option 1."
        return 1
    fi

    echo "Thèmes Plymouth disponibles :"
    local i=1
    declare -a PLYM_KEYS
    
    # Parcourir le dossier plymouth du repo
    for theme in "$REPO_DIR/plymouth"/*; do
        if [ -d "$theme" ]; then
            name=$(basename "$theme")
            # Vérifier qu'il contient bien un fichier .plymouth
            if [ -f "$theme/$name.plymouth" ]; then
                echo "$i. $name"
                PLYM_KEYS[$i]="$name"
                ((i++))
            fi
        fi
    done

    if [ $i -eq 1 ]; then
        echo "❌ Aucun thème Plymouth valide trouvé dans $REPO_DIR/plymouth"
        echo "🔍 Vérification du contenu du dossier..."
        ls -la "$REPO_DIR/plymouth" 2>/dev/null || echo "Le dossier n'existe pas"
        return 1
    fi

    read -p "🔥 Choix du thème Plymouth : " plym_choice
    if ! [[ "$plym_choice" =~ ^[0-9]+$ ]] || ((plym_choice < 1 || plym_choice >= i)); then
        echo "❌ Choix invalide."
        return 1
    fi

    selected="${PLYM_KEYS[$plym_choice]}"
    echo "⚙️ Activation du thème $selected..."
    
    # Copier tout le dossier du thème
    sudo cp -r "$REPO_DIR/plymouth/$selected" "$PLYMOUTH_DIR/"
    
    # Vérifier que le fichier .plymouth existe
    if [ -f "$PLYMOUTH_DIR/$selected/$selected.plymouth" ]; then
        # Méthode alternative si plymouth-set-default-theme n'existe pas
        if command -v plymouth-set-default-theme >/dev/null; then
            sudo plymouth-set-default-theme "$selected"
        else
            # Configuration manuelle
            echo "⚙️ Configuration manuelle de Plymouth..."
            
            # Créer/modifier le fichier de configuration Plymouth
            sudo mkdir -p /etc/plymouth
            echo "[Daemon]" | sudo tee /etc/plymouth/plymouthd.conf > /dev/null
            echo "Theme=$selected" | sudo tee -a /etc/plymouth/plymouthd.conf > /dev/null
            
            # Alternative avec update-alternatives sur Debian/Ubuntu
            if command -v update-alternatives >/dev/null; then
                sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "/usr/share/plymouth/themes/$selected/$selected.plymouth" 100
                sudo update-alternatives --set default.plymouth "/usr/share/plymouth/themes/$selected/$selected.plymouth"
            fi
        fi
        
        # Reconstruire l'initramfs
        echo "🔄 Reconstruction de l'initramfs..."
        if command -v update-initramfs >/dev/null; then
            sudo update-initramfs -u -k all
        elif command -v dracut >/dev/null; then
            sudo dracut -f --regenerate-all
        elif command -v mkinitcpio >/dev/null; then
            sudo mkinitcpio -P
        fi
        
        echo "✅ Plymouth configuré avec le thème $selected"
        echo "🔄 Redémarrez pour voir les changements"
        echo "💡 Si Plymouth ne s'affiche pas, vérifiez que 'quiet splash' est dans GRUB_CMDLINE_LINUX_DEFAULT"
    else
        echo "❌ Fichier $selected.plymouth introuvable dans $PLYMOUTH_DIR/$selected/"
        echo "🔍 Contenu du dossier :"
        ls -la "$PLYMOUTH_DIR/$selected/" 2>/dev/null
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

# Splashscreen KDE avec support GIF optimisé
function activer_splashscreen_kde() {
    # Vérifier et installer les dépendances Python pour KDE
    echo "🔧 Installation des dépendances Python pour KDE..."
    if command -v apt &>/dev/null; then
        sudo apt install python3-pyqt5 python3-qtpy python3-dbus.mainloop.pyqt5 python3-xml -y
    elif command -v pacman &>/dev/null; then
        sudo pacman -S python-pyqt5 python-qtpy python-dbus-next --noconfirm
    elif command -v dnf &>/dev/null; then
        sudo dnf install python3-qt5 python3-qtpy dbus-python -y
    else
        echo "⚠️ Impossible d'installer les dépendances automatiquement"
    fi

    if [ ! -d "$REPO_DIR/splashscreens" ]; then
        echo "❌ Dossier splashscreens introuvable. Exécutez d'abord l'option 1."
        return 1
    fi

        # Trouver les fichiers splashscreen (GIF prioritaire)
    declare -a splash_files
    while IFS= read -r -d $'\0' file; do
        splash_files+=("$file")
    done < <(find "$REPO_DIR/splashscreens" -maxdepth 1 -type f \( -iname "*.gif" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0)

    if [ ${#splash_files[@]} -eq 0 ]; then
        echo "❌ Aucun splashscreen valide trouvé."
        echo "🔍 Contenu du dossier :"
        ls -la "$REPO_DIR/splashscreens" 2>/dev/null
        return 1
    fi

    echo -e "\n🎞️ Splashscreens disponibles :"
    for i in "${!splash_files[@]}"; do
        echo "$((i+1)). $(basename "${splash_files[$i]}")"
    done

    read -p "💫 Sélectionnez un splashscreen [1-${#splash_files[@]}] : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#splash_files[@]})); then
        echo "❌ Sélection invalide."
        return 1
    fi

    selected="${splash_files[$((choice-1))]}"
    selected_name=$(basename "$selected")
    file_ext="${selected_name##*.}"
    
    echo "🖌️ Application de $selected_name..."
    
    # Identifier la version de KDE
    if [ -n "$KDE_SESSION_VERSION" ] || [ "$DESKTOP_SESSION" = "plasma" ] || pgrep -x "plasmashell" >/dev/null 2>&1; then
        # Nom du thème fixe et simple
        THEME_NAME="bearsplash"
        THEME_DIR="$HOME/.local/share/plasma/look-and-feel/$THEME_NAME"
        
        # Supprimer l'ancien thème s'il existe
        rm -rf "$THEME_DIR"
        
        # Créer la structure complète du thème
        mkdir -p "$THEME_DIR/contents/splash"
        mkdir -p "$THEME_DIR/contents/splash/images"
        
        # Copier l'image avec un nom standard
        cp "$selected" "$THEME_DIR/contents/splash/images/background.$file_ext"
        
        # Créer le fichier metadata.desktop avec le bon nom
        cat > "$THEME_DIR/metadata.desktop" << 'EOF'
[Desktop Entry]
Name=Bear Splash
Comment=Custom Bear Splashscreen by PapaOursPolaire
X-KDE-PluginInfo-Author=PapaOursPolaire
X-KDE-PluginInfo-Name=bearsplash
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL
X-KDE-ServiceTypes=Plasma/LookAndFeel
Type=Service
EOF

        # Créer le fichier Splash.qml optimisé pour GIF
        if [[ "$file_ext" == "gif" ]]; then
            cat > "$THEME_DIR/contents/splash/Splash.qml" << EOF
import QtQuick 2.5

Rectangle {
    id: root
    color: "black"
    
    property int stage
    
    onStageChanged: {
        if (stage == 1) {
            splashImage.visible = true
        }
    }
    
    AnimatedImage {
        id: splashImage
        anchors.fill: parent
        source: "images/background.$file_ext"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: false
        playing: true
        
        PropertyAnimation on opacity {
            running: splashImage.visible
            from: 0
            to: 1
            duration: 500
            easing.type: Easing.InOutQuad
        }
    }
    
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        width: 200
        height: 4
        color: "rgba(255,255,255,0.2)"
        radius: 2
        
        Rectangle {
            id: progressBar
            anchors.left: parent.left
            anchors.top: parent.top
            height: parent.height
            width: 0
            color: "white"
            radius: parent.radius
            
            PropertyAnimation on width {
                running: splashImage.visible
                from: 0
                to: parent.width
                duration: 3000
                easing.type: Easing.OutCubic
            }
        }
    }
}
EOF
        else
            cat > "$THEME_DIR/contents/splash/Splash.qml" << EOF
import QtQuick 2.5

Rectangle {
    id: root
    color: "black"
    
    property int stage
    
    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true
        }
    }
    
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "images/background.$file_ext"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        opacity: 0
        
        PropertyAnimation on opacity {
            id: introAnimation
            running: false
            from: 0
            to: 1
            duration: 800
            easing.type: Easing.InOutQuad
        }
    }
    
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        width: 200
        height: 4
        color: "rgba(255,255,255,0.2)"
        radius: 2
        
        Rectangle {
            id: progressBar
            anchors.left: parent.left
            anchors.top: parent.top
            height: parent.height
            width: 0
            color: "white"
            radius: parent.radius
            
            PropertyAnimation on width {
                running: introAnimation.running
                from: 0
                to: parent.width
                duration: 2000
                easing.type: Easing.OutCubic
            }
        }
    }
}
EOF
        fi

        # Application automatique du thème
        echo "⚙️ Application automatique du thème..."
        if command -v kbuildsycoca5 &>/dev/null; then
            kbuildsycoca5 --noincremental
        fi

        sleep 1

        # Configuration directe des fichiers KDE
        kwriteconfig5 --file ksplashrc --group KSplash --key Theme "$THEME_NAME"
        kwriteconfig5 --file ksplashrc --group KSplash --key Engine "KSplashQML"
        
        # Application via lookandfeeltool
        if command -v lookandfeeltool &>/dev/null; then
            lookandfeeltool -a "$THEME_NAME" 2>/dev/null || true
        fi

        # Forcer le rechargement complet de KDE
        killall plasmashell 2>/dev/null || true
        sleep 1
        kstart plasmashell &

        echo "✅ Splashscreen '$selected_name' installé et activé automatiquement!"
        echo "🔄 Déconnectez-vous et reconnectez-vous pour voir le splashscreen au démarrage"
        
    else
        echo "❌ KDE Plasma n'est pas détecté"
        return 1
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

# Fond d'écran animé KDE Plasma avec explorateur de fichiers
function activer_fond_anime_kde() {
    # Vérifier que KDE Plasma est bien détecté
    if ! pgrep -x "plasmashell" >/dev/null; then
        echo "❌ KDE Plasma n'est pas détecté comme environnement actuel"
        return 1
    fi

    echo -e "\n🎬 ACTIVATION DE FOND D'ÉCRAN VIDÉO POUR KDE PLASMA"
    
    # Définir les dossiers vidéos possibles
    VIDEOS_DIRS=("$HOME/Videos" "$HOME/Vidéos" "$HOME/Downloads" "$HOME/Téléchargements" "$HOME")
    VIDEOS_DIR=""
    
    # Trouver le premier dossier qui existe
    for dir in "${VIDEOS_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            VIDEOS_DIR="$dir"
            break
        fi
    done
    
    echo "📂 Dossiers vidéos détectés:"
    echo "   $VIDEOS_DIR"
    
    # Méthode 1: Lister les vidéos disponibles directement
    echo -e "\n🔍 Recherche de vidéos dans les dossiers courants..."
    declare -a video_files
    
    # CORRECTION : Boucle while complète et correctement formée
    while IFS= read -r -d $'\0' file; do
        video_files+=("$file")
    done < <(find "${VIDEOS_DIRS[@]}" "$HOME/Downloads" "$HOME/Téléchargements" "$HOME/Desktop" "$HOME/Bureau" 2>/dev/null -maxdepth 2 -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.flv" \) -print0 2>/dev/null | head -20)
    
    if [ ${#video_files[@]} -gt 0 ]; then
        echo -e "\n🎥 VIDÉOS DÉTECTÉES :"
        for i in "${!video_files[@]}"; do
            echo "$((i+1)). $(basename "${video_files[$i]}")"
            echo "    📁 ${video_files[$i]}"
        done
        echo "$((${#video_files[@]}+1)). 📝 Saisir un chemin manuellement"
        
        read -p "🎯 Choisissez une vidéo [1-$((${#video_files[@]}+1))]: " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#video_files[@]})); then
            video_path="${video_files[$((choice-1))]}"
        elif [ "$choice" = "$((${#video_files[@]}+1))" ]; then
            # Ouvrir l'explorateur en arrière-plan (sans attendre)
            echo "📂 Ouverture de l'explorateur..."
            if command -v dolphin >/dev/null; then
                dolphin "$VIDEOS_DIR" >/dev/null 2>&1 &
            elif command -v nautilus >/dev/null; then
                nautilus "$VIDEOS_DIR" >/dev/null 2>&1 &
            elif command -v thunar >/dev/null; then
                thunar "$VIDEOS_DIR" >/dev/null 2>&1 &
            else
                xdg-open "$VIDEOS_DIR" >/dev/null 2>&1 &
            fi
            sleep 2
            echo "🎥 Saisissez le chemin complet du fichier vidéo :"
            read -p "📂 Chemin vers la vidéo : " video_path
        else
            echo "❌ Choix invalide"
            return 1
        fi
    else
        echo "⚠️ Aucune vidéo détectée automatiquement"
        echo "📂 Ouverture de l'explorateur pour sélection manuelle..."
        
        # Ouvrir l'explorateur en arrière-plan
        if command -v dolphin >/dev/null; then
            dolphin "$VIDEOS_DIR" >/dev/null 2>&1 &
        elif command -v nautilus >/dev/null; then
            nautilus "$VIDEOS_DIR" >/dev/null 2>&1 &
        elif command -v thunar >/dev/null; then
            thunar "$VIDEOS_DIR" >/dev/null 2>&1 &
        else
            xdg-open "$VIDEOS_DIR" >/dev/null 2>&1 &
        fi
        
        sleep 2
        echo "🎥 Saisissez le chemin complet du fichier vidéo :"
        read -p "📂 Chemin vers la vidéo : " video_path
    fi
    
    # Vérifier que le fichier existe et est une vidéo
    if [ ! -f "$video_path" ]; then
        echo "❌ Fichier non trouvé : $video_path"
        return 1
    fi
    
    # Vérifier l'extension
    case "${video_path,,}" in
        *.mp4|*.webm|*.mkv|*.avi|*.mov|*.flv)
            echo "✅ Format vidéo supporté détecté"
            ;;
        *)
            echo "❌ Format non supporté. Utilisez : mp4, webm, mkv, avi, mov, flv"
            return 1
            ;;
    esac
    
    local video_name=$(basename "$video_path")
    
    echo -e "\n🛠️ Création du fond d'écran vidéo pour '$video_name'..."

    # Installer les dépendances nécessaires
    echo "📦 Vérification des dépendances multimédia..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt install qml-module-qtmultimedia gstreamer1.0-plugins-good gstreamer1.0-plugins-bad -y >/dev/null 2>&1
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S qt5-multimedia gst-plugins-good gst-plugins-bad --noconfirm >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install qt5-qtmultimedia gstreamer1-plugins-good gstreamer1-plugins-bad-free -y >/dev/null 2>&1
    fi

    # Créer le dossier du plugin
    local plugin_dir="$HOME/.local/share/plasma/wallpapers/bear_video"
    rm -rf "$plugin_dir"
    mkdir -p "$plugin_dir/contents/ui"

    # Fichier metadata.desktop
    cat > "$plugin_dir/metadata.desktop" <<EOF
[Desktop Entry]
Name=Bear Video Wallpaper
Comment=Video wallpaper by BearGrubChanger
X-KDE-PluginInfo-Author=PapaOursPolaire
X-KDE-PluginInfo-Name=bear_video
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-Website=https://github.com/PapaOursPolaire/BearGrubChanger
X-KDE-PluginInfo-Category=Video
X-KDE-PluginInfo-License=GPL
X-KDE-PluginInfo-EnabledByDefault=true
X-KDE-ServiceTypes=Plasma/Wallpaper
X-Plasma-API=declarativeappletscript
X-Plasma-MainScript=ui/main.qml
Type=Service
EOF

    # Fichier main.qml optimisé avec gestion d'erreurs améliorée
    cat > "$plugin_dir/contents/ui/main.qml" <<EOF
import QtQuick 2.12
import QtMultimedia 5.12

Rectangle {
    id: root
    color: "black"
    
    property string videoPath: "file://$video_path"
    property bool videoLoaded: false
    
    Text {
        id: statusText
        anchors.centerIn: parent
        text: "Chargement de la vidéo..."
        color: "white"
        font.pointSize: 12
        visible: !videoLoaded
    }
    
    MediaPlayer {
        id: mediaplayer
        source: videoPath
        loops: MediaPlayer.Infinite
        muted: true
        autoPlay: false
        
        onError: {
            console.log("Erreur vidéo:", errorString)
            statusText.text = "Erreur: " + errorString
            statusText.visible = true
        }
        
        onStatusChanged: {
            console.log("Status:", status)
            if (status === MediaPlayer.Loaded) {
                videoLoaded = true
                statusText.visible = false
                play()
            } else if (status === MediaPlayer.InvalidMedia) {
                statusText.text = "Format vidéo non supporté"
                statusText.visible = true
            }
        }
        
        onPlaybackStateChanged: {
            console.log("Playback state:", playbackState)
        }
    }
    
    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        source: mediaplayer
        fillMode: VideoOutput.PreserveAspectCrop
        visible: videoLoaded
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (mediaplayer.playbackState === MediaPlayer.PlayingState) {
                    mediaplayer.pause()
                    statusText.text = "Vidéo en pause (clic pour reprendre)"
                    statusText.visible = true
                } else {
                    mediaplayer.play()
                    statusText.visible = false
                }
            }
        }
    }
    
    Timer {
        id: loadTimer
        interval: 3000
        running: true
        onTriggered: {
            if (!videoLoaded) {
                statusText.text = "Chargement en cours...\nClic pour réessayer"
            }
        }
    }
    
    Component.onCompleted: {
        console.log("Chargement vidéo:", videoPath)
        mediaplayer.play()
    }
    
    Component.onDestruction: {
        mediaplayer.stop()
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
        echo "1. Installer tous les thèmes, polices, icônes + GRUB + Plymouth + SDDM"
        echo "2. Changer le thème GRUB"
        echo "3. Appliquer une police pour le menu GRUB"
        echo "4. Changer la police système (application automatique)"
        echo "5. Remplacer les icônes GRUB"
        echo "6. Activer une animation Plymouth"
        echo "7. Activer un splashscreen KDE Plasma (GIF supporté)"
        echo "8. Changer le thème SDDM"
        echo "9. Ajuster le délai de sélection GRUB"
        echo "10. Fond d'écran animé KDE Plasma (sélection vidéo)"
        echo "11. Tester Plymouth"
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
            0) echo "👋 Vzy casse-toi d'là"; exit 0 ;;
            *) echo "❌ Option invalide." ;;
        esac
    done
}

menu_principal
