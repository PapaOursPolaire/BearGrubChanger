#!/bin/bash

# BearGrubChanger - by PapaOursPolaire 
# Version 39.0, mise à jour le 14/08/2025 14:45

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

# Splashscreen pour KDE Plasma
function activer_splashscreen_kde() {
    if [ ! -d "$REPO_DIR/splashscreens" ]; then
        echo "❌ Dossier splashscreens introuvable. Exécutez d'abord l'option 1."
        return 1
    fi

    # Trouver les fichiers splashscreen
    declare -a splash_files
    while IFS= read -r -d $'\0' file; do
        splash_files+=("$file")
    done < <(find "$REPO_DIR/splashscreens" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" \) -print0)

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
        cp "$selected" "$THEME_DIR/contents/splash/images/background.png"
        
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

        # Créer le fichier Splash.qml simple et fonctionnel
        cat > "$THEME_DIR/contents/splash/Splash.qml" << 'EOF'
import QtQuick 2.5

Rectangle {
    id: root
    color: "black"
    
    property int stage
    
    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true
        } else if (stage == 5) {
            backgroundImage.opacity = 1
        }
    }
    
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: "images/background.png"
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

        # Nettoyer les anciennes configurations
        if command -v kwriteconfig5 >/dev/null; then
            kwriteconfig5 --file ksplashrc --group KSplash --key Theme ""
            sleep 1
        fi
        
        # Appliquer le thème
        echo "⚙️ Application du thème..."
        if command -v lookandfeeltool >/dev/null 2>&1; then
            if lookandfeeltool -a "$THEME_NAME" 2>/dev/null; then
                echo "✅ Thème appliqué avec lookandfeeltool"
            else
                echo "⚠️ Erreur avec lookandfeeltool, essai avec kwriteconfig5..."
                if command -v kwriteconfig5 >/dev/null; then
                    kwriteconfig5 --file ksplashrc --group KSplash --key Theme "$THEME_NAME"
                fi
            fi
        elif command -v kwriteconfig5 >/dev/null; then
            kwriteconfig5 --file ksplashrc --group KSplash --key Theme "$THEME_NAME"
            echo "✅ Configuration écrite dans ksplashrc"
        else
            echo "⚠️ Impossible d'appliquer automatiquement le thème"
        fi
        
        echo "✅ Splashscreen '$selected_name' installé!"
        echo "📁 Dossier: $THEME_DIR"
        echo "🔄 Déconnectez-vous et reconnectez-vous pour voir les changements"
        echo ""
        echo "📋 En cas de problème, configuration manuelle:"
        echo "   1. Paramètres système → Apparence → Écran de démarrage"
        echo "   2. Sélectionnez 'Bear Splash'"
        echo "   3. Appliquez"
        
    else
        echo "❌ KDE Plasma non détecté."
        echo "🖥️ Environnement actuel: ${DESKTOP_SESSION:-inconnu}"
        echo "💡 Cette fonctionnalité nécessite KDE Plasma"
        return 1
    fi
}

# Fonction pour tester Plymouth
function tester_plymouth() {
    echo "🧪 Test de Plymouth..."
    
    # Vérifier l'installation
    if ! command -v plymouth >/dev/null; then
        echo "❌ Plymouth n'est pas installé"
        return 1
    fi
    
    # Afficher le thème actuel
    current_theme=""
    if [ -f /etc/plymouth/plymouthd.conf ]; then
        current_theme=$(grep "Theme=" /etc/plymouth/plymouthd.conf 2>/dev/null | cut -d'=' -f2)
    fi
    
    echo "📋 Thème actuel: ${current_theme:-aucun}"
    
    # Lister les thèmes installés
    echo "📂 Thèmes disponibles dans $PLYMOUTH_DIR:"
    if [ -d "$PLYMOUTH_DIR" ]; then
        for theme_dir in "$PLYMOUTH_DIR"/*; do
            if [ -d "$theme_dir" ]; then
                theme=$(basename "$theme_dir")
                if [ -f "$theme_dir/$theme.plymouth" ]; then
                    echo "  ✅ $theme"
                else
                    echo "  ❌ $theme (fichier .plymouth manquant)"
                fi
            fi
        done
    fi
    
    # Vérifier GRUB
    if grep -q "quiet splash" "$GRUB_FILE" 2>/dev/null; then
        echo "✅ GRUB configuré avec 'quiet splash'"
    else
        echo "⚠️ GRUB ne contient pas 'quiet splash'"
        echo "💡 Ajoutez 'quiet splash' à GRUB_CMDLINE_LINUX_DEFAULT"
    fi
    
    # Test avec un thème système
    echo ""
    read -p "🔬 Voulez-vous tester Plymouth maintenant? (o/n): " test_now
    if [[ "$test_now" =~ ^[oO]$ ]]; then
        echo "⏱️ Test de 5 secondes..."
        sudo plymouthd --debug --debug-file=/tmp/plymouth-debug.log &
        sleep 1
        sudo plymouth --show-splash
        sleep 5
        sudo plymouth --quit
        sudo pkill plymouthd 2>/dev/null
        
        echo "📋 Log du test:"
        if [ -f /tmp/plymouth-debug.log ]; then
            tail -10 /tmp/plymouth-debug.log
        else
            echo "Aucun log généré"
        fi
    fi
}

# Fonction pour diagnostiquer les problèmes Plymouth
function diagnostiquer_plymouth() {
    echo "🔍 Diagnostic Plymouth :"
    echo "- Plymouth installé : $(command -v plymouth >/dev/null && echo "✅ Oui" || echo "❌ Non")"
    echo "- Thème actuel : $(plymouth-set-default-theme --list | grep '\*' || echo "Aucun")"
    echo "- Thèmes disponibles :"
    plymouth-set-default-theme --list 2>/dev/null | sed 's/^/  /'
    echo "- Contenu dossier themes :"
    ls -la "$PLYMOUTH_DIR" 2>/dev/null | head -10
    echo "- Contenu repo Plymouth :"
    ls -la "$REPO_DIR/plymouth" 2>/dev/null | head -10
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

# Fond d'écran animé KDE Plasma
function activer_fond_anime_kde() {
    # Vérifier que KDE Plasma est détecté
    if [ ! -n "$KDE_SESSION_VERSION" ] && [ "$DESKTOP_SESSION" != "plasma" ] && ! pgrep -x "plasmashell" >/dev/null 2>&1; then
        echo "❌ KDE Plasma non détecté."
        echo "🖥️ Environnement actuel: ${DESKTOP_SESSION:-inconnu}"
        return 1
    fi

    echo -e "\n🎥 Installation de Smart Video Wallpaper Reborn pour KDE Plasma"

    # Vérifier et installer Python 3 et pip3
    if ! command -v python3 &>/dev/null; then
        echo "🔧 Installation de Python 3..."
        sudo apt install python3 -y || sudo pacman -S python --noconfirm || sudo dnf install python3 -y || {
            echo "❌ Échec de l'installation de Python 3."
            return 1
        }
    fi

    if ! command -v pip3 &>/dev/null; then
        echo "🔧 Installation de pip3..."
        sudo apt install python3-pip -y || sudo pacman -S python-pip --noconfirm || sudo dnf install python3-pip -y || {
            echo "❌ Échec de l'installation de pip3."
            return 1
        }
    fi

    # Installer les dépendances système nécessaires
    echo "🔧 Installation des dépendances système..."
    sudo apt install python3-venv python3-wheel python3-setuptools -y || \
    sudo pacman -S python-virtualenv python-wheel python-setuptools --noconfirm || \
    sudo dnf install python3-virtualenv python3-wheel python3-setuptools -y || {
        echo "⚠️ Impossible d'installer toutes les dépendances système, continuation quand même..."
    }

    # Installer Smart Video Wallpaper Reborn avec pip
    echo "📦 Installation de Smart Video Wallpaper Reborn..."
    if pip3 install --user --upgrade smartvideowallpaper-reborn; then
        echo "✅ Installation réussie avec pip"
    else
        echo "⚠️ Échec de l'installation standard, tentative avec pipx..."
        
        # Installer pipx si nécessaire
        if ! command -v pipx &>/dev/null; then
            echo "🔧 Installation de pipx..."
            python3 -m pip install --user pipx
            python3 -m pipx ensurepath
            # Recharger le PATH pour la session courante
            export PATH="$HOME/.local/bin:$PATH"
        fi

        if command -v pipx &>/dev/null; then
            if pipx install smartvideowallpaper-reborn; then
                echo "✅ Installation réussie avec pipx"
            else
                echo "❌ Échec définitif de l'installation avec pipx"
                return 1
            fi
        else
            echo "❌ pipx n'est toujours pas disponible après installation"
            return 1
        fi
    fi

    # Démarrer l'interface graphique
    echo "🚀 Lancement de Smart Video Wallpaper..."
    # Vérifier le PATH pour les commandes
    export PATH="$HOME/.local/bin:$PATH"
    
    if command -v smartvideowallpaper &>/dev/null; then
        smartvideowallpaper &
    elif command -v python3 &>/dev/null; then
        python3 -m smartvideowallpaper &
    else
        echo "❌ Impossible de trouver le bon commandement pour lancer Smart Video Wallpaper"
        return 1
    fi

    # Attendre que l'interface s'ouvre
    sleep 3

    # Instructions pour l'utilisateur
    echo -e "\n✅ Smart Video Wallpaper Reborn est maintenant lancé !"
    echo "📌 Instructions :"
    echo "1. Cliquez sur 'Add Video' pour sélectionner votre vidéo"
    echo "2. Ajustez les paramètres si nécessaire"
    echo "3. Cliquez sur 'Apply' pour activer le fond animé"
    echo "4. Fermez la fenêtre une fois configuré"
    echo ""
    echo "💡 Pour le désinstaller plus tard :"
    echo "   pip3 uninstall smartvideowallpaper-reborn"
    echo "   ou pipx uninstall smartvideowallpaper-reborn"
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
        echo "10. Diagnostic Plymouth"
        echo "11. Fond d'écran animé KDE Plasma"
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
            10) diagnostiquer_plymouth ;;
            11) activer_fond_anime_kde ;;
            0) echo "👋 Vzy casse-toi d'là"; exit 0 ;;
            *) echo "❌ Option invalide." ;;
        esac
    done
}

menu_principal
