#!/bin/bash

# BearGrubChanger - by PapaOursPolaire 
# Version 268.8, mise à jour le 15/09/2025 - 20:11

# A APPORTER COMME MODIFICATIONS AU SCRIPT :
# - Installation automatique de spotdl ainsi que d'yt-dlp
# - Corriger/améliorer les options 4,9,10,11,13,14,15,19,20,21,23,24,25,26,27,28,29,30,31,32,33,34 & 35
# - Enelver l'option 32
# - Fusionner les options 16 et 17
# - Fusionner les options 10 et  11
# - Ajouter le changement d'environnement desktop en se basant sur la distro detectée

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
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"
FASTFETCH_IMAGES_DIR="$REPO_DIR/fastfetch/images"
FASTFETCH_LOGOS_DIR="$FASTFETCH_CONFIG_DIR/logos"

# Menu GRUB
function verifier_et_installer_grub() {
    if ! command -v grub-install &>/dev/null; then
        echo "GRUB n'est pas installé. Installation..."
        sudo apt install grub2-common grub-pc -y || \
        sudo pacman -S grub --noconfirm || \
        sudo dnf install grub2 -y || {
            echo "Échec de l'installation de GRUB."; exit 1;
        }
    else
        echo "GRUB est déjà installé."
    fi
}

function forcer_grub() {
    echo "Forçage affichage menu GRUB..."
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
        echo "Clonage du dépôt BearGrubChanger..."
        git clone --depth 1 --branch "$GIT_BRANCH" "$GIT_REPO" "$REPO_DIR" || {
            echo "Clonage échoué."; exit 1;
        }
    else
        echo "Mise à jour du dépôt..."
        git -C "$REPO_DIR" pull
    fi
}

# Installation des fichiers
function install_assets() {
    echo "Copie des thèmes, icônes et polices..."
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
    
    echo "Fichiers installés."
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

    read -p "Choix du thème : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "Choix invalide."; exit 1
    fi

    selected="${THEMES_KEYS[$choice]}"
    echo "Application du thème $selected..."
    sudo sed -i '/^GRUB_THEME=/d' "$GRUB_FILE"
    echo "GRUB_THEME=\"$THEMES_DIR/$selected/theme.txt\"" | sudo tee -a "$GRUB_FILE"
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "Thème $selected appliqué."
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
        echo "Aucune police trouvée dans $LOCAL_DIR/fonts/"
        return 1
    fi

    read -p "Choix de la police GRUB : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "Choix invalide."; return 1
    fi

    selected="${FONTS_KEYS[$choice]}"
    current_theme=$(grep GRUB_THEME "$GRUB_FILE" | cut -d'=' -f2 | tr -d '"')

    if [ ! -f "$current_theme" ]; then
        echo "Thème actif introuvable."; return 1
    fi

    sudo sed -i '/^terminal-font:/d' "$current_theme"
    echo "terminal-font: \"$LOCAL_DIR/fonts/$selected\"" | sudo tee -a "$current_theme"
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "Police GRUB $selected appliquée."
}

# Police système avec application automatique
function appliquer_police_systeme() {
    echo -e "\nConfiguration automatique de la police système"
    
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
        echo "Aucune police trouvée."
        echo "Astuce: Exécutez d'abord l'option 1 pour installer les polices"
        return 1
    fi

    read -p "Choix de la police système : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "Choix invalide."; return 1
    fi

    local font_path="${SYS_FONTS_KEYS[$choice]}"
    local font_family="${SYS_FONTS_NAMES[$choice]}"
    
    echo "Installation et configuration de la police système..."
    
    # Installe la police dans le système
    sudo mkdir -p /usr/share/fonts/custom
    sudo cp "$font_path" /usr/share/fonts/custom/
    sudo fc-cache -fv > /dev/null 2>&1

    # Application automatique selon l'environnement de bureau
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        # KDE Plasma
        echo "Configuration automatique pour KDE Plasma..."
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
        echo "Configuration automatique pour GNOME..."
        gsettings set org.gnome.desktop.interface font-name "$font_family 11"
        gsettings set org.gnome.desktop.interface document-font-name "$font_family 11"
        gsettings set org.gnome.desktop.wm.preferences titlebar-font "$font_family Bold 11"
        gsettings set org.gnome.desktop.interface monospace-font-name "$font_family Mono 10"
        
    elif pgrep -x "xfce4-panel" >/dev/null 2>&1; then
        # XFCE
        echo "Configuration automatique pour XFCE..."
        xfconf-query -c xsettings -p /Gtk/FontName -s "$font_family 11"
        xfconf-query -c xfwm4 -p /general/title_font -s "$font_family Bold 11"
        
    else
        echo "Environnement de bureau non reconnu."
        echo "Police installée dans le système. Sélectionnez-la manuellement dans les paramètres."
    fi

    echo "Police système '$font_family' configurée automatiquement."
    echo "Les changements seront visibles après redémarrage de la session."
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

    read -p "Choix du pack : " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "Choix invalide."; exit 1
    fi

    selected="${ICONS_KEYS[$choice]}"
    current_theme=$(grep GRUB_THEME "$GRUB_FILE" | cut -d'=' -f2 | tr -d '"')
    theme_path=$(dirname "$current_theme")

    if [ ! -d "$theme_path/icons" ]; then
        mkdir -p "$theme_path/icons"
    fi

    sudo cp -r "$LOCAL_DIR/icons/$selected/"* "$theme_path/icons/"
    sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    echo "Icônes $selected appliquées."
}

# Plymouth
function installer_plymouth() {
    echo "Installation complète de Plymouth..."
    
    # Installation selon la distribution
    if command -v apt >/dev/null; then
        sudo apt update
        sudo apt install plymouth plymouth-themes plymouth-x11 -y
    elif command -v pacman >/dev/null; then
        sudo pacman -S plymouth --noconfirm
    elif command -v dnf >/dev/null; then
        sudo dnf install plymouth plymouth-scripts plymouth-plugin-* -y
    else
        echo "Distribution non supportée pour l'installation automatique"
        return 1
    fi
    
    # Activer Plymouth dans GRUB
    echo "Configuration de GRUB pour Plymouth..."
    sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' "$GRUB_FILE"
    sudo update-grub 2>/dev/null || sudo grub-mkconfig -o /boot/grub/grub.cfg
    
    echo "Plymouth installé et configuré"
}

function choisir_plymouth() {
    # Vérifier que Plymouth est installé
    if ! command -v plymouth >/dev/null; then
        echo "Plymouth n'est pas installé. Utilisez l'option pour l'installer."
        return 1
    fi
    
    # Vérifier d'abord si les thèmes ont été clonés
    if [ ! -d "$REPO_DIR/plymouth" ]; then
        echo "Dossier Plymouth non trouvé. Exécutez d'abord l'option 1."
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
        echo "Aucun thème Plymouth valide trouvé dans $REPO_DIR/plymouth"
        echo "Vérification du contenu du dossier..."
        ls -la "$REPO_DIR/plymouth" 2>/dev/null || echo "Le dossier n'existe pas"
        return 1
    fi

    read -p "Choix du thème Plymouth : " plym_choice
    if ! [[ "$plym_choice" =~ ^[0-9]+$ ]] || ((plym_choice < 1 || plym_choice >= i)); then
        echo "Choix invalide."
        return 1
    fi

    selected="${PLYM_KEYS[$plym_choice]}"
    echo "Activation du thème $selected..."
    
    # Copier tout le dossier du thème
    sudo cp -r "$REPO_DIR/plymouth/$selected" "$PLYMOUTH_DIR/"
    
    # Vérifier que le fichier .plymouth existe
    if [ -f "$PLYMOUTH_DIR/$selected/$selected.plymouth" ]; then
        # Méthode alternative si plymouth-set-default-theme n'existe pas
        if command -v plymouth-set-default-theme >/dev/null; then
            sudo plymouth-set-default-theme "$selected"
        else
            # Configuration manuelle
            echo "Configuration manuelle de Plymouth..."
            
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
        echo "Reconstruction de l'initramfs..."
        if command -v update-initramfs >/dev/null; then
            sudo update-initramfs -u -k all
        elif command -v dracut >/dev/null; then
            sudo dracut -f --regenerate-all
        elif command -v mkinitcpio >/dev/null; then
            sudo mkinitcpio -P
        fi
        
        echo "Plymouth configuré avec le thème $selected"
        echo "Redémarrez pour voir les changements"
        echo "Si Plymouth ne s'affiche pas, vérifiez que 'quiet splash' est dans GRUB_CMDLINE_LINUX_DEFAULT"
    else
        echo "Fichier $selected.plymouth introuvable dans $PLYMOUTH_DIR/$selected/"
        echo "Contenu du dossier :"
        ls -la "$PLYMOUTH_DIR/$selected/" 2>/dev/null
    fi
}

# SDDM
function installer_sddm() {
    echo "Installation de SDDM..."
    sudo apt install sddm -y || sudo pacman -S sddm --noconfirm || sudo dnf install sddm -y
    sudo systemctl enable sddm
}

function choisir_sddm() {
    echo -e "\nGESTIONNAIRE DE THÈMES SDDM"
    
    # Vérifier que SDDM est installé
    if ! command -v sddm >/dev/null; then
        echo "SDDM n'est pas installé. Installation en cours..."
        installer_sddm || return 1
    fi
    
    # Vérifier que le dossier des thèmes SDDM existe
    if [ ! -d "$SDDM_THEMES_DIR" ]; then
        echo "Dossier des thèmes SDDM introuvable. Exécutez d'abord l'option 1."
        return 1
    fi
    
    while true; do
        echo -e "\n THÈMES SDDM DISPONIBLES"
        echo "0. SDDM Customisé (vidéo/GIF/images aléatoires)"
        
        # Lister les thèmes disponibles dans le dossier sddm du repo
        local i=1
        declare -a SDDM_THEMES
        declare -a SDDM_THEME_PATHS
        
        for theme_dir in "$SDDM_THEMES_DIR"/*; do
            if [ -d "$theme_dir" ] && [ -f "$theme_dir/metadata.desktop" ]; then
                theme_name=$(basename "$theme_dir")
                # Ne pas afficher le dossier custom s'il existe
                if [ "$theme_name" != "custom" ]; then
                    echo "$i. $theme_name"
                    SDDM_THEMES[$i]="$theme_name"
                    SDDM_THEME_PATHS[$i]="$theme_dir"
                    ((i++))
                fi
            fi
        done
        
        echo "$i. Importer un thème SDDM (dossier externe)"
        echo "$((i+1)). Retour au menu principal"
        
        read -p "Choisissez une option [0-$((i+1))]: " sddm_choice
        
        case "$sddm_choice" in
            0)
                configurer_sddm_customise
                ;;
            $i)
                importer_theme_sddm
                ;;
            $((i+1)))
                return 0
                ;;
            *)
                if [[ "$sddm_choice" =~ ^[0-9]+$ ]] && ((sddm_choice >= 1 && sddm_choice < i)); then
                    selected_theme="${SDDM_THEMES[$sddm_choice]}"
                    selected_path="${SDDM_THEME_PATHS[$sddm_choice]}"
                    activer_theme_sddm "$selected_theme" "$selected_path"
                else
                    echo "Option invalide."
                fi
                ;;
        esac
    done
}

# Fonction pour activer un thème SDDM
function activer_theme_sddm() {
    local theme_name="$1"
    local theme_path="$2"
    
    echo "Activation du thème $theme_name..."
    
    # Copier le thème dans le dossier système SDDM
    sudo mkdir -p "$SDDM_DIR/$theme_name"
    sudo cp -r "$theme_path"/* "$SDDM_DIR/$theme_name/"
    
    # Configurer SDDM pour utiliser ce thème
    sudo mkdir -p "$SDDM_CONFIG_DIR"
    sudo tee "$SDDM_CONFIG_DIR/bear-theme.conf" >/dev/null <<EOF
[Theme]
Current=$theme_name
EOF
    
    echo "Thème SDDM $theme_name appliqué avec succès."
    echo "Redémarrez SDDM pour voir les changements: sudo systemctl restart sddm"
}

# Fonction pour importer un thème SDDM externe
function importer_theme_sddm() {
    echo -e "\nIMPORTATION D'UN THÈME SDDM EXTERNE"
    
    # Ouvrir l'explorateur de fichiers pour sélectionner un dossier
    theme_dir=$(selectionner_dossier_interactif "$HOME" "Sélectionnez le dossier du thème SDDM")
    
    if [ -z "$theme_dir" ] || [ ! -d "$theme_dir" ]; then
        echo "Aucun dossier sélectionné ou dossier invalide."
        return 1
    fi
    
    # Vérifier que le dossier contient les fichiers nécessaires
    if [ ! -f "$theme_dir/metadata.desktop" ]; then
        echo "Le dossier sélectionné ne semble pas être un thème SDDM valide."
        echo "Un thème SDDM doit contenir au moins un fichier metadata.desktop."
        return 1
    fi
    
    # Extraire le nom du thème
    theme_name=$(basename "$theme_dir")
    
    # Copier le thème dans le dossier des thèmes SDDM système
    echo "Installation du thème $theme_name..."
    sudo mkdir -p "$SDDM_DIR/$theme_name"
    sudo cp -r "$theme_dir"/* "$SDDM_DIR/$theme_name/"
    
    # Activer le thème
    activer_theme_sddm "$theme_name" "$SDDM_DIR/$theme_name"
}

# Fonction pour configurer le thème SDDM customisé
function configurer_sddm_customise() {
    echo -e "\nCONFIGURATION DU THÈME SDDM CUSTOMISÉ"
    
    # Créer le dossier du thème custom
    CUSTOM_SDDM_THEME_DIR="$SDDM_DIR/custom"
    sudo mkdir -p "$CUSTOM_SDDM_THEME_DIR"
    
    # Vérifier si le dossier custom existe dans le repo
    if [ -d "$SDDM_THEMES_DIR/custom" ]; then
        # Copier les fichiers du dossier custom du repo
        sudo cp -r "$SDDM_THEMES_DIR/custom"/* "$CUSTOM_SDDM_THEME_DIR/"
    else
        # Créer les fichiers nécessaires pour le thème custom
        # metadata.desktop
        sudo tee "$CUSTOM_SDDM_THEME_DIR/metadata.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=SDDM Custom
Comment=Thème SDDM personnalisé avec fond vidéo/GIF/images aléatoires
Type=Service
X-KDE-PluginInfo-Author=PapaOursPolaire
X-KDE-PluginInfo-Email=papaoursgamer@gmail.com
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL
EOF
        
        # theme.conf (base)
        sudo tee "$CUSTOM_SDDM_THEME_DIR/theme.conf" >/dev/null <<EOF
[General]
background=
type=custom

[Custom]
UseRandomImages=false
ImageFolderPath=
CustomBackgroundPath=
MediaType=
EOF
        
        # Main.qml (version de base)
        sudo tee "$CUSTOM_SDDM_THEME_DIR/Main.qml" >/dev/null <<EOF
import QtQuick 2.15
import SddmComponents 2.0
import QtMultimedia 5.13

Rectangle {
    id: container
    width: 640
    height: 480

    // Fond d'écran vidéo
    Video {
        id: bgVideo
        anchors.fill: parent
        source: config.CustomBackgroundPath || ""
        autoPlay: true
        loops: MediaPlayer.Infinite
        muted: true
        fillMode: VideoOutput.PreserveAspectCrop
        visible: config.MediaType === "mp4" || config.MediaType === "video"
    }

    // Reste de l'interface utilisateur...
    // ... (le code d'interface utilisateur de base)
}
EOF
        
        # Copier l'image de terminal par défaut si disponible
        if [ -f "$SDDM_THEMES_DIR/fallout3/loginterminalc.png" ]; then
            sudo cp "$SDDM_THEMES_DIR/fallout3/loginterminalc.png" "$CUSTOM_SDDM_THEME_DIR/"
        fi
    fi
    
    # Options de configuration
    echo -e "\nOptions de configuration du thème custom:"
    echo "1. Vidéo (fichier .mp4)"
    echo "2. GIF animé (fichier .gif)"
    echo "3. Images aléatoires (dossier d'images)"
    echo "4. Annuler"
    
    read -p "Choisissez une option [1-4]: " media_choice
    
    case "$media_choice" in
        1)
            configurer_video_sddm
            ;;
        2)
            configurer_gif_sddm
            ;;
        3)
            configurer_images_aleatoires_sddm
            ;;
        4)
            echo "Configuration annulée."
            return 0
            ;;
        *)
            echo "Option invalide."
            return 1
            ;;
    esac
    
    # Activer le thème custom
    activer_theme_sddm "custom" "$CUSTOM_SDDM_THEME_DIR"
}

function configurer_video_sddm() {
    echo -e "\nCONFIGURATION VIDÉO POUR SDDM"
    
    # Sélectionner le fichier vidéo
    video_file=$(selectionner_fichier_interactif "$HOME" "*.mp4" "Sélectionnez un fichier vidéo MP4")
    
    if [ -z "$video_file" ] || [ ! -f "$video_file" ]; then
        echo "Aucun fichier vidéo sélectionné ou fichier invalide."
        return 1
    fi
    
    # Copier la vidéo dans le dossier du thème
    video_name=$(basename "$video_file")
    sudo cp "$video_file" "$CUSTOM_SDDM_THEME_DIR/$video_name"
    
    # Mettre à jour le fichier theme.conf
    sudo tee "$CUSTOM_SDDM_THEME_DIR/theme.conf" >/dev/null <<EOF
[General]
background=$video_name
type=video

[Custom]
UseRandomImages=false
ImageFolderPath=
CustomBackgroundPath=$CUSTOM_SDDM_THEME_DIR/$video_name
MediaType=mp4
EOF
    
    echo "Vidéo configurée: $video_name"
}

function configurer_gif_sddm() {
    echo -e "\nCONFIGURATION GIF POUR SDDM"
    
    # Sélectionner le fichier GIF
    gif_file=$(selectionner_fichier_interactif "$HOME" "*.gif" "Sélectionnez un fichier GIF")
    
    if [ -z "$gif_file" ] || [ ! -f "$gif_file" ]; then
        echo "Aucun fichier GIF sélectionné ou fichier invalide."
        return 1
    fi
    
    # Copier le GIF dans le dossier du thème
    gif_name=$(basename "$gif_file")
    sudo cp "$gif_file" "$CUSTOM_SDDM_THEME_DIR/$gif_name"
    
    # Mettre à jour le fichier theme.conf
    sudo tee "$CUSTOM_SDDM_THEME_DIR/theme.conf" >/dev/null <<EOF
[General]
background=$gif_name
type=gif

[Custom]
UseRandomImages=false
ImageFolderPath=
CustomBackgroundPath=$CUSTOM_SDDM_THEME_DIR/$gif_name
MediaType=gif
EOF
    
    echo "GIF configuré: $gif_name"
}

function configurer_images_aleatoires_sddm() {
    echo -e "\nCONFIGURATION D'IMAGES ALÉATOIRES POUR SDDM"
    
    # Sélectionner le dossier d'images
    images_dir=$(selectionner_dossier_interactif "$HOME" "Sélectionnez un dossier d'images")
    
    if [ -z "$images_dir" ] || [ ! -d "$images_dir" ]; then
        echo "Aucun dossier sélectionné ou dossier invalide."
        return 1
    fi
    
    # Créer un sous-dossier pour les images dans le thème
    sudo mkdir -p "$CUSTOM_SDDM_THEME_DIR/backgrounds"
    
    # Copier les images (formats supportés)
    echo "Copie des images..."
    supported_formats=("*.jpg" "*.jpeg" "*.png" "*.bmp")
    for format in "${supported_formats[@]}"; do
        find "$images_dir" -maxdepth 1 -type f -iname "$format" -exec sudo cp {} "$CUSTOM_SDDM_THEME_DIR/backgrounds/" \;
    done
    
    # Compter le nombre d'images copiées
    image_count=$(find "$CUSTOM_SDDM_THEME_DIR/backgrounds" -maxdepth 1 -type f | wc -l)
    
    if [ "$image_count" -eq 0 ]; then
        echo "Aucune image trouvée dans le dossier sélectionné."
        return 1
    fi
    
    # Mettre à jour le fichier theme.conf
    sudo tee "$CUSTOM_SDDM_THEME_DIR/theme.conf" >/dev/null <<EOF
[General]
background=
type=random

[Custom]
UseRandomImages=true
ImageFolderPath=$CUSTOM_SDDM_THEME_DIR/backgrounds
CustomBackgroundPath=
MediaType=image
ImageCount=$image_count
EOF
    
    echo "$image_count images configurées pour affichage aléatoire."
}

function selectionner_fichier_interactif() {
    local dossier_initial="${1:-$HOME}"
    local types_fichiers="${2:-*}"
    local titre="${3:-Sélectionnez un fichier}"
    
    # Utiliser zenity si disponible (interface graphique)
    if command -v zenity >/dev/null; then
        local fichier_selectionne=$(zenity --file-selection --title="$titre" --filename="$dossier_initial/" --file-filter="$types_fichiers" 2>/dev/null)
        if [ -n "$fichier_selectionne" ] && [ -f "$fichier_selectionne" ]; then
            echo "$fichier_selectionne"
            return 0
        fi
    fi
    
    # Utiliser kdialog pour KDE si disponible
    if command -v kdialog >/dev/null; then
        local fichier_selectionne=$(kdialog --getopenfilename "$dossier_initial" "$types_fichiers" --title "$titre" 2>/dev/null)
        if [ -n "$fichier_selectionne" ] && [ -f "$fichier_selectionne" ]; then
            echo "$fichier_selectionne"
            return 0
        fi
    fi
    
    # Fallback: ouvrir l'explorateur et attendre la saisie
    echo "Ouverture de l'explorateur de fichiers..."
    if command -v dolphin >/dev/null; then
        dolphin "$dossier_initial" >/dev/null 2>&1 &
    elif command -v nautilus >/dev/null; then
        nautilus "$dossier_initial" >/dev/null 2>&1 &
    elif command -v thunar >/dev/null; then
        thunar "$dossier_initial" >/dev/null 2>&1 &
    else
        xdg-open "$dossier_initial" >/dev/null 2>&1 &
    fi
    
    sleep 3
    echo "Naviguez dans l'explorateur et copiez le chemin complet du fichier"
    read -p "Collez le chemin complet ici : " fichier_saisi
    
    if [ -f "$fichier_saisi" ]; then
        echo "$fichier_saisi"
        return 0
    else
        echo ""
        return 1
    fi
}

# Fonction pour sélectionner un dossier
function selectionner_dossier_interactif() {
    local dossier_initial="${1:-$HOME}"
    local titre="${2:-Sélectionnez un dossier}"
    
    # Utiliser zenity si disponible
    if command -v zenity >/dev/null; then
        local dossier_selectionne=$(zenity --file-selection --directory --title="$titre" --filename="$dossier_initial/" 2>/dev/null)
        if [ -n "$dossier_selectionne" ] && [ -d "$dossier_selectionne" ]; then
            echo "$dossier_selectionne"
            return 0
        fi
    fi
    
    # Utiliser kdialog pour KDE si disponible
    if command -v kdialog >/dev/null; then
        local dossier_selectionne=$(kdialog --getexistingdirectory "$dossier_initial" --title "$titre" 2>/dev/null)
        if [ -n "$dossier_selectionne" ] && [ -d "$dossier_selectionne" ]; then
            echo "$dossier_selectionne"
            return 0
        fi
    fi
    
    # Fallback
    echo "Ouverture de l'explorateur de fichiers..."
    if command -v dolphin >/dev/null; then
        dolphin "$dossier_initial" >/dev/null 2>&1 &
    elif command -v nautilus >/dev/null; then
        nautilus "$dossier_initial" >/dev/null 2>&1 &
    elif command -v thunar >/dev/null; then
        thunar "$dossier_initial" >/dev/null 2>&1 &
    else
        xdg-open "$dossier_initial" >/dev/null 2>&1 &
    fi
    
    sleep 3
    echo "Naviguez vers le dossier désiré et copiez son chemin"
    read -p "Collez le chemin complet du dossier ici : " dossier_saisi
    
    if [ -d "$dossier_saisi" ]; then
        echo "$dossier_saisi"
        return 0
    else
        echo ""
        return 1
    fi
}

# Fonction améliorée pour SDDM customisé
function configurer_sddm_customise() {
    echo -e "\nCONFIGURATION DU THEME SDDM CUSTOMISE"
    echo "Ce theme permet d'utiliser vos propres medias comme arriere-plan de connexion"
    echo ""
    echo "Options disponibles:"
    echo "1. Video ou GIF personnalise (fichier unique en boucle)"
    echo "2. Diaporama d'images aleatoires depuis un dossier"
    echo "3. Annuler et revenir au menu"
    echo ""
    read -p "Votre choix [1-3]: " custom_choice

    case "$custom_choice" in
        3|"")
            echo "Configuration annulee"
            return 0
            ;;
    esac

    # Verification des dependances
    if ! command -v zenity >/dev/null && ! command -v kdialog >/dev/null; then
        echo "Installation des outils de selection graphique..."
        if command -v apt >/dev/null; then
            sudo apt install zenity -y >/dev/null 2>&1
        elif command -v pacman >/dev/null; then
            sudo pacman -S zenity --noconfirm >/dev/null 2>&1
        elif command -v dnf >/dev/null; then
            sudo dnf install zenity -y >/dev/null 2>&1
        fi
    fi

    # Creation de la structure du theme custom
    CUSTOM_SDDM_THEME_DIR="$SDDM_DIR/custom"
    echo "Preparation du theme custom SDDM..."
    
    sudo mkdir -p "$CUSTOM_SDDM_THEME_DIR"
    sudo mkdir -p "$CUSTOM_SDDM_THEME_DIR/backgrounds"

    # Verification de l'existence des fichiers source
    if [ ! -d "$REPO_DIR/sddm" ]; then
        echo "Erreur: Dossier sddm non trouve dans le depot"
        echo "Executez d'abord l'option 1 du menu principal pour cloner le depot"
        return 1
    fi

    # Copie des fichiers du theme de base
    for fichier in "Main.qml" "metadata.desktop" "theme.conf" "loginterminalc.png"; do
        if [ -f "$REPO_DIR/sddm/video/$fichier" ]; then
            sudo cp "$REPO_DIR/sddm/video/$fichier" "$CUSTOM_SDDM_THEME_DIR/"
        else
            echo "Attention: Fichier $fichier non trouve dans le depot"
        fi
    done

    if [ "$custom_choice" -eq 1 ]; then
        # Mode video/GIF personnalise
        echo -e "\nSELECTION D'UNE VIDEO OU D'UN GIF"
        echo "Formats supportes: mp4, webm, avi, mkv, mov, gif"
        echo ""
        
        # Determiner le dossier de depart pour la recherche
        local dossier_videos="$HOME"
        for dir in "$HOME/Videos" "$HOME/Videos" "$HOME/Downloads" "$HOME/Telechargements" "$HOME/Desktop" "$HOME/Bureau"; do
            if [ -d "$dir" ]; then
                dossier_videos="$dir"
                break
            fi
        done
        
        echo "Dossier de recherche initial: $dossier_videos"
        echo "Selection du fichier media..."
        
        # Selection interactive du fichier
        local media_path=$(selectionner_fichier_gui \
            "$dossier_videos" \
            "Selectionnez une video ou un GIF pour SDDM" \
            "Videos et GIF|*.mp4 *.webm *.avi *.mkv *.mov *.gif")
        
        if [ -z "$media_path" ]; then
            echo "Aucun fichier selectionne. Configuration annulee."
            return 1
        fi
        
        # Verification du format
        local extension="${media_path##*.}"
        case "${extension,,}" in
            mp4|webm|avi|mkv|mov|gif)
                echo "Format valide detecte: $extension"
                ;;
            *)
                echo "Erreur: Format non supporte '$extension'"
                echo "Utilisez: mp4, webm, avi, mkv, mov, gif"
                return 1
                ;;
        esac
        
        # Verification de la taille du fichier
        local taille_mo=$(du -m "$media_path" | cut -f1)
        if [ "$taille_mo" -gt 100 ]; then
            echo "Attention: Fichier volumineux ($taille_mo Mo)"
            echo "Recommandation: utilisez des fichiers < 50 Mo pour des performances optimales"
            read -p "Continuer quand meme ? [y/N]: " continuer
            if [[ ! "$continuer" =~ ^[Yy]$ ]]; then
                echo "Configuration annulee"
                return 1
            fi
        fi
        
        # Copie du fichier media
        local media_filename=$(basename "$media_path")
        local media_filename_safe=$(echo "$media_filename" | tr ' ' '_' | tr -cd '[:alnum:]._-')
        
        echo "Copie du media: $media_filename"
        if sudo cp "$media_path" "$CUSTOM_SDDM_THEME_DIR/$media_filename_safe"; then
            echo "Media copie avec succes"
        else
            echo "Erreur lors de la copie du fichier"
            return 1
        fi
        
        # Configuration du theme
        sudo tee "$CUSTOM_SDDM_THEME_DIR/theme.conf" >/dev/null <<EOF
[General]
background=$media_filename_safe

[Custom]
CustomBackgroundPath=$CUSTOM_SDDM_THEME_DIR/$media_filename_safe
UseRandomImages=false
ImageFolderPath=$CUSTOM_SDDM_THEME_DIR/backgrounds
MediaType=${extension,,}
EOF
        
        echo "Configuration terminee avec le fichier: $media_filename"
        
    elif [ "$custom_choice" -eq 2 ]; then
        # Mode images aleatoires
        echo -e "\nSELECTION D'UN DOSSIER D'IMAGES"
        echo "Le theme affichera aleatoirement les images de ce dossier"
        echo "Formats supportes: jpg, jpeg, png, bmp, gif"
        echo ""
        
        # Determiner le dossier de depart
        local dossier_images="$HOME"
        for dir in "$HOME/Pictures" "$HOME/Images" "$HOME/Photos" "$HOME/Desktop" "$HOME/Bureau"; do
            if [ -d "$dir" ]; then
                dossier_images="$dir"
                break
            fi
        done
        
        echo "Dossier de recherche initial: $dossier_images"
        echo "Selection du dossier d'images..."
        
        # Selection interactive du dossier
        local images_dir=$(selectionner_dossier_gui \
            "$dossier_images" \
            "Selectionnez le dossier contenant vos images")
        
        if [ -z "$images_dir" ]; then
            echo "Aucun dossier selectionne. Configuration annulee."
            return 1
        fi
        
        # Verification et copie des images
        echo "Analyse du dossier: $images_dir"
        local copied_count=0
        local total_size=0
        
        # Copier les images par format
        for extension in jpg jpeg png bmp gif; do
            for image in "$images_dir"/*."$extension" "$images_dir"/*."${extension^^}"; do
                if [ -f "$image" ]; then
                    local image_name=$(basename "$image")
                    local image_name_safe=$(echo "$image_name" | tr ' ' '_' | tr -cd '[:alnum:]._-')
                    
                    if sudo cp "$image" "$CUSTOM_SDDM_THEME_DIR/backgrounds/$image_name_safe"; then
                        copied_count=$((copied_count + 1))
                        local size=$(du -k "$image" | cut -f1)
                        total_size=$((total_size + size))
                    fi
                fi
            done
        done
        
        if [ $copied_count -eq 0 ]; then
            echo "Erreur: Aucune image trouvee dans le dossier selectionne"
            echo "Formats acceptes: jpg, jpeg, png, bmp, gif"
            return 1
        fi
        
        echo "$copied_count images copiees ($(($total_size / 1024)) Mo au total)"
        
        # Configuration du theme
        sudo tee "$CUSTOM_SDDM_THEME_DIR/theme.conf" >/dev/null <<EOF
[General]
background=

[Custom]
CustomBackgroundPath=
UseRandomImages=true
ImageFolderPath=$CUSTOM_SDDM_THEME_DIR/backgrounds
ImageCount=$copied_count
SourceFolder=$images_dir
EOF
        
        echo "Configuration terminee avec $copied_count images aleatoires"
        
    else
        echo "Option invalide"
        return 1
    fi

    # Configuration finale de SDDM
    echo -e "\nActivation du theme SDDM custom..."
    sudo mkdir -p "$SDDM_CONFIG_DIR"
    
    # Creation du fichier de configuration SDDM
    sudo tee "$SDDM_CONFIG_DIR/bear-theme.conf" >/dev/null <<EOF
[Theme]
Current=custom
CursorTheme=default

[General]
Numlock=on
EOF

    # Verification de l'activation de SDDM
    if systemctl is-enabled sddm >/dev/null 2>&1; then
        echo "SDDM est active comme gestionnaire de connexion"
    else
        echo "Attention: SDDM n'est pas le gestionnaire de connexion actuel"
        read -p "Activer SDDM comme gestionnaire par defaut ? [y/N]: " activer_sddm
        if [[ "$activer_sddm" =~ ^[Yy]$ ]]; then
            sudo systemctl enable sddm
            sudo systemctl set-default graphical.target
            echo "SDDM active. Redemarrage necessaire pour voir les changements."
        fi
    fi

    echo -e "\nCONFIGURATION TERMINEE"
    echo "Theme SDDM custom configure avec succes !"
    echo ""
    echo "Pour voir les changements:"
    echo "1. Redemarrez SDDM: sudo systemctl restart sddm"
    echo "2. Ou redemarrez l'ordinateur"
    echo ""
    echo "Fonctionnalites du theme:"
    if [ "$custom_choice" -eq 1 ]; then
        echo "- Video/GIF personnalise en arriere-plan"
        echo "- Lecture automatique en boucle"
    else
        echo "- Diaporama d'images aleatoires"
        echo "- Changement d'image a chaque connexion"
    fi
    echo "- Interface de connexion moderne et fluide"
    echo "- Compatible avec tous les gestionnaires de fenetres"
}

# Fonction améliorée pour détecter et appliquer les splashscreens KDE
function activer_splashscreen_kde() {
    # Vérifier et installer les dépendances Python pour KDE
    echo "Installation des dépendances Python pour KDE..."
    if command -v apt &>/dev/null; then
        sudo apt install python3-pyqt5 python3-qtpy python3-dbus.mainloop.pyqt5 python3-xml -y
    elif command -v pacman &>/dev/null; then
        sudo pacman -S python-pyqt5 python-qtpy python-dbus-next --noconfirm
    elif command -v dnf &>/dev/null; then
        sudo dnf install python3-qt5 python3-qtpy dbus-python -y
    else
        echo "Impossible d'installer les dépendances automatiquement"
    fi

    if [ ! -d "$REPO_DIR/splashscreens" ]; then
        echo "Dossier splashscreens introuvable. Exécutez d'abord l'option 1."
        return 1
    fi

    # Détecter les thèmes de splashscreen valides (recherche récursive)
    declare -a valid_splashscreens
    declare -a splash_paths
    declare -a splash_files
    local i=1

    echo "Détection des splashscreens KDE disponibles..."
    
    # Parcourir tous les dossiers dans splashscreens/
    for splash_dir in "$REPO_DIR/splashscreens"/*; do
        if [ -d "$splash_dir" ]; then
            local splash_name=$(basename "$splash_dir")
            
            # Recherche récursive des fichiers requis
            local splash_qml=$(find "$splash_dir" -name "Splash.qml" -type f | head -1)
            local metadata_file=$(find "$splash_dir" -name "metadata.desktop" -type f | head -1)
            
            # Recherche de fichiers multimédias (priorité: gif > png > jpg > mp4 > webm)
            local media_file=$(find "$splash_dir" -type f \( \
                -iname "*.gif" -o -iname "*.png" -o -iname "*.jpg" -o \
                -iname "*.jpeg" -o -iname "*.mp4" -o -iname "*.webm" \
            \) | head -1)

            if [ -n "$splash_qml" ]; then
                echo "$i. $splash_name"
                echo "   Splash.qml: $(basename "$splash_qml")"
                
                if [ -n "$media_file" ]; then
                    echo "   Média: $(basename "$media_file")"
                else
                    echo "   Média: Aucun fichier média détecté"
                fi
                
                if [ -n "$metadata_file" ]; then
                    local theme_name=$(grep "^Name=" "$metadata_file" 2>/dev/null | cut -d'=' -f2)
                    if [ -n "$theme_name" ]; then
                        echo "   Nom: $theme_name"
                    fi
                fi
                
                valid_splashscreens[$i]="$splash_name"
                splash_paths[$i]="$splash_dir"
                splash_files[$i]="$media_file"
                ((i++))
                echo ""
            else
                echo "Ignoré: $splash_name (Splash.qml introuvable)"
            fi
        fi
    done

    if [ ${#valid_splashscreens[@]} -eq 0 ]; then
        echo "Aucun splashscreen KDE valide trouvé dans $REPO_DIR/splashscreens"
        echo ""
        echo "Structure attendue pour chaque splashscreen:"
        echo "nom_du_splashscreen/"
        echo "├── Splash.qml (obligatoire, peut être dans un sous-dossier)"
        echo "├── metadata.desktop (optionnel)"
        echo "└── fichier_média.gif (ou .png, .jpg, .mp4, etc., optionnel)"
        echo ""
        return 1
    fi

    read -p "Sélectionnez un splashscreen [1-$((i-1))]: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "Sélection invalide."
        return 1
    fi

    selected_name="${valid_splashscreens[$choice]}"
    selected_path="${splash_paths[$choice]}"
    selected_media="${splash_files[$choice]}"
    
    echo "Application de $selected_name..."
    
    # Identifier la version de KDE
    if [ -n "$KDE_SESSION_VERSION" ] || [ "$DESKTOP_SESSION" = "plasma" ] || pgrep -x "plasmashell" >/dev/null 2>&1; then
        # Nom du thème fixe et simple
        THEME_NAME="bearsplash"
        THEME_DIR="$HOME/.local/share/plasma/look-and-feel/$THEME_NAME"
        
        # Supprimer l'ancien thème s'il existe
        rm -rf "$THEME_DIR"
        
        # Copier entièrement le thème sélectionné
        echo "Copie du thème complet..."
        cp -r "$selected_path" "$THEME_DIR"
        
        # Vérifier et ajuster le fichier metadata.desktop
        local metadata_file=$(find "$THEME_DIR" -name "metadata.desktop" -type f | head -1)
        if [ -n "$metadata_file" ]; then
            # Modifier l'identifiant du plugin pour éviter les conflits
            sed -i "s/X-KDE-PluginInfo-Name=.*/X-KDE-PluginInfo-Name=bearsplash/" "$metadata_file"
        else
            # Créer le fichier metadata.desktop s'il n'existe pas
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
        fi

        # Vérifier que le fichier Splash.qml est présent
        local splash_qml=$(find "$THEME_DIR" -name "Splash.qml" -type f | head -1)
        if [ -z "$splash_qml" ]; then
            echo "Erreur: Splash.qml manquant après copie"
            return 1
        fi

        # Détection du type de média principal pour optimisation
        if [ -n "$selected_media" ]; then
            media_ext="${selected_media##*.}"
            echo "Type de média détecté: $media_ext"
        fi

        # Application automatique du thème
        echo "Application automatique du thème..."
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

        echo "Splashscreen '$selected_name' installé et activé automatiquement!"
        if [ -n "$selected_media" ]; then
            echo "Fichier média principal: $(basename "$selected_media")"
        fi
        echo "Déconnectez-vous et reconnectez-vous pour voir le splashscreen au démarrage"
        
    else
        echo "KDE Plasma n'est pas détecté"
        return 1
    fi
}

# Fonction helper pour valider la structure d'un splashscreen
function valider_structure_splashscreen() {
    local splash_dir="$1"
    local splash_name=$(basename "$splash_dir")
    
    echo "Validation de la structure pour: $splash_name"
    
    # Vérifications obligatoires
    if [ ! -d "$splash_dir/contents" ]; then
        echo "Dossier contents/ manquant"
        return 1
    fi
    
    if [ ! -f "$splash_dir/contents/Splash.qml" ]; then
        echo "Fichier Splash.qml manquant dans contents/"
        return 1
    fi
    
    # Vérifier la présence de fichiers multimédias
    local media_count=$(find "$splash_dir/contents" -maxdepth 1 -type f \( \
        -iname "*.gif" -o -iname "*.png" -o -iname "*.jpg" -o \
        -iname "*.jpeg" -o -iname "*.mp4" -o -iname "*.webm" \
    \) | wc -l)
    
    if [ $media_count -eq 0 ]; then
        echo "Aucun fichier média trouvé (recommandé: .gif, .png, .jpg, .mp4)"
    else
        echo "$media_count fichier(s) média trouvé(s)"
    fi
    
    # Vérifications optionnelles
    if [ -f "$splash_dir/metadata.desktop" ]; then
        echo "metadata.desktop présent"
    else
        echo "ℹmetadata.desktop absent (sera créé automatiquement)"
    fi
    
    echo "Structure valide pour $splash_name"
    return 0
}

function ajuster_delai_grub() {
    current_timeout=$(grep "GRUB_TIMEOUT=" "$GRUB_FILE" | cut -d'=' -f2)
    echo -e "\n Délai actuel pour la sélection automatique : ${current_timeout:-15} secondes"
    read -p "Nouveau délai (en secondes, 0 pour désactiver) : " new_timeout

    if ! [[ "$new_timeout" =~ ^[0-9]+$ ]]; then
        echo "Valeur invalide. Doit être un nombre entier."
        return 1
    fi

    sudo sed -i '/^GRUB_TIMEOUT=/d' "$GRUB_FILE"
    echo "GRUB_TIMEOUT=$new_timeout" | sudo tee -a "$GRUB_FILE"
    sudo update-grub

    echo "Délai mis à jour : $new_timeout secondes"
    echo "Le système appliquera les changements au prochain démarrage."
}

# Fond d'écran animé KDE Plasma avec support vidéo et mpvpaper
function video_wallpaper() {
    echo -e "\nFOND D'ÉCRAN ANIMÉ POUR KDE PLASMA"
    echo "Options disponibles:"
    echo "1. Vidéo native (KDE Plasma - expérimental)"
    echo "2. MPVPaper (méthode externe plus stable)"
    
    read -p "Votre choix [1-2]: " method_choice
    
    case "$method_choice" in
        1)
            # Méthode native KDE Plasma
            echo -e "\nMÉTHODE NATIVE KDE PLASMA"
            
            # Vérifier que KDE Plasma est bien détecté
            if ! pgrep -x "plasmashell" >/dev/null; then
                echo "KDE Plasma n'est pas détecté comme environnement actuel"
                return 1
            fi
            
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
            
            echo "Dossiers vidéos détectés:"
            echo "   $VIDEOS_DIR"
            
            # Méthode 1: Lister les vidéos disponibles directement
            echo -e "\nRecherche de vidéos dans les dossiers courants..."
            declare -a video_files
            
            # Recherche de vidéos
            while IFS= read -r -d $'\0' file; do
                video_files+=("$file")
            done < <(find "${VIDEOS_DIRS[@]}" "$HOME/Downloads" "$HOME/Téléchargements" "$HOME/Desktop" "$HOME/Bureau" 2>/dev/null -maxdepth 2 -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.flv" \) -print0 2>/dev/null | head -20)
            
            if [ ${#video_files[@]} -gt 0 ]; then
                echo -e "\n VIDÉOS DÉTECTÉES :"
                for i in "${!video_files[@]}"; do
                    echo "$((i+1)). $(basename "${video_files[$i]}")"
                    echo " ${video_files[$i]}"
                done
                echo "$((${#video_files[@]}+1)). Saisir un chemin manuellement"
                
                read -p "Choisissez une vidéo [1-$((${#video_files[@]}+1))]: " choice
                
                if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#video_files[@]})); then
                    video_path="${video_files[$((choice-1))]}"
                elif [ "$choice" = "$((${#video_files[@]}+1))" ]; then
                    # Ouvrir l'explorateur en arrière-plan (sans attendre)
                    echo "Ouverture de l'explorateur..."
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
                    echo "Saisissez le chemin complet du fichier vidéo :"
                    read -p "Chemin vers la vidéo : " video_path
                else
                    echo "Choix invalide"
                    return 1
                fi
            else
                echo "Aucune vidéo détectée automatiquement"
                echo "Ouverture de l'explorateur pour sélection manuelle..."
                
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
                echo "Saisissez le chemin complet du fichier vidéo :"
                read -p "Chemin vers la vidéo : " video_path
            fi
            
            # Vérifier que le fichier existe et est une vidéo
            if [ ! -f "$video_path" ]; then
                echo "Fichier non trouvé : $video_path"
                return 1
            fi
            
            # Vérifier l'extension
            case "${video_path,,}" in
                *.mp4|*.webm|*.mkv|*.avi|*.mov|*.flv)
                    echo "Format vidéo supporté détecté"
                    ;;
                *)
                    echo "Format non supporté. Utilisez : mp4, webm, mkv, avi, mov, flv"
                    return 1
                    ;;
            esac
            
            local video_name=$(basename "$video_path")
            
            echo -e "\n Création du fond d'écran vidéo pour '$video_name'..."

            # Installer les dépendances nécessaires
            echo "Vérification des dépendances multimédia..."
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

            # Reconstruire le cache de KDE
            echo "Reconstruction du cache KDE..."
            kbuildsycoca5 --noincremental >/dev/null 2>&1

            # Configuration du fond d'écran
            echo "Tentative d'application automatique..."
            
            # Méthode 2: Configuration directe via dbus
            if command -v qdbus >/dev/null 2>&1; then
                echo "Configuration via DBus..."
                qdbus org.kde.plasmashell /PlasmaShell evaluateScript "
                    var allDesktops = desktops();
                    for (i = 0; i < allDesktops.length; i++) {
                        d = allDesktops[i];
                        d.wallpaperPlugin = 'bear_video';
                        d.currentConfigGroup = Array('Wallpaper', 'bear_video', 'General');
                    }
                " 2>/dev/null || echo "Configuration DBus échouée"
            fi
            
            # Redémarrer plasmashell pour appliquer les changements
            echo "Redémarrage de Plasmashell..."
            killall plasmashell 2>/dev/null
            sleep 3
            kstart plasmashell >/dev/null 2>&1 &
            
            echo -e "\nFOND D'ÉCRAN VIDÉO CONFIGURÉ !"
            echo "Vidéo: $video_name"
            echo ""
            echo "Si le fond d'écran ne s'applique pas automatiquement :"
            echo "1. Clic droit sur le bureau → 'Configurer le bureau et le fond d'écran'"
            echo "2. Type de fond d'écran → 'Bear Video Wallpaper'"
            echo "3. Appliquer"
            echo ""
            echo "Le fond d'écran vidéo sera visible dans 5-10 secondes..."
            echo "Clic sur le fond d'écran pour mettre en pause/reprendre"
            ;;
        
        2)
            # Méthode MPVPaper
            echo -e "\nMÉTHODE MPVPAPER (EXTERNE)"
            
            # Vérifier l'installation de mpvpaper
            if ! command -v mpvpaper >/dev/null; then
                echo "Installation de mpvpaper..."
                if command -v apt >/dev/null; then
                    sudo apt install mpv libmpv-dev cmake build-essential -y
                    git clone https://github.com/GhostNaN/mpvpaper.git /tmp/mpvpaper
                    cd /tmp/mpvpaper
                    mkdir build && cd build
                    cmake ..
                    make
                    sudo make install
                elif command -v pacman >/dev/null; then
                    sudo pacman -S mpvpaper --noconfirm
                elif command -v dnf >/dev/null; then
                    sudo dnf install mpvpaper -y
                else
                    echo "mpvpaper n'est pas disponible pour votre distribution"
                    echo "Veuillez l'installer manuellement"
                    return 1
                fi
            fi
            
            # Sélection de la vidéo
            vid=$(selectionner_fichier_interactif "$HOME/Videos" "*.mp4 *.mkv" "Choisissez une vidéo")
            [ -z "$vid" ] && return
            
            # Arrêter les instances précédentes
            pkill mpvpaper 2>/dev/null
            
            # Démarrer mpvpaper
            echo "Lancement de mpvpaper..."
            nohup mpvpaper -o "no-audio loop" "*" "$vid" >/dev/null 2>&1 &
            
            echo "Vidéo appliquée en fond d'écran avec mpvpaper."
            echo "Note: mpvpaper est une méthode externe plus stable pour les wallpapers vidéo"
            ;;
        
        *)
            echo "Option invalide"
            return 1
            ;;
    esac
}

# Thèmes d'icônes système complets (dossier icons-themes du repo)
function appliquer_icons_sys() {
    echo -e "\nTHÈMES D'ICÔNES SYSTÈME COMPLETS"
    
    # Vérifier que le dossier icons-themes existe
    ICONS_THEMES_DIR="$REPO_DIR/icons-themes"
    if [ ! -d "$ICONS_THEMES_DIR" ]; then
        echo "Dossier icons-themes introuvable dans le dépôt"
        echo "Vérifiez que le dépôt contient bien le dossier icons-themes"
        return 1
    fi
    
    echo "Thèmes d'icônes disponibles :"
    local i=1
    declare -a ICON_THEMES_KEYS
    declare -a ICON_THEMES_PATHS
    
    # Parcourir tous les fichiers d'archive dans icons-themes
    while IFS= read -r -d $'\0' archive; do
        filename=$(basename "$archive")
        themename="${filename%.*}"  # Retirer l'extension
        themename="${themename%.tar}"  # Retirer .tar supplémentaire si présent
        
        echo "$i. $themename"
        ICON_THEMES_KEYS[$i]="$themename"
        ICON_THEMES_PATHS[$i]="$archive"
        ((i++))
    done < <(find "$ICONS_THEMES_DIR" -maxdepth 1 -type f \( \
        -iname "*.tar.xz" -o \
        -iname "*.tar.gz" -o \
        -iname "*.tgz" -o \
        -iname "*.tar.bz2" -o \
        -iname "*.tbz" -o \
        -iname "*.zip" -o \
        -iname "*.7z" \
    \) -print0)
    
    if [ $i -eq 1 ]; then
        echo "Aucun thème d'icônes trouvé dans $ICONS_THEMES_DIR"
        echo "Formats supportés: .tar.xz, .tar.gz, .tgz, .tar.bz2, .tbz, .zip, .7z"
        return 1
    fi
    
    read -p "Choisissez un thème d'icônes [1-$((i-1))]: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
        echo "Choix invalide."
        return 1
    fi
    
    selected_theme="${ICON_THEMES_KEYS[$choice]}"
    selected_archive="${ICON_THEMES_PATHS[$choice]}"
    archive_ext="${selected_archive##*.}"
    
    echo "Installation du thème $selected_theme..."
    
    # Dossier de destination pour les icônes système
    ICONS_DEST_DIR="$HOME/.local/share/icons"
    sudo_ICONS_DEST_DIR="/usr/share/icons"
    
    # Créer le dossier de destination
    mkdir -p "$ICONS_DEST_DIR"
    
    # Extraire l'archive selon son format
    echo "Extraction de l'archive..."
    case "$archive_ext" in
        xz|gz|bz2|tgz|tbz)
            # Archives tar avec différentes compressions
            tar_flags=""
            case "$archive_ext" in
                xz) tar_flags="J" ;;
                gz|tgz) tar_flags="z" ;;
                bz2|tbz) tar_flags="j" ;;
            esac
            tar -x${tar_flags}f "$selected_archive" -C "$ICONS_DEST_DIR"
            ;;
        zip)
            unzip -q "$selected_archive" -d "$ICONS_DEST_DIR"
            ;;
        7z)
            if command -v 7z >/dev/null; then
                7z x "$selected_archive" -o"$ICONS_DEST_DIR" -y
            else
                echo "7z n'est pas installé. Installation..."
                sudo apt install p7zip-full -y || sudo pacman -S p7zip --noconfirm || sudo dnf install p7zip -y
                7z x "$selected_archive" -o"$ICONS_DEST_DIR" -y
            fi
            ;;
        *)
            echo "Format non supporté: $archive_ext"
            return 1
            ;;
    esac
    
    # Trouver le dossier extrait (peut avoir un nom différent)
    extracted_dir=""
    for dir in "$ICONS_DEST_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/index.theme" ]; then
            extracted_dir="$dir"
            theme_name=$(basename "$dir")
            break
        fi
    done
    
    if [ -z "$extracted_dir" ]; then
        echo "Impossible de trouver le dossier du thème après extraction"
        echo "Contenu extrait:"
        ls -la "$ICONS_DEST_DIR"
        return 1
    fi
    
    echo "Thème extrait: $theme_name"
    
    # Application automatique selon l'environnement de bureau
    echo "Application du thème d'icônes..."
    
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        # KDE Plasma
        kwriteconfig5 --file kdeglobals --group Icons --key Theme "$theme_name"
        echo "Thème d'icônes appliqué pour KDE Plasma: $theme_name"
        
    elif pgrep -x "gnome-shell" >/dev/null 2>&1; then
        # GNOME
        gsettings set org.gnome.desktop.interface icon-theme "$theme_name"
        echo "Thème d'icônes appliqué pour GNOME: $theme_name"
        
    elif pgrep -x "xfce4-panel" >/dev/null 2>&1; then
        # XFCE
        xfconf-query -c xsettings -p /Net/IconThemeName -s "$theme_name"
        echo "Thème d'icônes appliqué pour XFCE: $theme_name"
        
    else
        echo "Environnement de bureau non reconnu"
        echo "Thème installé dans : $extracted_dir"
        echo "Sélectionnez-le manuellement dans les paramètres de votre bureau"
    fi
    
    # Actualiser le cache d'icônes
    echo "Actualisation du cache d'icônes..."
    gtk-update-icon-cache -f -t "$extracted_dir" 2>/dev/null || true
    
    # Forcer le rechargement dans KDE
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        kquitapp5 plasmashell && kstart plasmashell &
    fi
    
    echo "Thème d'icônes '$theme_name' installé avec succès!"
    echo "Les changements seront visibles après redémarrage de la session"
}

function maj_system() {
    echo -e "\nMISE À JOUR COMPLÈTE DU SYSTÈME"
    echo "Cette opération peut prendre du temps selon votre connexion..."
    
    # Détecter la distribution et utiliser le gestionnaire de paquets approprié
    if command -v apt >/dev/null; then
        echo "Distribution basée sur Debian/Ubuntu détectée"
        echo "Mise à jour de la liste des paquets..."
        sudo apt update
        
        echo "Mise à jour des paquets installés..."
        sudo apt upgrade -y
        
        echo "Mise à jour de la distribution..."
        sudo apt dist-upgrade -y
        
        echo "Nettoyage des paquets obsolètes..."
        sudo apt autoremove -y
        sudo apt autoclean
        
        # Mise à jour des snaps si disponible
        if command -v snap >/dev/null; then
            echo "Mise à jour des paquets Snap..."
            sudo snap refresh
        fi
        
    elif command -v pacman >/dev/null; then
        echo "Distribution basée sur Arch Linux détectée"
        echo "Mise à jour complète du système..."
        sudo pacman -Syu --noconfirm
        
        echo "Nettoyage du cache..."
        sudo pacman -Sc --noconfirm
        
        # AUR helper si disponible
        if command -v yay >/dev/null; then
            echo "Mise à jour des paquets AUR avec yay..."
            yay -Syu --noconfirm
        elif command -v paru >/dev/null; then
            echo "Mise à jour des paquets AUR avec paru..."
            paru -Syu --noconfirm
        fi
        
    elif command -v dnf >/dev/null; then
        echo "Distribution basée sur Red Hat/Fedora détectée"
        echo "Mise à jour du système..."
        sudo dnf upgrade -y
        
        echo "Nettoyage..."
        sudo dnf autoremove -y
        sudo dnf clean all
        
    elif command -v zypper >/dev/null; then
        echo "Distribution basée sur openSUSE détectée"
        echo "Mise à jour du système..."
        sudo zypper update -y
        
        echo "Mise à jour de la distribution..."
        sudo zypper dup -y
        
    else
        echo "Gestionnaire de paquets non supporté"
        echo "Systèmes supportés : Debian/Ubuntu, Arch Linux, Red Hat/Fedora, openSUSE"
        return 1
    fi
    
    # Mise à jour des paquets Flatpak si disponible
    if command -v flatpak >/dev/null; then
        echo "Mise à jour des applications Flatpak..."
        flatpak update -y 2>/dev/null || true
    fi
    
    # Mise à jour d'AppImage via AppImageUpdate si disponible
    if command -v appimageupdate >/dev/null; then
        echo "Recherche des AppImages à mettre à jour..."
        find "$HOME" -name "*.AppImage" -executable 2>/dev/null | while read appimage; do
            echo "Mise à jour de $(basename "$appimage")..."
            appimageupdate "$appimage" 2>/dev/null || true
        done
    fi
    
    echo -e "\nnnMISE À JOUR SYSTÈME TERMINÉE"
    echo "Il est recommandé de redémarrer le système pour appliquer tous les changements"
    read -p "Redémarrer maintenant ? [y/N]: " restart_choice
    if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
        echo "Redémarrage dans 5 secondes..."
        sleep 5
        sudo reboot
    fi
}

# Fonction pour installer Fastfetch si nécessaire
function installer_fastfetch() {
    if command -v fastfetch >/dev/null; then
        echo "Fastfetch est déjà installé"
        return 0
    fi
    
    echo "Installation de Fastfetch..."
    if command -v apt >/dev/null; then
        # Pour Ubuntu/Debian récents
        sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y 2>/dev/null || {
            # Installation manuelle si le PPA n'est pas disponible
            wget -O /tmp/fastfetch.deb https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb
            sudo dpkg -i /tmp/fastfetch.deb
            sudo apt -f install -y
        }
        sudo apt update && sudo apt install fastfetch -y
        
    elif command -v pacman >/dev/null; then
        sudo pacman -S fastfetch --noconfirm
        
    elif command -v dnf >/dev/null; then
        sudo dnf install fastfetch -y
        
    elif command -v zypper >/dev/null; then
        sudo zypper install fastfetch -y
        
    else
        echo "Installation manuelle depuis GitHub..."
        wget -O /tmp/fastfetch.tar.gz https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.tar.gz
        tar -xzf /tmp/fastfetch.tar.gz -C /tmp/
        sudo cp /tmp/fastfetch-*/usr/bin/fastfetch /usr/local/bin/
        sudo chmod +x /usr/local/bin/fastfetch
    fi
    
    if command -v fastfetch >/dev/null; then
        echo "Fastfetch installé avec succès"
    else
        echo "Échec de l'installation de Fastfetch"
        return 1
    fi
}

# Fonction de conversion d'image pour Fastfetch
function convertir_image_fastfetch() {
    local image_path="$1"
    local output_path="$2"
    local max_width="${3:-60}"
    local max_height="${4:-30}"
    
    if ! command -v convert >/dev/null; then
        echo "Installation d'ImageMagick pour la conversion..."
        if command -v apt >/dev/null; then
            sudo apt install imagemagick -y
        elif command -v pacman >/dev/null; then
            sudo pacman -S imagemagick --noconfirm
        elif command -v dnf >/dev/null; then
            sudo dnf install ImageMagick -y
        fi
    fi
    
    # Conversion et redimensionnement pour Fastfetch
    convert "$image_path" \
        -resize "${max_width}x${max_height}>" \
        -colors 256 \
        "$output_path" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "Image convertie: $(basename "$output_path")"
        return 0
    else
        echo "Erreur lors de la conversion de l'image"
        return 1
    fi
}

# Fonction unifiée de customisation Fastfetch
function fastfetch() {
    echo -e "\nCUSTOMISATION COMPLÈTE DE FASTFETCH"
    
    # Installer Fastfetch si nécessaire
    installer_fastfetch || return 1
    
    # Créer les dossiers nécessaires
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    mkdir -p "$FASTFETCH_LOGOS_DIR"
    mkdir -p "$FASTFETCH_IMAGES_DIR"
    
    while true; do
        echo -e "\n=== MENU CUSTOMISATION FASTFETCH ==="
        echo "1.  Logo fixe personnalisé (image)"
        echo "2.  Logo aléatoire à chaque lancement"
        echo "3.  Logo d'un autre OS (distro)"
        echo "4.  Pokémon aléatoire à chaque lancement"
        echo "5.  Image convertie en ASCII art"
        echo "6.  ASCII art personnalisé"
        echo "7.  Ajouter une nouvelle image/logo"
        echo "8.  Gérer les modules (ajouter/supprimer)"
        echo "9.  Activer couleurs aléatoires pour le logo"
        echo "10. Aperçu de la configuration actuelle"
        echo "11. Appliquer la configuration"
        echo "12. Restaurer la configuration par défaut"
        echo "13. Tester la configuration actuelle"
        echo "0.  Retour au menu principal"
        
        read -p "Votre choix [0-13]: " fastfetch_choice
        
        case "$fastfetch_choice" in
            1) configurer_logo_fixe_fastfetch ;;
            2) configurer_logo_aleatoire_fastfetch ;;
            3) choisir_logo_os ;;
            4) configurer_pokemon_aleatoire ;;
            5) convertir_image_ascii ;;
            6) saisir_ascii_personnalise ;;
            7) ajouter_image_fastfetch ;;
            8) gerer_modules_fastfetch ;;
            9) activer_couleurs_aleatoires ;;
            10) afficher_configuration_actuelle ;;
            11) appliquer_configuration_fastfetch ;;
            12) restaurer_config_fastfetch ;;
            13) 
                echo -e "\nTEST DE LA CONFIGURATION ACTUELLE:"
                fastfetch --config "$FASTFETCH_CONFIG_DIR/config.jsonc" 2>/dev/null || fastfetch
                ;;
            0) break ;;
            *) echo "Option invalide." ;;
        esac
    done
    
    # Créer un alias pratique
    echo -e "\nPour utiliser facilement votre configuration:"
    echo "Ajoutez cette ligne à votre ~/.bashrc ou ~/.zshrc:"
    echo "alias ff='fastfetch --config \"$FASTFETCH_CONFIG_DIR/config.jsonc\"'"
    echo ""
    read -p "Voulez-vous ajouter cet alias maintenant? [y/N]: " add_alias
    if [[ "$add_alias" =~ ^[Yy]$ ]]; then
        if [ -n "$ZSH_VERSION" ]; then
            echo "alias ff='fastfetch --config \"$FASTFETCH_CONFIG_DIR/config.jsonc\"'" >> "$HOME/.zshrc"
            echo "Alias ajouté à ~/.zshrc"
        else
            echo "alias ff='fastfetch --config \"$FASTFETCH_CONFIG_DIR/config.jsonc\"'" >> "$HOME/.bashrc"
            echo "Alias ajouté à ~/.bashrc"
        fi
    fi
}

# Configuration logo fixe
function configurer_logo_fixe_fastfetch() {
    echo -e "\nCONFIGURATION LOGO FIXE FASTFETCH"
    
    # Lister les images disponibles
    declare -a available_images
    local i=1
    
    echo "Images disponibles :"
    
    # Images du repo
    if [ -d "$FASTFETCH_IMAGES_DIR" ]; then
        for img in "$FASTFETCH_IMAGES_DIR"/*.{png,jpg,jpeg,gif,bmp,svg}; do
            if [ -f "$img" ]; then
                echo "$i. $(basename "$img") (repo)"
                available_images[$i]="$img"
                ((i++))
            fi
        done
    fi
    
    # Images déjà converties
    for img in "$FASTFETCH_LOGOS_DIR"/*.{png,jpg,jpeg}; do
        if [ -f "$img" ]; then
            echo "$i. $(basename "$img") (converti)"
            available_images[$i]="$img"
            ((i++))
        fi
    done
    
    echo "$i. Parcourir pour sélectionner un fichier"
    
    if [ $i -eq 1 ]; then
        echo "Aucune image trouvée. Utilisez l'option 3 pour ajouter des images."
        return 1
    fi
    
    read -p "Choisissez une image [1-$i]: " img_choice
    
    local selected_image=""
    
    if [[ "$img_choice" =~ ^[0-9]+$ ]] && ((img_choice >= 1 && img_choice < i)); then
        selected_image="${available_images[$img_choice]}"
    elif [ "$img_choice" = "$i" ]; then
        # Ouvrir l'explorateur de fichiers
        echo "Ouverture de l'explorateur..."
        if command -v dolphin >/dev/null; then
            dolphin "$HOME" >/dev/null 2>&1 &
        elif command -v nautilus >/dev/null; then
            nautilus "$HOME" >/dev/null 2>&1 &
        else
            xdg-open "$HOME" >/dev/null 2>&1 &
        fi
        
        sleep 2
        read -p "Chemin complet vers l'image : " selected_image
    else
        echo "Choix invalide"
        return 1
    fi
    
    if [ ! -f "$selected_image" ]; then
        echo "Fichier non trouvé : $selected_image"
        return 1
    fi
    
    # Convertir l'image pour Fastfetch
    local logo_name="logo_$(date +%s).png"
    local converted_path="$FASTFETCH_LOGOS_DIR/$logo_name"
    
    echo "Conversion de l'image pour Fastfetch..."
    convertir_image_fastfetch "$selected_image" "$converted_path" 60 30
    
    # Créer la configuration Fastfetch
    cat > "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
{
    "logo": {
        "source": "$converted_path",
        "width": 60,
        "height": 30,
        "padding": {
            "top": 1,
            "left": 2
        }
    },
    "display": {
        "color": {
            "keys": "blue",
            "title": "yellow"
        }
    },
    "modules": [
        "title",
        "separator",
        "os",
        "host",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "display",
        "de",
        "wm",
        "wmtheme",
        "theme",
        "icons",
        "font",
        "cursor",
        "terminal",
        "terminalfont",
        "cpu",
        "gpu",
        "memory",
        "disk",
        "localip",
        "battery",
        "locale",
        "break",
        "colors"
    ]
}
EOF
    
    echo "Configuration Fastfetch créée avec logo fixe: $(basename "$selected_image")"
    echo "Testez avec la commande : fastfetch"
}

# Configuration logo aléatoire
function configurer_logo_aleatoire_fastfetch() {
    echo -e "\nCONFIGURATION LOGO ALÉATOIRE FASTFETCH"
    
    # Vérifier qu'il y a des images disponibles
    local img_count=$(find "$FASTFETCH_IMAGES_DIR" "$FASTFETCH_LOGOS_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) 2>/dev/null | wc -l)
    
    if [ "$img_count" -eq 0 ]; then
        echo "Aucune image disponible. Ajoutez des images avec l'option 3."
        return 1
    fi
    
    # Créer le script de sélection aléatoire
    cat > "$FASTFETCH_CONFIG_DIR/random_logo.sh" <<'EOF'
#!/bin/bash

# Dossiers contenant les logos
LOGOS_DIRS=("$HOME/.config/fastfetch/logos" "$HOME/.grub-themes/BearGrubChanger/fastfetch/images")
CONFIG_FILE="$HOME/.config/fastfetch/config.jsonc"

# Trouver tous les logos disponibles
declare -a logos
for dir in "${LOGOS_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        while IFS= read -r -d $'\0' logo; do
            logos+=("$logo")
        done < <(find "$dir" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0 2>/dev/null)
    fi
done

if [ ${#logos[@]} -eq 0 ]; then
    echo "Aucun logo trouvé"
    exit 1
fi

# Sélectionner un logo aléatoire
random_logo="${logos[$RANDOM % ${#logos[@]}]}"

# Créer la configuration avec le logo aléatoire
cat > "$CONFIG_FILE" <<FASTFETCH_CONFIG
{
    "logo": {
        "source": "$random_logo",
        "width": 60,
        "height": 30,
        "padding": {
            "top": 1,
            "left": 2
        }
    },
    "display": {
        "color": {
            "keys": "blue",
            "title": "yellow"
        }
    },
    "modules": [
        "title",
        "separator",
        "os",
        "host",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "display",
        "de",
        "wm",
        "wmtheme",
        "theme",
        "icons",
        "font",
        "cursor",
        "terminal",
        "terminalfont",
        "cpu",
        "gpu",
        "memory",
        "disk",
        "localip",
        "battery",
        "locale",
        "break",
        "colors"
    ]
}
FASTFETCH_CONFIG
EOF
    
    chmod +x "$FASTFETCH_CONFIG_DIR/random_logo.sh"
    
    # Créer un alias pour fastfetch avec logo aléatoire
    cat > "$FASTFETCH_CONFIG_DIR/fastfetch_random.sh" <<EOF
#!/bin/bash
"$FASTFETCH_CONFIG_DIR/random_logo.sh" && fastfetch
EOF
    
    chmod +x "$FASTFETCH_CONFIG_DIR/fastfetch_random.sh"
    
    # Ajouter l'alias au .bashrc ou .zshrc
    local shell_rc=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi
    
    # Retirer l'ancien alias s'il existe
    sed -i '/alias fastfetch-random/d' "$shell_rc" 2>/dev/null
    
    # Ajouter le nouveau alias
    echo "alias fastfetch-random='$FASTFETCH_CONFIG_DIR/fastfetch_random.sh'" >> "$shell_rc"
    
    echo "Configuration logo aléatoire créée !"
    echo "Utilisez 'fastfetch-random' pour un logo différent à chaque fois"
    echo "Ou rechargez votre terminal et utilisez l'alias après : source $shell_rc"
    
    # Test immédiat
    "$FASTFETCH_CONFIG_DIR/fastfetch_random.sh"
}

# Ajouter une nouvelle image
function ajouter_image_fastfetch() {
    echo -e "\nAJOUT D'IMAGE POUR FASTFETCH"
    echo "Fastfetch peut afficher des logos personnalises lors de l'affichage des informations systeme"
    echo ""
    
    # Verification de l'installation de Fastfetch
    if ! command -v fastfetch >/dev/null; then
        echo "Fastfetch n'est pas installe."
        read -p "Installer Fastfetch maintenant ? [y/N]: " installer_ff
        if [[ "$installer_ff" =~ ^[Yy]$ ]]; then
            installer_fastfetch || return 1
        else
            echo "Installation annulee"
            return 1
        fi
    fi
    
    # Creation des dossiers necessaires
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    mkdir -p "$FASTFETCH_LOGOS_DIR"
    mkdir -p "$FASTFETCH_IMAGES_DIR"
    
    echo "Methodes d'ajout d'image:"
    echo "1. Selection graphique via explorateur de fichiers"
    echo "2. Telechargement depuis une URL"
    echo "3. Parcourir les images detectees automatiquement"
    echo "4. Copier depuis le presse-papiers (chemin d'image)"
    echo "5. Annuler"
    echo ""
    read -p "Choisissez une methode [1-5]: " add_method

    local source_image=""
    local method_name=""
    
    case "$add_method" in
        1)
            # Selection graphique interactive
            method_name="Selection graphique"
            echo -e "\nSELECTION GRAPHIQUE D'IMAGE"
            
            # Verification des outils de dialogue
            if ! command -v zenity >/dev/null && ! command -v kdialog >/dev/null; then
                echo "Installation des outils de selection graphique..."
                if command -v apt >/dev/null; then
                    sudo apt install zenity -y >/dev/null 2>&1
                elif command -v pacman >/dev/null; then
                    sudo pacman -S zenity --noconfirm >/dev/null 2>&1
                fi
            fi
            
            # Determiner le dossier de depart
            local dossier_images="$HOME"
            for dir in "$HOME/Pictures" "$HOME/Images" "$HOME/Photos" "$HOME/Desktop" "$HOME/Bureau" "$HOME/Downloads" "$HOME/Telechargements"; do
                if [ -d "$dir" ]; then
                    dossier_images="$dir"
                    break
                fi
            done
            
            echo "Dossier de recherche initial: $dossier_images"
            echo "Ouverture du selecteur de fichiers..."
            
            source_image=$(selectionner_fichier_gui \
                "$dossier_images" \
                "Selectionnez une image pour Fastfetch" \
                "Images|*.png *.jpg *.jpeg *.gif *.bmp *.svg *.webp *.ico")
            ;;
            
        2)
            # Telechargement depuis URL
            method_name="Telechargement URL"
            echo -e "\nTELECHARGEMENT DEPUIS URL"
            echo "Entrez l'URL d'une image (formats: png, jpg, jpeg, gif, bmp, svg, webp)"
            echo "Exemple: https://example.com/logo.png"
            echo ""
            read -p "URL de l'image: " image_url
            
            if [[ ! "$image_url" =~ ^https?:// ]]; then
                echo "Erreur: URL invalide (doit commencer par http:// ou https://)"
                return 1
            fi
            
            # Extraction du nom de fichier et nettoyage
            local filename=$(basename "$image_url" | sed 's/[^a-zA-Z0-9._-]/_/g')
            if [ -z "$filename" ] || [[ "$filename" == *"_"* ]]; then
                filename="fastfetch_image_$(date +%s).png"
            fi
            
            source_image="/tmp/fastfetch_dl_$filename"
            echo "Telechargement en cours..."
            
            if command -v wget >/dev/null; then
                if wget -q --timeout=10 --tries=2 -O "$source_image" "$image_url"; then
                    echo "Telechargement reussi via wget"
                else
                    echo "Echec du telechargement avec wget"
                    return 1
                fi
            elif command -v curl >/dev/null; then
                if curl -s --max-time 10 --retry 2 -o "$source_image" "$image_url"; then
                    echo "Telechargement reussi via curl"
                else
                    echo "Echec du telechargement avec curl"
                    return 1
                fi
            else
                echo "Erreur: ni wget ni curl ne sont installes"
                return 1
            fi
            ;;
            
        3)
            # Parcours automatique des images
            method_name="Detection automatique"
            echo -e "\nIMAGES DETECTEES AUTOMATIQUEMENT"
            echo "Recherche d'images dans les dossiers courants..."
            
            # Recherche dans plusieurs dossiers
            local search_dirs=("$HOME/Pictures" "$HOME/Images" "$HOME/Photos" "$HOME/Desktop" "$HOME/Bureau" "$HOME/Downloads" "$HOME/Telechargements")
            declare -a found_images
            local i=1
            
            echo "Images trouvees:"
            for dir in "${search_dirs[@]}"; do
                if [ -d "$dir" ]; then
                    while IFS= read -r -d $'\0' img; do
                        if [ $i -le 25 ]; then  # Limiter a 25 images pour la lisibilite
                            local size=$(du -h "$img" 2>/dev/null | cut -f1)
                            echo "$i. $(basename "$img") - $size ($(dirname "$img"))"
                            found_images[$i]="$img"
                            ((i++))
                        fi
                    done < <(find "$dir" -maxdepth 2 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.svg" -o -iname "*.webp" \) -print0 2>/dev/null)
                fi
            done
            
            if [ $i -eq 1 ]; then
                echo "Aucune image trouvee dans les dossiers courants"
                echo "Essayez la methode 1 pour parcourir manuellement"
                return 1
            fi
            
            echo ""
            read -p "Choisissez une image [1-$((i-1))]: " img_choice
            if [[ "$img_choice" =~ ^[0-9]+$ ]] && ((img_choice >= 1 && img_choice < i)); then
                source_image="${found_images[$img_choice]}"
                echo "Image selectionnee: $(basename "$source_image")"
            else
                echo "Choix invalide"
                return 1
            fi
            ;;
            
        4)
            # Presse-papiers (chemin)
            method_name="Presse-papiers"
            echo -e "\nCOPIE DEPUIS LE PRESSE-PAPIERS"
            echo "Copiez le chemin complet d'une image dans le presse-papiers"
            echo "Puis appuyez sur Entree"
            echo ""
            read -p "Collez le chemin de l'image ici: " clipboard_path
            
            if [ -f "$clipboard_path" ]; then
                source_image="$clipboard_path"
                echo "Chemin valide: $(basename "$source_image")"
            else
                echo "Erreur: Fichier non trouve: $clipboard_path"
                return 1
            fi
            ;;
            
        5|"")
            echo "Ajout d'image annule"
            return 0
            ;;
            
        *)
            echo "Methode invalide"
            return 1
            ;;
    esac
    
    # Verification du fichier source
    if [ -z "$source_image" ] || [ ! -f "$source_image" ]; then
        echo "Erreur: Aucune image selectionnee ou fichier inexistant"
        return 1
    fi
    
    # Verification du format d'image
    local extension="${source_image##*.}"
    case "${extension,,}" in
        png|jpg|jpeg|gif|bmp|svg|webp|ico)
            echo "Format d'image valide: $extension"
            ;;
        *)
            echo "Attention: Format potentiellement non supporte: $extension"
            read -p "Continuer quand meme ? [y/N]: " continuer
            if [[ ! "$continuer" =~ ^[Yy]$ ]]; then
                return 1
            fi
            ;;
    esac
    
    # Verification de la taille
    if [ -f "$source_image" ]; then
        local size_kb=$(du -k "$source_image" | cut -f1)
        if [ $size_kb -gt 1024 ]; then  # Plus de 1 Mo
            echo "Attention: Image volumineuse ($(du -h "$source_image" | cut -f1))"
            echo "Recommandation: utilisez des images < 500 KB pour de meilleures performances"
        fi
    fi
    
    # Preparation des noms de fichiers
    local img_name=$(basename "$source_image" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local timestamp=$(date +%s)
    local dest_original="$FASTFETCH_IMAGES_DIR/original_${timestamp}_${img_name}"
    local dest_converted="$FASTFETCH_LOGOS_DIR/converted_${timestamp}_${img_name%.*}.png"
    
    echo -e "\nTRAITEMENT DE L'IMAGE"
    echo "Methode utilisee: $method_name"
    echo "Image source: $(basename "$source_image")"
    
    # Copie de l'original
    if cp "$source_image" "$dest_original"; then
        echo "Original sauvegarde: $(basename "$dest_original")"
    else
        echo "Erreur lors de la sauvegarde de l'original"
        return 1
    fi
    
    # Conversion pour Fastfetch
    echo "Conversion pour Fastfetch (optimisation taille et format)..."
    
    # Verification de la presence d'ImageMagick
    if ! command -v convert >/dev/null; then
        echo "Installation d'ImageMagick pour la conversion..."
        if command -v apt >/dev/null; then
            sudo apt install imagemagick -y
        elif command -v pacman >/dev/null; then
            sudo pacman -S imagemagick --noconfirm
        elif command -v dnf >/dev/null; then
            sudo dnf install ImageMagick -y
        else
            echo "Impossible d'installer ImageMagick automatiquement"
            echo "Image originale disponible sans conversion"
            dest_converted="$dest_original"
        fi
    fi
    
    # Conversion avec ImageMagick si disponible
    if command -v convert >/dev/null && [ "$dest_converted" != "$dest_original" ]; then
        if convert "$source_image" \
            -resize "80x40>" \
            -colors 256 \
            -strip \
            -quality 85 \
            "$dest_converted" 2>/dev/null; then
            
            local size_original=$(du -h "$dest_original" | cut -f1)
            local size_converted=$(du -h "$dest_converted" | cut -f1)
            echo "Conversion reussie:"
            echo "  Original: $size_original"
            echo "  Convertie: $size_converted"
        else
            echo "Erreur de conversion, utilisation de l'original"
            dest_converted="$dest_original"
        fi
    fi
    
    # Test de l'image avec Fastfetch
    echo -e "\nTEST AVEC FASTFETCH"
    echo "Test d'affichage avec la nouvelle image..."
    
    # Creation d'une configuration temporaire pour test
    local config_test="/tmp/fastfetch_test_config.jsonc"
    cat > "$config_test" <<EOF
{
    "logo": {
        "source": "$dest_converted",
        "width": 60,
        "height": 30
    },
    "modules": ["title", "os", "kernel", "cpu", "memory"]
}
EOF
    
    # Execution du test
    if timeout 10 fastfetch --config "$config_test" 2>/dev/null; then
        echo "Test reussi ! L'image fonctionne avec Fastfetch"
        rm -f "$config_test"
    else
        echo "Attention: Test partiel ou echec, mais l'image a ete ajoutee"
        rm -f "$config_test"
    fi
    
    # Nettoyage des fichiers temporaires
    if [[ "$source_image" == "/tmp/fastfetch_dl_"* ]]; then
        rm -f "$source_image"
        echo "Fichier temporaire nettoye"
    fi
    
    # Informations finales
    echo -e "\nIMAGE AJOUTEE AVEC SUCCES"
    echo "Methode: $method_name"
    echo "Fichiers crees:"
    echo "  Original: $dest_original"
    echo "  Optimise: $dest_converted"
    echo ""
    echo "Utilisation:"
    echo "1. Option 'Logo fixe personnalise' dans le menu Fastfetch"
    echo "2. Option 'Logo aleatoire' pour rotation automatique"
    echo "3. Configuration manuelle avec: fastfetch --logo '$dest_converted'"
    echo ""
    echo "L'image est maintenant disponible dans les options de configuration Fastfetch"
    
    return 0
}

# Restaurer configuration par défaut
function restaurer_config_fastfetch() {
    echo -e "\nRESTAURATION CONFIGURATION FASTFETCH PAR DÉFAUT"
    
    # Sauvegarder l'ancienne configuration
    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        cp "$FASTFETCH_CONFIG_DIR/config.jsonc" "$FASTFETCH_CONFIG_DIR/config.jsonc.bak.$(date +%s)"
        echo "Ancienne configuration sauvegardée"
    fi
    
    # Supprimer la configuration personnalisée
    rm -f "$FASTFETCH_CONFIG_DIR/config.jsonc"
    rm -f "$FASTFETCH_CONFIG_DIR/random_logo.sh"
    rm -f "$FASTFETCH_CONFIG_DIR/fastfetch_random.sh"
    
    # Retirer l'alias
    sed -i '/alias fastfetch-random/d' "$HOME/.bashrc" 2>/dev/null
    sed -i '/alias fastfetch-random/d' "$HOME/.zshrc" 2>/dev/null
    
    echo "Configuration par défaut restaurée"
    echo "Fastfetch utilisera maintenant le logo par défaut du système"
}

function configurer_lockscreen() {
    echo -e "\nCONFIGURATION DU LOCKSCREEN (VERROUILLAGE DE SESSION)"
    
    if pgrep -x "plasmashell" >/dev/null; then
        echo "Environnement KDE Plasma détecté"
        echo "Options disponibles :"
        echo "1. Image fixe"
        echo "2. Diaporama d'images"
        echo "3. Vidéo (expérimental)"
        read -p "Votre choix [1-3] : " lock_choice

        case "$lock_choice" in
            1)
                img=$(selectionner_fichier_interactif "$HOME/Pictures" "*.jpg *.png" "Choisissez une image pour l'écran de verrouillage")
                [ -n "$img" ] && qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                    lockscreen = lockScreen;
                    lockscreen.background = 'file://$img';
                " && echo "Image appliquée au lockscreen."
                ;;
            2)
                dir=$(selectionner_dossier_interactif "$HOME/Pictures" "Choisissez un dossier d'images")
                [ -n "$dir" ] && kwriteconfig5 --file kscreenlockerrc --group Greeter --key Image "$dir" && \
                    kwriteconfig5 --file kscreenlockerrc --group Greeter --key SlideShow "$dir" && \
                    echo "Diaporama appliqué au lockscreen."
                ;;
            3)
                echo "Mode vidéo en cours de test (nécessite `sddm-greeter` modifié ou un script externe)."
                ;;
        esac

    elif pgrep -x "gnome-shell" >/dev/null; then
        echo "Environnement GNOME détecté"
        img=$(selectionner_fichier_interactif "$HOME/Pictures" "*.jpg *.png" "Choisissez une image pour le lockscreen")
        [ -n "$img" ] && gsettings set org.gnome.desktop.screensaver picture-uri "file://$img" && \
            echo "Image appliquée au lockscreen GNOME."
    else
        echo "Environnement non reconnu. Configurez manuellement le lockscreen."
    fi
}

function configurer_barre_taches() {
    echo -e "\nCONFIGURATION DE LA BARRE DES TÂCHES"

    if pgrep -x "plasmashell" >/dev/null; then
        echo "KDE Plasma détecté"
        echo "Options :"
        echo "1. Pleine largeur en bas"
        echo "2. Taille réduite et centrée"
        echo "3. Couleur personnalisée + transparence"
        read -p "Votre choix [1-3] : " task_choice

        case "$task_choice" in
            1)
                qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                    var panel = panels()[0];
                    panel.location = 'bottom';
                    panel.alignment = 'fill';
                "
                ;;
            2)
                qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                    var panel = panels()[0];
                    panel.alignment = 'center';
                    panel.height = 36;
                "
                ;;
            3)
                echo "Application d’un style personnalisé..."
                kwriteconfig5 --file plasmarc --group Theme --key backgroundColor "#55000055"
                kquitapp5 plasmashell && kstart plasmashell &
                ;;
        esac

    elif pgrep -x "gnome-shell" >/dev/null; then
        echo "GNOME détecté : personnalisation via `gnome-extensions` (Dash to Dock / Dash to Panel)."
        echo "Activez et configurez via l’outil `gnome-tweaks`."
    else
        echo "Environnement non supporté automatiquement."
    fi
}

function customiser_fastfetch_plus() {
    echo -e "\nCUSTOMISATION AVANCÉE DE FASTFETCH"
    installer_fastfetch || return 1
    mkdir -p "$FASTFETCH_CONFIG_DIR" "$FASTFETCH_LOGOS_DIR"

    echo "Options :"
    echo "1. Logo d'une autre distro Arch (depuis repo GitHub)"
    echo "2. ASCII/ANSI art (Pokémon, perso, etc.)"
    echo "3. Image locale"
    read -p "Choix [1-3] : " ff_choice

    case "$ff_choice" in
        1)
            echo "Téléchargement de logos Arch alternatifs..."
            git clone https://github.com/adi1090x/termux-style /tmp/ff-logos --depth=1
            cp /tmp/ff-logos/ascii/* "$FASTFETCH_LOGOS_DIR/"
            echo "Logos importés. Configurez via customiser_fastfetch."
            ;;
        2)
            echo "Téléchargement d’ASCII Pokémon..."
            git clone https://github.com/borntyping/pokemon-terminal-art /tmp/ff-pokemon --depth=1
            cp /tmp/ff-pokemon/ascii/* "$FASTFETCH_LOGOS_DIR/"
            echo "Pokémon ASCII ajoutés !"
            ;;
        3)
            img=$(selectionner_fichier_interactif "$HOME/Pictures" "*.jpg *.png" "Sélectionnez une image")
            [ -n "$img" ] && convertir_image_fastfetch "$img" "$FASTFETCH_LOGOS_DIR/custom.png" 60 30
            ;;
    esac
}

function basculer_theme_systeme() {
    echo -e "\nCHANGEMENT DU THÈME CLAIR/SOMBRE"

    echo "1. Forcer mode clair"
    echo "2. Forcer mode sombre"
    echo "3. Basculer automatiquement selon l'heure (7h-19h clair, sinon sombre)"
    read -p "Votre choix [1-3] : " theme_choice

    case "$theme_choice" in
        1) 
            mode="light"
            echo "Mode clair activé"
            ;;
        2) 
            mode="dark"
            echo "Mode sombre activé"
            ;;
        3)
            hour=$(date +%H)
            if ((hour >= 7 && hour < 19)); then 
                mode="light"
                echo "Mode clair activé (jour)"
            else 
                mode="dark"
                echo "Mode sombre activé (nuit)"
            fi
            ;;
        *) 
            echo "Choix invalide"
            return 1 
            ;;
    esac

    # Configuration pour KDE Plasma
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        echo "Configuration pour KDE Plasma..."
        
        # Thème de couleur
        if [ "$mode" = "light" ]; then
            kwriteconfig5 --file kdeglobals --group General --key ColorScheme "BreezeLight"
            kwriteconfig5 --file kdeglobals --group General --key Name "Breeze Light"
        else
            kwriteconfig5 --file kdeglobals --group General --key ColorScheme "BreezeDark"
            kwriteconfig5 --file kdeglobals --group General --key Name "Breeze Dark"
        fi
        
        # Thème d'icônes
        kwriteconfig5 --file kdeglobals --group Icons --key Theme "breeze-dark"  # Les deux modes utilisent breeze-dark pour les icônes
        
        # Forcer le rechargement
        qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
        
        echo "Thème $mode appliqué pour KDE Plasma. Redémarrez la session pour voir tous les changements."

    # Configuration pour GNOME
    elif pgrep -x "gnome-shell" >/dev/null 2>&1; then
        echo "Configuration pour GNOME..."
        
        if [ "$mode" = "light" ]; then
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
            gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
        else
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
            gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
        fi
        
        echo "Thème $mode appliqué pour GNOME."

    # Configuration pour XFCE
    elif pgrep -x "xfce4-panel" >/dev/null 2>&1; then
        echo "Configuration pour XFCE..."
        
        if [ "$mode" = "light" ]; then
            xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita"
            xfconf-query -c xsettings -p /Net/IconThemeName -s "Adwaita"
        else
            xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"
            xfconf-query -c xsettings -p /Net/IconThemeName -s "Adwaita"
        fi
        
        echo "Thème $mode appliqué pour XFCE."

    else
        echo "Environnement de bureau non reconnu."
        echo "Mode sélectionné: $mode"
        echo "Configurez manuellement le thème dans les paramètres de votre bureau."
    fi

    # Configuration GTK globale (pour les applications)
    if [ "$mode" = "dark" ]; then
        # Forcer le mode sombre pour les applications GTK
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        echo "GTK applications configurées pour le mode sombre"
    else
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
        echo "GTK applications configurées pour le mode clair"
    fi

    echo "Changement de thème terminé!"
}

function configurer_clavier() {
    echo -e "\nCONFIGURATION DE LA DISPOSITION CLAVIER AU BOOT"

    # Liste des langues les plus pratiquées avec leurs codes
    declare -A langues=(
        [1]="fr Français"
        [2]="en Anglais"
        [3]="es Espagnol"
        [4]="de Allemand"
        [5]="it Italien"
        [6]="pt Portugais"
        [7]="ru Russe"
        [8]="zh Chinois"
        [9]="ja Japonais"
        [10]="ko Coréen"
        [11]="ar Arabe"
        [12]="nl Néerlandais"
        [13]="sv Suédois"
        [14]="da Danois"
        [15]="no Norvégien"
        [16]="fi Finnois"
        [17]="pl Polonais"
        [18]="tr Turc"
        [19]="vi Vietnamien"
        [20]="el Grec"
        [21]="he Hébreu"
        [22]="hi Hindi"
        [23]="th Thaïlandais"
        [24]="cs Tchèque"
        [25]="hu Hongrois"
    )

    # Afficher la liste des langues
    echo "Langues disponibles :"
    echo "===================="
    for i in {1..25}; do
        echo "$i. ${langues[$i]}"
    done

    read -p "Choisissez une langue [1-25] : " choix_langue

    # Vérifier le choix
    if ! [[ "$choix_langue" =~ ^[0-9]+$ ]] || ((choix_langue < 1 || choix_langue > 25)); then
        echo "Choix invalide."
        return 1
    fi

    # Extraire le code de la langue
    langue_code=$(echo "${langues[$choix_langue]}" | cut -d' ' -f1)
    langue_nom=$(echo "${langues[$choix_langue]}" | cut -d' ' -f2-)

    echo -e "\nLangue sélectionnée : $langue_nom ($langue_code)"

    # Définir les variantes de claviers pour chaque langue
    declare -A variantes=(
        ["fr"]="azerty bepo oss oss_latin9 fr-latin9 fr-azerty fr-bepo fr-oss fr-oss_latin9 fr-be"
        ["en"]="us uk dvorak colemak workman"
        ["es"]="es ast cat"
        ["de"]="de de-nodeadkeys"
        ["it"]="it it-nodeadkeys"
        ["pt"]="pt pt-nodeadkeys"
        ["ru"]="ru ru-phonetic"
        ["zh"]="cn tw hk"
        ["ja"]="jp jp106"
        ["ko"]="kr"
        ["ar"]="ar azerty"
        ["nl"]="nl"
        ["sv"]="sv nodeadkeys"
        ["da"]="da nodeadkeys"
        ["no"]="no nodeadkeys"
        ["fi"]="fi nodeadkeys"
        ["pl"]="pl"
        ["tr"]="tr trf"
        ["vi"]="vi"
        ["el"]="el"
        ["he"]="he"
        ["hi"]="in"
        ["th"]="th"
        ["cs"]="cz qwerty"
        ["hu"]="hu"
    )

    # Noms conviviaux pour les variantes françaises
    declare -A noms_variantes_fr=(
        ["azerty"]="AZERTY standard (France)"
        ["bepo"]="BÉPO (ergonomique français)"
        ["oss"]="OSS (Open Source Software)"
        ["oss_latin9"]="OSS Latin9"
        ["fr-latin9"]="Français Latin9"
        ["fr-azerty"]="Français AZERTY"
        ["fr-bepo"]="Français BÉPO"
        ["fr-oss"]="Français OSS"
        ["fr-oss_latin9"]="Français OSS Latin9"
        ["fr-be"]="AZERTY belge (Belgique)"
    )

    # Afficher les variantes disponibles pour la langue sélectionnée
    if [ -n "${variantes[$langue_code]}" ]; then
        echo -e "\nVariantes de clavier disponibles pour $langue_nom :"
        echo "======================================================"
        
        variantes_list=(${variantes[$langue_code]})
        for j in "${!variantes_list[@]}"; do
            variante_code="${variantes_list[$j]}"
            if [ "$langue_code" = "fr" ] && [ -n "${noms_variantes_fr[$variante_code]}" ]; then
                echo "$((j+1)). $variante_code - ${noms_variantes_fr[$variante_code]}"
            else
                echo "$((j+1)). $variante_code"
            fi
        done

        read -p "Choisissez une variante [1-${#variantes_list[@]}] : " choix_variante

        # Vérifier le choix de la variante
        if ! [[ "$choix_variante" =~ ^[0-9]+$ ]] || ((choix_variante < 1 || choix_variante > ${#variantes_list[@]})); then
            echo "Choix invalide, utilisation de la variante par défaut."
            layout="$langue_code"
        else
            layout="${variantes_list[$((choix_variante-1))]}"
        fi
    else
        echo "Aucune variante spécifique trouvée, utilisation de la disposition par défaut."
        layout="$langue_code"
    fi

    echo -e "\nConfiguration de la disposition clavier : $layout"

    # Pour la console (avant login)
    sudo localectl set-keymap "$layout"

    # Pour X11/Wayland
    sudo localectl set-x11-keymap "$layout"

    echo "Disposition clavier '$layout' configurée pour le boot."
    echo "Les changements seront effectifs au prochain démarrage."
}

function configurer_son_login() {
    echo -e "\nCONFIGURATION SONORE DU LOGIN/BOOT"
    echo "======================================"
    
    # Vérifier les dépendances
    if ! command -v paplay >/dev/null; then
        echo "Installation de PulseAudio utils..."
        if command -v apt >/dev/null; then
            sudo apt install pulseaudio-utils -y
        elif command -v pacman >/dev/null; then
            sudo pacman -S pulseaudio --noconfirm
        elif command -v dnf >/dev/null; then
            sudo dnf install pulseaudio-utils -y
        fi
    fi
    
    # Options disponibles
    echo -e "\nOptions disponibles:"
    echo "1. Sélectionner un fichier audio local"
    echo "2. Télécharger un son depuis une URL"
    echo "3. Utiliser un son du système"
    echo "4. Tester les sons disponibles"
    echo "5. Désactiver le son de login"
    echo "6. Annuler"
    
    read -p "Votre choix [1-6]: " choice
    
    case "$choice" in
        1)
            # Sélectionner un fichier audio local
            echo -e "\nSÉLECTION D'UN FICHIER AUDIO LOCAL"
            echo "Formats supportés: mp3, wav, ogg, flac"
            
            # Déterminer le dossier de départ
            local dossier_audio="$HOME"
            for dir in "$HOME/Music" "$HOME/Musique" "$HOME/Downloads" "$HOME/Téléchargements" "$HOME/Audio"; do
                if [ -d "$dir" ]; then
                    dossier_audio="$dir"
                    break
                fi
            done
            
            echo "Dossier de recherche: $dossier_audio"
            audio_file=$(selectionner_fichier_interactif "$dossier_audio" "*.mp3 *.wav *.ogg *.flac" "Sélectionnez un fichier audio")
            
            if [ -z "$audio_file" ] || [ ! -f "$audio_file" ]; then
                echo "Aucun fichier sélectionné ou fichier invalide."
                return 1
            fi
            ;;
            
        2)
            # Télécharger depuis une URL
            echo -e "\nTÉLÉCHARGEMENT DEPUIS URL"
            read -p "URL du fichier audio: " audio_url
            
            if [ -z "$audio_url" ]; then
                echo "URL vide."
                return 1
            fi
            
            # Créer le dossier de téléchargement
            DOWNLOAD_DIR="$HOME/.local/share/sounds/login"
            mkdir -p "$DOWNLOAD_DIR"
            
            # Télécharger le fichier
            echo "Téléchargement en cours..."
            if command -v wget >/dev/null; then
                wget -q -O "$DOWNLOAD_DIR/login_sound.${audio_url##*.}" "$audio_url"
                audio_file="$DOWNLOAD_DIR/login_sound.${audio_url##*.}"
            elif command -v curl >/dev/null; then
                curl -s -o "$DOWNLOAD_DIR/login_sound.${audio_url##*.}" "$audio_url"
                audio_file="$DOWNLOAD_DIR/login_sound.${audio_url##*.}"
            else
                echo "Erreur: wget ou curl non installé."
                return 1
            fi
            
            if [ ! -f "$audio_file" ]; then
                echo "Échec du téléchargement."
                return 1
            fi
            ;;
            
        3)
            # Utiliser un son du système
            echo -e "\nSONS SYSTÈME DISPONIBLES:"
            system_sounds_dir="/usr/share/sounds"
            if [ -d "$system_sounds_dir" ]; then
                find "$system_sounds_dir" -name "*.ogg" -o -name "*.wav" -o -name "*.mp3" | head -10 | nl
                read -p "Numéro du son: " sound_num
                audio_file=$(find "$system_sounds_dir" -name "*.ogg" -o -name "*.wav" -o -name "*.mp3" | sed -n "${sound_num}p")
                
                if [ -z "$audio_file" ]; then
                    echo "Sélection invalide."
                    return 1
                fi
            else
                echo "Aucun son système trouvé."
                return 1
            fi
            ;;
            
        4)
            # Tester les sons disponibles
            echo -e "\nTEST DES SONS DISPONIBLES"
            test_dir="$HOME/.local/share/sounds/login"
            if [ -d "$test_dir" ]; then
                echo "Sons personnalisés:"
                find "$test_dir" -name "*.mp3" -o -name "*.wav" -o -name "*.ogg" | nl
            fi
            
            echo -e "\nSons système:"
            find "/usr/share/sounds" -name "*.ogg" -o -name "*.wav" -o -name "*.mp3" 2>/dev/null | head -5 | nl
            
            read -p "Numéro du son à tester (0 pour annuler): " test_num
            if [ "$test_num" -eq 0 ]; then
                return 0
            fi
            
            test_file=$(find "$test_dir" "/usr/share/sounds" -name "*.mp3" -o -name "*.wav" -o -name "*.ogg" 2>/dev/null | sed -n "${test_num}p")
            if [ -n "$test_file" ] && [ -f "$test_file" ]; then
                echo "Test du son: $(basename "$test_file")"
                timeout 5 paplay "$test_file" 2>/dev/null &
                read -p "Appuyez sur Entrée pour arrêter le test..." 
                pkill -f "paplay.*$test_file" 2>/dev/null
            else
                echo "Fichier non trouvé."
            fi
            return 0
            ;;
            
        5)
            # Désactiver le son
            echo -e "\nDÉSACTIVATION DU SON DE LOGIN"
            systemctl --user disable login-sound.service 2>/dev/null
            rm -f "$HOME/.config/systemd/user/login-sound.service"
            echo "Son de login désactivé."
            return 0
            ;;
            
        6|"")
            echo "Opération annulée."
            return 0
            ;;
            
        *)
            echo "Choix invalide."
            return 1
            ;;
    esac
    
    # Vérifier le format du fichier audio
    if [ ! -f "$audio_file" ]; then
        echo "Fichier audio non trouvé: $audio_file"
        return 1
    fi
    
    # Vérifier le format
    file_ext="${audio_file##*.}"
    case "${file_ext,,}" in
        mp3|wav|ogg|flac)
            echo "Format audio supporté: $file_ext"
            ;;
        *)
            echo "Format non supporté: $file_ext"
            echo "Formats supportés: mp3, wav, ogg, flac"
            return 1
            ;;
    esac
    
    # Vérifier la taille du fichier
    file_size=$(du -k "$audio_file" | cut -f1)
    if [ "$file_size" -gt 1024 ]; then
        echo "Attention: Fichier volumineux ($((file_size/1024)) Mo)"
        read -p "Continuer quand même ? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Copier le fichier dans le dossier des sons utilisateur
    SOUNDS_DIR="$HOME/.local/share/sounds/login"
    mkdir -p "$SOUNDS_DIR"
    cp "$audio_file" "$SOUNDS_DIR/login_sound.$file_ext"
    local final_audio="$SOUNDS_DIR/login_sound.$file_ext"
    
    # Configuration systemd
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_DIR"
    
    # Créer le service systemd
    cat > "$SYSTEMD_DIR/login-sound.service" <<EOF
[Unit]
Description=Lecture du son au login
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
Environment=DISPLAY=:0
Environment=XAUTHORITY=%h/.Xauthority
ExecStart=/usr/bin/paplay "$final_audio"
ExecStartPost=/bin/sleep 2
Restart=no
User=%I

[Install]
WantedBy=default.target
EOF
    
    # Activer le service
    systemctl --user daemon-reload
    systemctl --user enable login-sound.service
    systemctl --user start login-sound.service
    
    # Configuration supplémentaire pour différents environnements
    if pgrep -x "plasmashell" >/dev/null; then
        # KDE Plasma
        kwriteconfig5 --file kdeglobals --group General --key LoginSound true
        echo "Configuration KDE appliquée."
    fi
    
    # Test immédiat
    echo -e "\nTest du son..."
    timeout 5 paplay "$final_audio" 2>/dev/null &
    
    echo -e "\n✅ CONFIGURATION TERMINÉE !"
    echo "Fichier audio: $(basename "$final_audio")"
    echo "Service systemd: $SYSTEMD_DIR/login-sound.service"
    echo ""
    echo "Le son se jouera automatiquement à chaque connexion."
    echo ""
    echo "Commandes de gestion:"
    echo "  systemctl --user status login-sound.service  # Vérifier le statut"
    echo "  systemctl --user restart login-sound.service # Redémarrer le service"
    echo "  systemctl --user disable login-sound.service # Désactiver le son"
    echo ""
    echo "Redémarrez votre session pour tester complètement."
}

# Export profil
function exporter_profil() {
    echo -e "\nEXPORT DE PROFIL"
    profil="$HOME/BGC_Profile_$(date +%Y%m%d).tar.gz"
    tar -czf "$profil" ~/.config ~/.local/share /etc/default/grub /etc/sddm.conf.d 2>/dev/null || true
    echo "Profil exporté : $profil"
}

# Import profil
function importer_profil() {
    echo -e "\nIMPORT DE PROFIL"
    read -p "Fichier .tar.gz : " f
    [ ! -f "$f" ] && echo "Fichier invalide" && return
    tar -xzf "$f" -C /
    echo "Profil importé"
}

function download_video() {
    local url="$1"
    local type="$2"
    local output_dir="$HOME/Téléchargements/Vidéos"
    mkdir -p "$output_dir"
    
    echo "Téléchargement en cours..."
    
    local options=""
    if [ "$type" = "playlist" ]; then
        options="--yes-playlist"
    else
        options="--no-playlist"
    fi
    
    # Utiliser le downloader disponible
    if [ "$DOWNLOADER" = "yt-dlp" ]; then
        yt-dlp \
            -o "$output_dir/%(title)s.%(ext)s" \
            --merge-output-format mp4 \
            --format "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
            --add-metadata \
            --embed-thumbnail \
            $options \
            "$url"
    else
        youtube-dl \
            -o "$output_dir/%(title)s.%(ext)s" \
            --format "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
            --add-metadata \
            $options \
            "$url"
    fi
    
    if [ $? -eq 0 ]; then
        echo "Téléchargement terminé dans: $output_dir"
    else
        echo "Erreur lors du téléchargement"
    fi
}

function download_from_file() {
    local url_file="$1"
    local output_dir="$HOME/Téléchargements/Vidéos"
    mkdir -p "$output_dir"
    
    echo "Téléchargement en masse depuis le fichier..."
    
    if [ "$DOWNLOADER" = "yt-dlp" ]; then
        yt-dlp \
            -a "$url_file" \
            -o "$output_dir/%(title)s.%(ext)s" \
            --merge-output-format mp4 \
            --format "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
            --add-metadata \
            --embed-thumbnail
    else
        youtube-dl \
            -a "$url_file" \
            -o "$output_dir/%(title)s.%(ext)s" \
            --format "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
            --add-metadata
    fi
    
    echo "Téléchargement en masse terminé"
}

function extract_audio() {
    local url="$1"
    local output_dir="$HOME/Téléchargements/Musique"
    mkdir -p "$output_dir"
    
    echo "Extraction audio en cours..."
    
    if [ "$DOWNLOADER" = "yt-dlp" ]; then
        yt-dlp \
            -x \
            --audio-format mp3 \
            --audio-quality 0 \
            -o "$output_dir/%(title)s.%(ext)s" \
            --embed-thumbnail \
            --add-metadata \
            "$url"
    else
        youtube-dl \
            -x \
            --audio-format mp3 \
            --audio-quality 0 \
            -o "$output_dir/%(title)s.%(ext)s" \
            --add-metadata \
            "$url"
    fi
    
    if [ $? -eq 0 ]; then
        echo "Audio extrait dans: $output_dir"
    else
        echo "Erreur lors de l'extraction audio"
    fi
}

function choose_quality() {
    local url="$1"
    local output_dir="$HOME/Téléchargements/Vidéos"
    mkdir -p "$output_dir"
    
    echo "Formats disponibles:"
    if [ "$DOWNLOADER" = "yt-dlp" ]; then
        yt-dlp -F "$url"
    else
        youtube-dl -F "$url"
    fi
    
    read -p "Entrez le code du format désiré: " format_code
    
    echo "Téléchargement avec le format choisi..."
    
    if [ "$DOWNLOADER" = "yt-dlp" ]; then
        yt-dlp \
            -f "$format_code" \
            -o "$output_dir/%(title)s.%(ext)s" \
            --merge-output-format mp4 \
            --add-metadata \
            --embed-thumbnail \
            "$url"
    else
        youtube-dl \
            -f "$format_code" \
            -o "$output_dir/%(title)s.%(ext)s" \
            --add-metadata \
            "$url"
    fi
    
    if [ $? -eq 0 ]; then
        echo "Téléchargement terminé avec le format choisi"
    else
        echo "Erreur lors du téléchargement"
    fi
}

# Fonction pour télécharger depuis les sites populaires
function telecharger_videos() {
    echo -e "\nTÉLÉCHARGEMENT SITE SPÉCIFIQUE"
    
    echo "Sites supportés:"
    echo "1. YouTube"
    echo "2. Twitter/X"
    echo "3. Instagram"
    echo "4. TikTok"
    echo "5. Facebook"
    echo "6. Reddit"
    echo "7. Dailymotion"
    echo "8. Vimeo"
    echo "9. SoundCloud (audio)"
    echo "10. Twitch (VOD/clips)"
    
    read -p "Choix du site [1-10]: " site_choice
    read -p "URL de la vidéo: " video_url
    
    local output_dir="$HOME/Téléchargements/Vidéos"
    mkdir -p "$output_dir"
    
    echo "Téléchargement depuis le site sélectionné..."
    
    if [ "$DOWNLOADER" = "yt-dlp" ]; then
        yt-dlp \
            -o "$output_dir/%(title)s.%(ext)s" \
            --merge-output-format mp4 \
            --add-metadata \
            --embed-thumbnail \
            "$video_url"
    else
        youtube-dl \
            -o "$output_dir/%(title)s.%(ext)s" \
            --add-metadata \
            "$video_url"
    fi
    
    echo "Téléchargement terminé"
}

# Thèmes sonores complets KDE/GNOME
function installer_theme_sonore() {
    echo -e "\n🎵 INSTALLATION D'UN THÈME SONORE COMPLET"
    echo "=========================================="
    
    # Vérifier les environnements de bureau disponibles
    echo -e "\nDétection de l'environnement de bureau..."
    local env_detected=""
    
    if pgrep -x "plasmashell" >/dev/null; then
        env_detected="kde"
        echo "Environnement détecté: KDE Plasma"
    elif pgrep -x "gnome-shell" >/dev/null; then
        env_detected="gnome"
        echo "Environnement détecté: GNOME"
    elif command -v xfce4-session >/dev/null && pgrep -x "xfce4-session" >/dev/null; then
        env_detected="xfce"
        echo "Environnement détecté: XFCE"
    elif command -v cinnamon-session >/dev/null && pgrep -x "cinnamon-session" >/dev/null; then
        env_detected="cinnamon"
        echo "Environnement détecté: Cinnamon"
    else
        echo "Environnement non spécifiquement détecté, utilisation des méthodes génériques"
    fi
    
    # Options disponibles
    echo -e "\nOptions disponibles:"
    echo "1. Thème sonore pour KDE Plasma"
    echo "2. Thème sonore pour GNOME"
    echo "3. Thème sonore pour XFCE"
    echo "4. Thème sonore générique (pour tout environnement)"
    echo "5. Installer des thèmes sonores supplémentaires"
    echo "6. Configurer les sons système personnalisés"
    echo "7. Tester les sons actuels"
    echo "8. Annuler"
    
    read -p "Votre choix [1-8]: " choice
    
    case "$choice" in
        1|2|3|4)
            # Déterminer le type de thème en fonction du choix
            case "$choice" in
                1) theme_type="kde" ;;
                2) theme_type="gnome" ;;
                3) theme_type="xfce" ;;
                4) theme_type="generic" ;;
            esac
            
            # Vérifier si des thèmes sonores sont disponibles dans le repo
            SOUND_THEMES_DIR="$REPO_DIR/sound-themes"
            if [ ! -d "$SOUND_THEMES_DIR" ]; then
                echo "Dossier des thèmes sonores introuvable dans le dépôt."
                echo "Tentative de téléchargement..."
                
                # Essayer de créer le dossier et de trouver des thèmes
                mkdir -p "$SOUND_THEMES_DIR"
                
                # Télécharger quelques thèmes sonores de base si le dossier est vide
                if [ -z "$(ls -A "$SOUND_THEMES_DIR")" ]; then
                    echo "Téléchargement de thèmes sonores de base..."
                    
                    # Thème Material Design (sons modernes)
                    if ! [ -d "$SOUND_THEMES_DIR/MaterialDesign" ]; then
                        git clone https://github.com/material-design-sound-theme/material-design-sound-theme.git "$SOUND_THEMES_DIR/MaterialDesign" 2>/dev/null || \
                        echo "Échec du téléchargement du thème Material Design"
                    fi
                    
                    # Thème Freedesktop (standard)
                    if ! [ -d "$SOUND_THEMES_DIR/Freedesktop" ]; then
                        mkdir -p "$SOUND_THEMES_DIR/Freedesktop"
                        echo "Installation des sons Freedesktop standard..."
                        # Copier les sons système s'ils existent
                        if [ -d "/usr/share/sounds/freedesktop" ]; then
                            cp -r /usr/share/sounds/freedesktop/* "$SOUND_THEMES_DIR/Freedesktop/" 2>/dev/null || true
                        fi
                    fi
                fi
            fi
            
            # Lister les thèmes sonores disponibles
            echo -e "\nThèmes sonores disponibles:"
            local i=1
            declare -a theme_dirs
            declare -a theme_names
            
            # Parcourir les thèmes dans le dossier du repo
            for theme_dir in "$SOUND_THEMES_DIR"/*; do
                if [ -d "$theme_dir" ]; then
                    theme_name=$(basename "$theme_dir")
                    echo "$i. $theme_name"
                    theme_dirs[$i]="$theme_dir"
                    theme_names[$i]="$theme_name"
                    ((i++))
                fi
            done
            
            # Ajouter les thèmes système s'ils existent
            if [ -d "/usr/share/sounds" ]; then
                for sys_theme in /usr/share/sounds/*; do
                    if [ -d "$sys_theme" ] && [ -f "$sys_theme/index.theme" ]; then
                        theme_name=$(basename "$sys_theme")
                        echo "$i. $theme_name (système)"
                        theme_dirs[$i]="$sys_theme"
                        theme_names[$i]="$theme_name"
                        ((i++))
                    fi
                done
            fi
            
            if [ $i -eq 1 ]; then
                echo "Aucun thème sonore trouvé."
                echo "Utilisation des sons par défaut du système."
                return 1
            fi
            
            read -p "Choisissez un thème sonore [1-$((i-1))]: " theme_choice
            
            if ! [[ "$theme_choice" =~ ^[0-9]+$ ]] || ((theme_choice < 1 || theme_choice >= i)); then
                echo "Choix invalide."
                return 1
            fi
            
            selected_theme="${theme_names[$theme_choice]}"
            selected_dir="${theme_dirs[$theme_choice]}"
            
            echo "Installation du thème sonore: $selected_theme"
            
            # Installation selon l'environnement
            case "$env_detected" in
                "kde")
                    install_theme_kde "$selected_dir" "$selected_theme"
                    ;;
                "gnome")
                    install_theme_gnome "$selected_dir" "$selected_theme"
                    ;;
                "xfce")
                    install_theme_xfce "$selected_dir" "$selected_theme"
                    ;;
                *)
                    install_theme_generic "$selected_dir" "$selected_theme"
                    ;;
            esac
            ;;
        
        5)
            # Installer des thèmes sonores supplémentaires
            install_extra_sound_themes
            ;;
        
        6)
            # Configurer les sons système personnalisés
            configure_custom_sounds
            ;;
        
        7)
            # Tester les sons actuels
            test_current_sounds
            ;;
        
        8|"")
            echo "Opération annulée."
            return 0
            ;;
        
        *)
            echo "Choix invalide."
            return 1
            ;;
    esac
    
    echo -e "\n✅ THÈME SONORE CONFIGURÉ AVEC SUCCÈS!"
    echo "Redémarrez votre session pour que tous les changements prennent effet."
}

# Fonction pour installer un thème sonore pour KDE Plasma
function install_theme_kde() {
    local theme_dir="$1"
    local theme_name="$2"
    
    echo "Configuration pour KDE Plasma..."
    
    # Copier le thème dans le dossier utilisateur
    local user_sound_dir="$HOME/.local/share/sounds"
    mkdir -p "$user_sound_dir"
    
    if [ -d "$theme_dir" ]; then
        cp -r "$theme_dir" "$user_sound_dir/$theme_name"
        echo "Thème copié dans: $user_sound_dir/$theme_name"
    fi
    
    # Configurer KDE pour utiliser ce thème
    kwriteconfig5 --file kdeglobals --group Sounds --key Theme "$theme_name"
    
    # Configurer les événements sonores spécifiques
    if [ -f "$user_sound_dir/$theme_name/index.theme" ]; then
        # Lire les sons définis dans le thème
        while read -r line; do
            if [[ "$line" =~ ^([a-zA-Z-]+)=([a-zA-Z0-9_/-]+\.ogg)$ ]]; then
                event="${BASH_REMATCH[1]}"
                sound_file="${BASH_REMATCH[2]}"
                
                # Configurer l'événement sonore dans KDE
                kwriteconfig5 --file kdeglobals --group "Event Sounds" --key "$event" "$user_sound_dir/$theme_name/$sound_file"
            fi
        done < "$user_sound_dir/$theme_name/index.theme"
    fi
    
    echo "Thème sonore '$theme_name' configuré pour KDE Plasma."
}

# Fonction pour installer un thème sonore pour GNOME
function install_theme_gnome() {
    local theme_dir="$1"
    local theme_name="$2"
    
    echo "Configuration pour GNOME..."
    
    # Copier le thème dans le dossier système ou utilisateur
    local system_sound_dir="/usr/share/sounds"
    local user_sound_dir="$HOME/.local/share/sounds"
    
    # Essayer d'abord d'installer dans le dossier système (nécessite sudo)
    if [ -w "$system_sound_dir" ]; then
        sudo cp -r "$theme_dir" "$system_sound_dir/$theme_name" 2>/dev/null && \
        echo "Thème installé dans: $system_sound_dir/$theme_name"
    else
        # Sinon, installer dans le dossier utilisateur
        mkdir -p "$user_sound_dir"
        cp -r "$theme_dir" "$user_sound_dir/$theme_name"
        echo "Thème installé dans: $user_sound_dir/$theme_name"
    fi
    
    # Configurer GNOME pour utiliser ce thème
    gsettings set org.gnome.desktop.sound theme-name "$theme_name"
    
    # Activer les sons d'interface
    gsettings set org.gnome.desktop.sound input-feedback-sounds true
    gsettings set org.gnome.desktop.sound event-sounds true
    
    echo "Thème sonore '$theme_name' configuré pour GNOME."
}

# Fonction pour installer un thème sonore pour XFCE
function install_theme_xfce() {
    local theme_dir="$1"
    local theme_name="$2"
    
    echo "Configuration pour XFCE..."
    
    # XFCE utilise généralement les thèmes système
    local system_sound_dir="/usr/share/sounds"
    sudo cp -r "$theme_dir" "$system_sound_dir/$theme_name" 2>/dev/null || \
    echo "Impossible d'installer dans $system_sound_dir, tentative dans le dossier utilisateur"
    
    # Fallback vers le dossier utilisateur
    if [ $? -ne 0 ]; then
        local user_sound_dir="$HOME/.local/share/sounds"
        mkdir -p "$user_sound_dir"
        cp -r "$theme_dir" "$user_sound_dir/$theme_name"
        echo "Thème installé dans: $user_sound_dir/$theme_name"
    fi
    
    # Configurer XFCE pour utiliser ce thème
    xfconf-query -c xsettings -p /Net/SoundThemeName -s "$theme_name" 2>/dev/null || \
    xfconf-query -c xsettings -p /Net/SoundThemeName -n -t string -s "$theme_name"
    
    # Activer les sons
    xfconf-query -c xsettings -p /Net/EnableEventSounds -s true 2>/dev/null || \
    xfconf-query -c xsettings -p /Net/EnableEventSounds -n -t bool -s true
    
    xfconf-query -c xsettings -p /Net/EnableInputFeedbackSounds -s true 2>/dev/null || \
    xfconf-query -c xsettings -p /Net/EnableInputFeedbackSounds -n -t bool -s true
    
    echo "Thème sonore '$theme_name' configuré pour XFCE."
}

# Fonction générique pour installer un thème sonore
function install_theme_generic() {
    local theme_dir="$1"
    local theme_name="$2"
    
    echo "Configuration générique..."
    
    # Installer dans le dossier système si possible
    local system_sound_dir="/usr/share/sounds"
    if [ -w "$system_sound_dir" ]; then
        sudo cp -r "$theme_dir" "$system_sound_dir/$theme_name" 2>/dev/null && \
        echo "Thème installé dans: $system_sound_dir/$theme_name"
    else
        # Sinon, installer dans le dossier utilisateur
        local user_sound_dir="$HOME/.local/share/sounds"
        mkdir -p "$user_sound_dir"
        cp -r "$theme_dir" "$user_sound_dir/$theme_name"
        echo "Thème installé dans: $user_sound_dir/$theme_name"
    fi
    
    echo "Thème sonore '$theme_name' installé."
    echo "Configurez-le manuellement dans les paramètres de votre bureau."
}

# Fonction pour installer des thèmes sonores supplémentaires
function install_extra_sound_themes() {
    echo -e "\n📦 INSTALLATION DE THÈMES SONORES SUPPLÉMENTAIRES"
    
    # Créer le dossier des thèmes sonores s'il n'existe pas
    SOUND_THEMES_DIR="$REPO_DIR/sound-themes"
    mkdir -p "$SOUND_THEMES_DIR"
    
    echo "Thèmes disponibles:"
    echo "1. Oxygen (KDE classique)"
    echo "2. Sonar (sons modernes)"
    echo "3. WoodenBeaver (sons naturels)"
    echo "4. Custom (téléchargement personnalisé)"
    
    read -p "Votre choix [1-4]: " extra_choice
    
    case "$extra_choice" in
        1)
            # Oxygen (thème classique KDE)
            echo "Téléchargement du thème Oxygen..."
            git clone https://github.com/KDE/oxygen-sound.git "$SOUND_THEMES_DIR/Oxygen" 2>/dev/null || \
            echo "Le thème Oxygen est déjà installé ou erreur de téléchargement"
            ;;
        
        2)
            # Sonar (sons modernes)
            echo "Téléchargement du thème Sonar..."
            wget -q -O /tmp/sonar-sound-theme.tar.gz https://github.com/shimmerproject/Sonar/archive/master.tar.gz
            tar -xzf /tmp/sonar-sound-theme.tar.gz -C "$SOUND_THEMES_DIR" 2>/dev/null && \
            mv "$SOUND_THEMES_DIR/Sonar-master" "$SOUND_THEMES_DIR/Sonar" 2>/dev/null || \
            echo "Le thème Sonar est déjà installé ou erreur de téléchargement"
            rm -f /tmp/sonar-sound-theme.tar.gz
            ;;
        
        3)
            # WoodenBeaver (sons naturels)
            echo "Téléchargement du thème WoodenBeaver..."
            wget -q -O /tmp/woodenbeaver.tar.gz https://github.com/MatMoul/woodenbeaver-sound-theme/archive/master.tar.gz
            tar -xzf /tmp/woodenbeaver.tar.gz -C "$SOUND_THEMES_DIR" 2>/dev/null && \
            mv "$SOUND_THEMES_DIR/woodenbeaver-sound-theme-master" "$SOUND_THEMES_DIR/WoodenBeaver" 2>/dev/null || \
            echo "Le thème WoodenBeaver est déjà installé ou erreur de téléchargement"
            rm -f /tmp/woodenbeaver.tar.gz
            ;;
        
        4)
            # Téléchargement personnalisé
            echo "Téléchargement personnalisé..."
            read -p "URL du thème sonore (archive tar.gz/zip): " custom_url
            if [ -n "$custom_url" ]; then
                read -p "Nom du thème: " theme_name
                if [ -n "$theme_name" ]; then
                    mkdir -p "/tmp/custom_sound_theme"
                    wget -q -O "/tmp/custom_sound_theme/theme_archive" "$custom_url"
                    
                    # Extraire selon le format
                    if file "/tmp/custom_sound_theme/theme_archive" | grep -q "gzip"; then
                        tar -xzf "/tmp/custom_sound_theme/theme_archive" -C "/tmp/custom_sound_theme"
                    elif file "/tmp/custom_sound_theme/theme_archive" | grep -q "Zip"; then
                        unzip -q "/tmp/custom_sound_theme/theme_archive" -d "/tmp/custom_sound_theme"
                    else
                        echo "Format d'archive non reconnu"
                        return 1
                    fi
                    
                    # Trouver le dossier extrait et le copier
                    extracted_dir=$(find "/tmp/custom_sound_theme" -maxdepth 1 -type d ! -name "custom_sound_theme" | head -1)
                    if [ -n "$extracted_dir" ] && [ -d "$extracted_dir" ]; then
                        cp -r "$extracted_dir" "$SOUND_THEMES_DIR/$theme_name"
                        echo "Thème '$theme_name' installé avec succès"
                    else
                        echo "Impossible de trouver les fichiers du thème"
                    fi
                    
                    rm -rf "/tmp/custom_sound_theme"
                fi
            fi
            ;;
        
        *)
            echo "Choix invalide."
            return 1
            ;;
    esac
    
    echo "Thème(s) supplémentaire(s) installé(s). Utilisez l'option 1 pour les configurer."
}

# Fonction pour configurer des sons personnalisés
function configure_custom_sounds() {
    echo -e "\n🎛️ CONFIGURATION DE SONS PERSONNALISÉS"
    
    # Détection de l'environnement
    if pgrep -x "plasmashell" >/dev/null; then
        configure_custom_sounds_kde
    elif pgrep -x "gnome-shell" >/dev/null; then
        configure_custom_sounds_gnome
    else
        echo "Configuration manuelle nécessaire pour votre environnement."
        echo "Placez vos fichiers sonores dans ~/.local/share/sounds/custom/"
        echo "Format: OGG recommandé pour une compatibilité optimale"
    fi
}

# Configuration des sons personnalisés pour KDE
function configure_custom_sounds_kde() {
    echo "Configuration pour KDE Plasma..."
    
    CUSTOM_SOUND_DIR="$HOME/.local/share/sounds/custom"
    mkdir -p "$CUSTOM_SOUND_DIR"
    
    echo "Événements configurables:"
    echo "1.  Login (connexion)"
    echo "2.  Logout (déconnexion)"
    echo "3.  Bell (cloche système)"
    echo "4.  Question (question)"
    echo "5.  Warning (avertissement)"
    echo "6.  Error (erreur)"
    echo "7.  Notification (notification)"
    echo "8.  Trash (corbeille)"
    echo "9.  Screenshot (capture d'écran)"
    echo "10. Son personnalisé (autre événement)"
    
    read -p "Choisissez un événement [1-10]: " event_choice
    
    case "$event_choice" in
        1) event_name="login"; event_desc="Connexion" ;;
        2) event_name="logout"; event_desc="Déconnexion" ;;
        3) event_name="bell"; event_desc="Cloche système" ;;
        4) event_name="question"; event_desc="Question" ;;
        5) event_name="warning"; event_desc="Avertissement" ;;
        6) event_name="error"; event_desc="Erreur" ;;
        7) event_name="notification"; event_desc="Notification" ;;
        8) event_name="trash"; event_desc="Corbeille" ;;
        9) event_name="screenshot"; event_desc="Capture d'écran" ;;
        10) 
            read -p "Nom de l'événement personnalisé: " event_name
            read -p "Description: " event_desc
            ;;
        *) echo "Choix invalide."; return 1 ;;
    esac
    
    # Sélection du fichier sonore
    echo "Sélection du fichier sonore pour $event_desc..."
    sound_file=$(selectionner_fichier_interactif "$HOME" "*.ogg *.wav *.mp3" "Sélectionnez un fichier sonore")
    
    if [ -z "$sound_file" ] || [ ! -f "$sound_file" ]; then
        echo "Aucun fichier sélectionné ou fichier invalide."
        return 1
    fi
    
    # Convertir en OGG si nécessaire (format recommandé)
    file_ext="${sound_file##*.}"
    if [ "${file_ext,,}" != "ogg" ]; then
        echo "Conversion en OGG (format recommandé)..."
        if command -v ffmpeg >/dev/null; then
            converted_file="$CUSTOM_SOUND_DIR/${event_name}.ogg"
            ffmpeg -i "$sound_file" -c:a libvorbis -q:a 4 "$converted_file" 2>/dev/null && \
            sound_file="$converted_file"
            echo "Fichier converti: $converted_file"
        else
            echo "FFmpeg n'est pas installé. Le fichier ne sera pas converti."
            cp "$sound_file" "$CUSTOM_SOUND_DIR/${event_name}.${file_ext}"
            sound_file="$CUSTOM_SOUND_DIR/${event_name}.${file_ext}"
        fi
    else
        cp "$sound_file" "$CUSTOM_SOUND_DIR/${event_name}.ogg"
        sound_file="$CUSTOM_SOUND_DIR/${event_name}.ogg"
    fi
    
    # Configurer KDE pour utiliser ce son
    kwriteconfig5 --file kdeglobals --group "Event Sounds" --key "$event_name" "$sound_file"
    
    echo "Son $event_desc configuré: $(basename "$sound_file")"
}

# Configuration des sons personnalisés pour GNOME
function configure_custom_sounds_gnome() {
    echo "Configuration pour GNOME..."
    
    CUSTOM_SOUND_DIR="$HOME/.local/share/sounds/custom"
    mkdir -p "$CUSTOM_SOUND_DIR"
    
    echo "GNOME utilise un thème sonore complet. Création d'un thème personnalisé..."
    
    # Créer la structure du thème
    THEME_NAME="CustomSounds"
    THEME_DIR="$CUSTOM_SOUND_DIR/$THEME_NAME"
    mkdir -p "$THEME_DIR/stereo"
    
    # Créer le fichier index.theme
    cat > "$THEME_DIR/index.theme" <<EOF
[Sound Theme]
Name=Custom Sounds
Description=Custom sound theme created by BearGrubChanger
Directories=stereo

[stereo]
OutputProfile=stereo
EOF
    
    # Événements configurables
    declare -A gnome_events=(
        ["bell"]="bell-terminal"
        ["dialog-question"]="dialog-question"
        ["dialog-warning"]="dialog-warning"
        ["dialog-error"]="dialog-error"
        ["device-added"]="device-added"
        ["device-removed"]="device-removed"
        ["message"]="message"
        ["trash-empty"]="trash-empty"
        ["window-attention"]="window-attention"
    )
    
    echo "Événements configurables:"
    local i=1
    declare -a event_keys
    for key in "${!gnome_events[@]}"; do
        echo "$i. ${gnome_events[$key]} ($key)"
        event_keys[$i]="$key"
        ((i++))
    done
    echo "$i. Autre événement personnalisé"
    
    read -p "Choisissez un événement [1-$i]: " event_choice
    
    if [ "$event_choice" -eq "$i" ]; then
        read -p "Nom de l'événement GNOME: " event_name
        read -p "Nom du fichier: " file_name
    else
        event_name="${event_keys[$event_choice]}"
        file_name="${gnome_events[$event_name]}"
    fi
    
    # Sélection du fichier sonore
    echo "Sélection du fichier sonore pour $event_name..."
    sound_file=$(selectionner_fichier_interactif "$HOME" "*.ogg *.wav" "Sélectionnez un fichier sonore")
    
    if [ -z "$sound_file" ] || [ ! -f "$sound_file" ]; then
        echo "Aucun fichier sélectionné ou fichier invalide."
        return 1
    fi
    
    # Copier et convertir si nécessaire
    if [ "${sound_file##*.}" != "ogg" ]; then
        if command -v ffmpeg >/dev/null; then
            ffmpeg -i "$sound_file" -c:a libvorbis -q:a 4 "$THEME_DIR/stereo/${file_name}.ogg" 2>/dev/null
            echo "Fichier converti en OGG"
        else
            echo "Conversion non disponible. Utilisez des fichiers OGG pour une compatibilité optimale."
            cp "$sound_file" "$THEME_DIR/stereo/${file_name}.${sound_file##*.}"
        fi
    else
        cp "$sound_file" "$THEME_DIR/stereo/${file_name}.ogg"
    fi
    
    # Configurer GNOME pour utiliser ce thème
    gsettings set org.gnome.desktop.sound theme-name "$THEME_NAME"
    
    echo "Thème personnalisé créé: $THEME_NAME"
    echo "Son '$event_name' configuré: $file_name"
}

# Fonction pour tester les sons actuels
function test_current_sounds() {
    echo -e "\n🔊 TEST DES SONS SYSTÈME ACTUELS"
    
    # Détection de l'environnement
    if pgrep -x "plasmashell" >/dev/null; then
        test_sounds_kde
    elif pgrep -x "gnome-shell" >/dev/null; then
        test_sounds_gnome
    else
        test_sounds_generic
    fi
}

# Tester les sons pour KDE
function test_sounds_kde() {
    echo "Test des sons pour KDE Plasma..."
    
    # Sons à tester
    declare -A test_sounds=(
        ["bell"]="Cloche système"
        ["dialog-information"]="Information"
        ["dialog-warning"]="Avertissement"
        ["dialog-error"]="Erreur"
        ["notification"]="Notification"
    )
    
    for sound in "${!test_sounds[@]}"; do
        echo -n "Test: ${test_sounds[$sound]}... "
        sound_file=$(kreadconfig5 --file kdeglobals --group "Event Sounds" --key "$sound")
        
        if [ -n "$sound_file" ] && [ -f "$sound_file" ]; then
            timeout 3 paplay "$sound_file" 2>/dev/null &
            echo "✓"
        else
            echo "✗ (non configuré)"
        fi
        
        sleep 1
    done
}

# Tester les sons pour GNOME
function test_sounds_gnome() {
    echo "Test des sons pour GNOME..."
    
    # Utiliser canberra-gtk-play pour tester les sons système
    if command -v canberra-gtk-play >/dev/null; then
        echo "Test des sons GNOME avec canberra-gtk-play..."
        
        canberra-gtk-play --id="bell" 2>/dev/null && echo "Cloche système: ✓" || echo "Cloche système: ✗"
        sleep 1
        canberra-gtk-play --id="dialog-information" 2>/dev/null && echo "Information: ✓" || echo "Information: ✗"
        sleep 1
        canberra-gtk-play --id="dialog-warning" 2>/dev/null && echo "Avertissement: ✓" || echo "Avertissement: ✗"
        sleep 1
        canberra-gtk-play --id="dialog-error" 2>/dev/null && echo "Erreur: ✓" || echo "Erreur: ✗"
        sleep 1
        canberra-gtk-play --id="complete" 2>/dev/null && echo "Complete: ✓" || echo "Complete: ✗"
    else
        echo "canberra-gtk-play n'est pas installé. Impossible de tester les sons."
    fi
}

# Test générique de sons
function test_sounds_generic() {
    echo "Test générique des sons..."
    
    # Essayer de jouer un son de test si possible
    if command -v paplay >/dev/null; then
        # Chercher un fichier sonore de test
        test_file=$(find /usr/share/sounds -name "*.ogg" -o -name "*.wav" 2>/dev/null | head -1)
        
        if [ -n "$test_file" ] && [ -f "$test_file" ]; then
            echo "Test avec: $(basename "$test_file")"
            timeout 3 paplay "$test_file" 2>/dev/null && \
            echo "Sortie audio fonctionnelle ✓" || \
            echo "Erreur de lecture audio ✗"
        else
            echo "Aucun fichier sonore de test trouvé."
        fi
    else
        echo "paplay n'est pas disponible. Impossible de tester l'audio."
    fi
}

# Installer NerdFonts automatiquement
function installer_nerdfonts() {
    echo -e "\nINSTALLATION DE NERD FONTS"
    mkdir -p ~/.local/share/fonts
    wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip -O /tmp/Hack.zip
    unzip -o /tmp/Hack.zip -d ~/.local/share/fonts/
    fc-cache -fv
    echo "NerdFonts Hack installé."
}

# Wallpapers animés avec mpv
function wallpaper_video() {
    echo -e "\nWALLPAPER VIDÉO POUR KDE PLASMA"
    
    # Vérifier que KDE Plasma est bien détecté
    if ! pgrep -x "plasmashell" >/dev/null; then
        echo "KDE Plasma n'est pas détecté comme environnement actuel"
        echo "Cette fonctionnalité est spécifique à KDE Plasma"
        return 1
    fi
    
    # Vérifier les dépendances
    if ! command -v mpv >/dev/null; then
        echo "Installation de MPV..."
        if command -v apt >/dev/null; then
            sudo apt install mpv -y
        elif command -v pacman >/dev/null; then
            sudo pacman -S mpv --noconfirm
        elif command -v dnf >/dev/null; then
            sudo dnf install mpv -y
        else
            echo "Impossible d'installer MPV automatiquement"
            return 1
        fi
    fi
    
    if ! command -v mpvpaper >/dev/null; then
        echo "Installation de mpvpaper..."
        # Essayer d'abord avec les gestionnaires de paquets
        if command -v apt >/dev/null; then
            sudo add-apt-repository ppa:flexiondotorg/mpvpaper -y
            sudo apt update
            sudo apt install mpvpaper -y
        elif command -v pacman >/dev/null; then
            # Installation depuis AUR
            if command -v yay >/dev/null; then
                yay -S mpvpaper --noconfirm
            elif command -v paru >/dev/null; then
                paru -S mpvpaper --noconfirm
            else
                # Installation manuelle depuis GitHub
                echo "Installation manuelle de mpvpaper..."
                git clone https://github.com/GhostNaN/mpvpaper.git /tmp/mpvpaper
                cd /tmp/mpvpaper
                mkdir build && cd build
                cmake ..
                make
                sudo make install
            fi
        elif command -v dnf >/dev/null; then
            # Pour Fedora, installation depuis COPR
            sudo dnf copr enable lukenukem/mpvpaper -y
            sudo dnf install mpvpaper -y
        else
            echo "Distribution non supportée pour l'installation automatique"
            echo "Veuillez installer mpvpaper manuellement"
            return 1
        fi
    fi
    
    # Définir les dossiers vidéos possibles
    VIDEOS_DIRS=("$HOME/Videos" "$HOME/Vidéos" "$HOME/Downloads" "$HOME/Téléchargements" "$HOME/Desktop" "$HOME/Bureau")
    VIDEOS_DIR=""
    
    # Trouver le premier dossier qui existe
    for dir in "${VIDEOS_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            VIDEOS_DIR="$dir"
            break
        fi
    done
    
    if [ -z "$VIDEOS_DIR" ]; then
        VIDEOS_DIR="$HOME"
    fi
    
    echo "Dossiers vidéos détectés:"
    echo "   $VIDEOS_DIR"
    
    # Options disponibles
    echo -e "\nOptions disponibles:"
    echo "1. Sélectionner une vidéo existante"
    echo "2. Télécharger une vidéo depuis YouTube"
    echo "3. Utiliser un GIF animé"
    echo "4. Annuler"
    
    read -p "Votre choix [1-4]: " choice
    
    case "$choice" in
        1)
            # Sélectionner une vidéo existante
            echo -e "\nSÉLECTION D'UNE VIDÉO EXISTANTE"
            echo "Formats supportés: mp4, webm, mkv, avi, mov, flv, gif"
            
            # Méthode 1: Lister les vidéos disponibles directement
            echo -e "\nRecherche de vidéos dans les dossiers courants..."
            declare -a video_files
            
            # Recherche de vidéos dans plusieurs dossiers
            while IFS= read -r -d $'\0' file; do
                video_files+=("$file")
            done < <(find "${VIDEOS_DIRS[@]}" "$HOME/Downloads" "$HOME/Téléchargements" "$HOME/Desktop" "$HOME/Bureau" 2>/dev/null -maxdepth 2 -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.gif" \) -print0 2>/dev/null | head -20)
            
            if [ ${#video_files[@]} -gt 0 ]; then
                echo -e "\n VIDÉOS DÉTECTÉES :"
                for i in "${!video_files[@]}"; do
                    size=$(du -h "${video_files[$i]}" 2>/dev/null | cut -f1)
                    echo "$((i+1)). $(basename "${video_files[$i]}") - $size"
                    echo " ${video_files[$i]}"
                done
                echo "$((${#video_files[@]}+1)). Saisir un chemin manuellement"
                echo "$((${#video_files[@]}+2)). Parcourir avec l'explorateur de fichiers"
                
                read -p "Choisissez une vidéo [1-$((${#video_files[@]}+2))]: " video_choice
                
                if [[ "$video_choice" =~ ^[0-9]+$ ]] && ((video_choice >= 1 && video_choice <= ${#video_files[@]})); then
                    video_path="${video_files[$((video_choice-1))]}"
                elif [ "$video_choice" = "$((${#video_files[@]}+1))" ]; then
                    read -p "Chemin complet vers la vidéo : " video_path
                elif [ "$video_choice" = "$((${#video_files[@]}+2))" ]; then
                    # Ouvrir l'explorateur en arrière-plan (sans attendre)
                    echo "Ouverture de l'explorateur..."
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
                    read -p "Chemin complet vers la vidéo : " video_path
                else
                    echo "Choix invalide"
                    return 1
                fi
            else
                echo "Aucune vidéo détectée automatiquement"
                echo "Ouverture de l'explorateur pour sélection manuelle..."
                
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
                read -p "Chemin complet vers la vidéo : " video_path
            fi
            ;;
        
        2)
            # Télécharger depuis YouTube
            echo -e "\nTÉLÉCHARGEMENT DEPUIS YOUTUBE"
            read -p "URL de la vidéo YouTube : " youtube_url
            
            if [ -z "$youtube_url" ]; then
                echo "URL vide"
                return 1
            fi
            
            # Vérifier si yt-dlp est installé
            if ! command -v yt-dlp >/dev/null && ! command -v youtube-dl >/dev/null; then
                echo "Installation de yt-dlp..."
                if command -v apt >/dev/null; then
                    sudo apt install yt-dlp -y
                elif command -v pacman >/dev/null; then
                    sudo pacman -S yt-dlp --noconfirm
                elif command -v dnf >/dev/null; then
                    sudo dnf install yt-dlp -y
                else
                    sudo pip3 install yt-dlp
                fi
            fi
            
            # Dossier de téléchargement
            DOWNLOAD_DIR="$HOME/Téléchargements/WallpaperVideos"
            mkdir -p "$DOWNLOAD_DIR"
            
            echo "Téléchargement en cours..."
            if command -v yt-dlp >/dev/null; then
                yt-dlp -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --merge-output-format mp4 -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" "$youtube_url"
            else
                youtube-dl -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" "$youtube_url"
            fi
            
            # Trouver le fichier téléchargé
            video_path=$(find "$DOWNLOAD_DIR" -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" | head -1)
            
            if [ -z "$video_path" ]; then
                echo "Échec du téléchargement"
                return 1
            fi
            
            echo "Vidéo téléchargée: $video_path"
            ;;
        
        3)
            # Utiliser un GIF animé
            echo -e "\nUTILISATION D'UN GIF ANIMÉ"
            echo "Recherche de GIFs dans les dossiers courants..."
            
            declare -a gif_files
            while IFS= read -r -d $'\0' file; do
                gif_files+=("$file")
            done < <(find "${VIDEOS_DIRS[@]}" "$HOME/Downloads" "$HOME/Téléchargements" "$HOME/Desktop" "$HOME/Bureau" 2>/dev/null -maxdepth 2 -type f -iname "*.gif" -print0 2>/dev/null | head -10)
            
            if [ ${#gif_files[@]} -gt 0 ]; then
                echo -e "\n GIFS DÉTECTÉS :"
                for i in "${!gif_files[@]}"; do
                    size=$(du -h "${gif_files[$i]}" 2>/dev/null | cut -f1)
                    echo "$((i+1)). $(basename "${gif_files[$i]}") - $size"
                done
                echo "$((${#gif_files[@]}+1)). Saisir un chemin manuellement"
                
                read -p "Choisissez un GIF [1-$((${#gif_files[@]}+1))]: " gif_choice
                
                if [[ "$gif_choice" =~ ^[0-9]+$ ]] && ((gif_choice >= 1 && gif_choice <= ${#gif_files[@]})); then
                    video_path="${gif_files[$((gif_choice-1))]}"
                elif [ "$gif_choice" = "$((${#gif_files[@]}+1))" ]; then
                    read -p "Chemin complet vers le GIF : " video_path
                else
                    echo "Choix invalide"
                    return 1
                fi
            else
                echo "Aucun GIF détecté automatiquement"
                read -p "Chemin complet vers le GIF : " video_path
            fi
            ;;
        
        4)
            echo "Opération annulée"
            return 0
            ;;
        
        *)
            echo "Choix invalide"
            return 1
            ;;
    esac
    
    # Vérifier que le fichier existe et est une vidéo/GIF
    if [ ! -f "$video_path" ]; then
        echo "Fichier non trouvé : $video_path"
        return 1
    fi
    
    # Vérifier l'extension
    file_extension="${video_path##*.}"
    case "${file_extension,,}" in
        mp4|webm|mkv|avi|mov|flv|gif)
            echo "Format supporté détecté: $file_extension"
            ;;
        *)
            echo "Format non supporté: $file_extension"
            echo "Formats supportés: mp4, webm, mkv, avi, mov, flv, gif"
            return 1
            ;;
    esac
    
    # Vérifier la taille du fichier
    file_size=$(du -m "$video_path" | cut -f1)
    if [ "$file_size" -gt 100 ]; then
        echo "Attention: Fichier volumineux ($file_size Mo)"
        echo "Recommandation: utilisez des fichiers < 50 Mo pour des performances optimales"
        read -p "Continuer quand même ? [y/N]: " continuer
        if [[ ! "$continuer" =~ ^[Yy]$ ]]; then
            echo "Opération annulée"
            return 1
        fi
    fi
    
    local video_name=$(basename "$video_path")
    
    echo -e "\n CONFIGURATION DU FOND D'ÉCRAN VIDÉO POUR '$video_name'"
    
    # Arrêter les instances précédentes de mpvpaper
    echo "Arrêt des instances mpvpaper existantes..."
    pkill -f "mpvpaper" 2>/dev/null || true
    sleep 1
    
    # Options de configuration
    echo -e "\nOptions de configuration:"
    echo "1. Lecture normale (avec son)"
    echo "2. Lecture silencieuse (recommandé pour fond d'écran)"
    echo "3. Personnaliser les options"
    
    read -p "Choix [1-3]: " config_choice
    
    case "$config_choice" in
        1)
            mpv_options="--loop"
            ;;
        2)
            mpv_options="--loop --no-audio"
            ;;
        3)
            echo "Options MPV disponibles (séparées par des espaces):"
            echo "Exemples: --loop --no-audio --hwdec=auto --profile=low-latency"
            read -p "Options personnalisées: " custom_options
            mpv_options="$custom_options"
            ;;
        *)
            mpv_options="--loop --no-audio"
            ;;
    esac
    
    # Démarrer mpvpaper
    echo "Lancement de mpvpaper avec les options: $mpv_options"
    
    # Essayer différentes méthodes pour identifier l'écran
    SCREEN_OUTPUT="*"  # Par défaut, tous les écrans
    
    # Méthode 1: Utiliser l'environnement WAYLAND_DISPLAY si Wayland
    if [ -n "$WAYLAND_DISPLAY" ]; then
        echo "Environnement Wayland détecté"
        # Pour Wayland, on utilise généralement wlroots ou similar
        SCREEN_OUTPUT="wayland"
    fi
    
    # Méthode 2: Utiliser xrandr pour X11
    if command -v xrandr >/dev/null && [ -z "$WAYLAND_DISPLAY" ]; then
        echo "Environnement X11 détecté"
        # Prendre le premier écran détecté
        SCREEN_OUTPUT=$(xrandr --listmonitors | awk 'NR==2 {print $4}' | sed 's/+.*//')
        if [ -z "$SCREEN_OUTPUT" ]; then
            SCREEN_OUTPUT="*"
        fi
    fi
    
    # Lancer mpvpaper en arrière-plan
    nohup mpvpaper -o "$mpv_options" "$SCREEN_OUTPUT" "$video_path" >/dev/null 2>&1 &
    
    # Attendre un peu pour vérifier que le processus a démarré
    sleep 2
    
    # Vérifier que mpvpaper est en cours d'exécution
    if pgrep -f "mpvpaper" >/dev/null; then
        echo -e "\n✅ FOND D'ÉCRAN VIDÉO ACTIVÉ AVEC SUCCÈS !"
        echo "Vidéo: $video_name"
        echo "Processus mpvpaper en cours d'exécution"
        
        # Créer un script de redémarrage automatique
        SCRIPT_DIR="$HOME/.config/mpvpaper"
        mkdir -p "$SCRIPT_DIR"
        
        cat > "$SCRIPT_DIR/restart_wallpaper.sh" <<EOF
#!/bin/bash
# Script de redémarrage automatique du wallpaper vidéo
pkill -f "mpvpaper"
sleep 1
nohup mpvpaper -o "$mpv_options" "$SCREEN_OUTPUT" "$video_path" >/dev/null 2>&1 &
EOF
        
        chmod +x "$SCRIPT_DIR/restart_wallpaper.sh"
        
        # Ajouter au démarrage automatique si demandé
        read -p "Voulez-vous démarrer automatiquement au login ? [y/N]: " autostart
        if [[ "$autostart" =~ ^[Yy]$ ]]; then
            AUTOSTART_DIR="$HOME/.config/autostart"
            mkdir -p "$AUTOSTART_DIR"
            
            cat > "$AUTOSTART_DIR/mpvpaper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MPVPaper Wallpaper
Exec=$SCRIPT_DIR/restart_wallpaper.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
            
            echo "Démarrage automatique configuré"
        fi
        
        echo -e "\nCommandes utiles:"
        echo "  pkill -f mpvpaper          # Arrêter le fond d'écran vidéo"
        echo "  $SCRIPT_DIR/restart_wallpaper.sh  # Redémarrer le fond d'écran"
        
    else
        echo -e "\n❌ ERREUR: mpvpaper n'a pas pu démarrer"
        echo "Vérifiez que:"
        echo "1. mpvpaper est correctement installé"
        echo "2. Le fichier vidéo est accessible"
        echo "3. Vous utilisez un environnement de bureau supporté"
        return 1
    fi
    
    # Attendre un peu pour que l'utilisateur voie le message
    sleep 3
    
    return 0
}

# MODE GAMING
function mode_gaming() {
    echo -e "\nMODE GAMING"
    echo "1. Activer mode gaming (perf max)"
    echo "2. Désactiver mode gaming (restaurer services)"
    read -p "Choix : " opt
    case "$opt" in
        1)
            echo "Activation du mode performance..."
            sudo systemctl stop bluetooth cups baloo-file
            if command -v cpupower >/dev/null; then
                sudo cpupower frequency-set -g performance
            elif command -v powerprofilesctl >/dev/null; then
                sudo powerprofilesctl set performance
            fi
            ;;
        2)
            echo "Restauration des services..."
            sudo systemctl start bluetooth cups baloo-file
            if command -v cpupower >/dev/null; then
                sudo cpupower frequency-set -g schedutil
            elif command -v powerprofilesctl >/dev/null; then
                sudo powerprofilesctl set balanced
            fi
            ;;
    esac
}

# GESTIONNAIRE DE THEMES
function gestionnaire_themes() {
    echo -e "\nGESTIONNAIRE DE THEMES"
    echo "1. GRUB"
    echo "2. Plymouth"
    echo "3. SDDM"
    echo "4. Icônes système"
    read -p "Choix : " cat
    case "$cat" in
        1) dossier="/boot/grub/themes" ;;
        2) dossier="/usr/share/plymouth/themes" ;;
        3) dossier="/usr/share/sddm/themes" ;;
        4) dossier="/usr/share/icons" ;;
        *) echo "Invalide" ; return ;;
    esac

    echo "Thèmes disponibles dans $dossier :"
    ls "$dossier"
    read -p "Nom du thème à appliquer : " theme

    if [ "$cat" -eq 1 ]; then
        sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=$dossier/$theme/theme.txt|" /etc/default/grub
        sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
    elif [ "$cat" -eq 2 ]; then
        sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$dossier/$theme/$theme.plymouth" 100
        sudo update-alternatives --set default.plymouth "$dossier/$theme/$theme.plymouth"
        sudo update-initramfs -u
    elif [ "$cat" -eq 3 ]; then
        sudo sed -i "s|^Current=.*|Current=$theme|" /etc/sddm.conf
    elif [ "$cat" -eq 4 ]; then
        gsettings set org.gnome.desktop.interface icon-theme "$theme" 2>/dev/null
        kwriteconfig5 --file kdeglobals --group Icons --key Theme "$theme"
    fi

    echo "Thème $theme appliqué."
}

# OPTIMISATION LAPTOP
function mode_laptop() {
    echo -e "\nMODE LAPTOP"
    echo "1. Économie d'énergie"
    echo "2. Performance maximale"
    read -p "Choix : " opt
    case "$opt" in
        1)
            echo "Mode économie activé"
            if command -v cpupower >/dev/null; then
                sudo cpupower frequency-set -g powersave
            elif command -v powerprofilesctl >/dev/null; then
                sudo powerprofilesctl set power-saver
            fi
            ;;
        2)
            echo "Mode performance activé"
            if command -v cpupower >/dev/null; then
                sudo cpupower frequency-set -g performance
            elif command -v powerprofilesctl >/dev/null; then
                sudo powerprofilesctl set performance
            fi
            ;;
    esac
}

# Télécharger musique Spotify/YouTube
function telecharger_musique() {
    echo -e "\nTELECHARGER MUSIQUE (Spotify / YouTube)"
    read -p "Lien du morceau/playlist : " url
    mkdir -p ~/Music/BearGrubChanger
    if command -v spotdl >/dev/null; then
        spotdl "$url" --output ~/Music/BearGrubChanger/
    else
        echo "Installez spotdl (pip install spotdl)"
        return 1
    fi
    echo "Musique téléchargée dans ~/Music/BearGrubChanger/"
}

function choisir_logo_os() {
    echo -e "\nLOGOS D'OS DISPONIBLES:"
    echo "1. Arch Linux"
    echo "2. Ubuntu"
    echo "3. Debian"
    echo "4. Fedora"
    echo "5. Windows"
    echo "6. macOS"
    echo "7. Linux Mint"
    echo "8. Manjaro"
    echo "9. Pop!_OS"
    echo "10. Autre (saisir manuellement)"
    
    read -p "Choisissez un OS [1-10]: " os_choice
    
    case "$os_choice" in
        1) logo_name="arch" ;;
        2) logo_name="ubuntu" ;;
        3) logo_name="debian" ;;
        4) logo_name="fedora" ;;
        5) logo_name="windows" ;;
        6) logo_name="macos" ;;
        7) logo_name="mint" ;;
        8) logo_name="manjaro" ;;
        9) logo_name="popos" ;;
        10) 
            read -p "Nom du logo Fastfetch (ex: alpine, gentoo, nixos): " logo_name
            ;;
        *) echo "Choix invalide"; return 1 ;;
    esac
    
    # Configurer le logo dans la configuration
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    cat > "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
{
    "logo": {
        "type": "$logo_name",
        "width": 60,
        "height": 30,
        "padding": {
            "top": 1,
            "left": 2
        }
    }
}
EOF
}

function configurer_pokemon_aleatoire() {
    echo -e "\nPOKÉMON ALÉATOIRE À CHAQUE LANCEMENT"
    
    # Cloner le dépôt Pokémon si nécessaire
    POKEMON_DIR="/tmp/pokemon-terminal"
    if [ ! -d "$POKEMON_DIR" ]; then
        echo "Téléchargement des sprites Pokémon..."
        git clone --depth=1 https://github.com/LazoCoder/Pokemon-Terminal.git "$POKEMON_DIR" 2>/dev/null || {
            echo "Échec du téléchargement. Utilisation des sprites locaux si disponibles."
        }
    fi
    
    # Créer le script de sélection aléatoire
    cat > "$FASTFETCH_CONFIG_DIR/pokemon_random.sh" <<'EOF'
#!/bin/bash

POKEMON_DIR="/tmp/pokemon-terminal"
CONFIG_FILE="$HOME/.config/fastfetch/config.jsonc"

# Liste de tous les Pokémon disponibles (générations 1-8)
declare -a pokemon_list=(
    "bulbasaur" "ivysaur" "venusaur" "charmander" "charmeleon" "charizard"
    "squirtle" "wartortle" "blastoise" "caterpie" "metapod" "butterfree"
    "weedle" "kakuna" "beedrill" "pidgey" "pidgeotto" "pidgeot"
    "rattata" "raticate" "spearow" "fearow" "ekans" "arbok"
    "pikachu" "raichu" "sandshrew" "sandslash" "nidoran-f" "nidorina"
    "nidoqueen" "nidoran-m" "nidorino" "nidoking" "clefairy" "clefable"
    "vulpix" "ninetales" "jigglypuff" "wigglytuff" "zubat" "golbat"
    "oddish" "gloom" "vileplume" "paras" "parasect" "venonat"
    "venomoth" "diglett" "dugtrio" "meowth" "persian" "psyduck"
    "golduck" "mankey" "primeape" "growlithe" "arcanine" "poliwag"
    "poliwhirl" "poliwrath" "abra" "kadabra" "alakazam" "machop"
    "machoke" "machamp" "bellsprout" "weepinbell" "victreebel" "tentacool"
    "tentacruel" "geodude" "graveler" "golem" "ponyta" "rapidash"
    "slowpoke" "slowbro" "magnemite" "magneton" "farfetchd" "doduo"
    "dodrio" "seel" "dewgong" "grimer" "muk" "shellder"
    "cloyster" "gastly" "haunter" "gengar" "onix" "drowzee"
    "hypno" "krabby" "kingler" "voltorb" "electrode" "exeggcute"
    "exeggutor" "cubone" "marowak" "hitmonlee" "hitmonchan" "lickitung"
    "koffing" "weezing" "rhyhorn" "rhydon" "chansey" "tangela"
    "kangaskhan" "horsea" "seadra" "goldeen" "seaking" "staryu"
    "starmie" "mr-mime" "scyther" "jynx" "electabuzz" "magmar"
    "pinsir" "tauros" "magikarp" "gyarados" "lapras" "ditto"
    "eevee" "vaporeon" "jolteon" "flareon" "porygon" "omanyte"
    "omastar" "kabuto" "kabutops" "aerodactyl" "snorlax" "articuno"
    "zapdos" "mewtwo" "mew"
)

# Sélectionner un Pokémon aléatoire
random_pokemon="${pokemon_list[$RANDOM % ${#pokemon_list[@]}]}"

# Créer la configuration avec le Pokémon aléatoire
cat > "$CONFIG_FILE" <<FASTFETCH_CONFIG
{
    "logo": {
        "type": "$random_pokemon",
        "width": 60,
        "height": 30,
        "padding": {
            "top": 1,
            "left": 2
        }
    },
    "display": {
        "color": {
            "keys": "blue",
            "title": "yellow"
        }
    }
}
FASTFETCH_CONFIG

echo "Pokémon sélectionné: $random_pokemon"
EOF
    
    chmod +x "$FASTFETCH_CONFIG_DIR/pokemon_random.sh"
    
    # Créer un alias pour lancer avec Pokémon aléatoire
    echo "alias fastfetch-pokemon='$FASTFETCH_CONFIG_DIR/pokemon_random.sh && fastfetch'" >> ~/.bashrc
    echo "Alias créé: fastfetch-pokemon"
    
    # Test immédiat
    "$FASTFETCH_CONFIG_DIR/pokemon_random.sh"
    fastfetch
}

function choisir_image_personnalisee() {
    echo -e "\nIMAGE PERSONNALISÉE"
    echo "Sélectionnez une image pour Fastfetch:"
    
    # Ouvrir l'explorateur de fichiers
    image_path=$(selectionner_fichier_interactif "$HOME" "*.png *.jpg *.jpeg *.gif" "Sélectionnez une image")
    
    if [ -z "$image_path" ] || [ ! -f "$image_path" ]; then
        echo "Aucune image sélectionnée ou fichier invalide"
        return 1
    fi
    
    # Convertir l'image pour Fastfetch
    mkdir -p "$FASTFETCH_LOGOS_DIR"
    output_image="$FASTFETCH_LOGOS_DIR/custom_$(date +%s).png"
    
    convertir_image_fastfetch "$image_path" "$output_image" 60 30
    
    # Configurer Fastfetch pour utiliser l'image
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    cat > "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
{
    "logo": {
        "source": "$output_image",
        "width": 60,
        "height": 30,
        "padding": {
            "top": 1,
            "left": 2
        }
    }
}
EOF
    
    echo "Image configurée: $(basename "$output_image")"
}

function convertir_image_ascii() {
    echo -e "\nCONVERSION IMAGE VERS ASCII ART"
    
    # Sélectionner l'image
    image_path=$(selectionner_fichier_interactif "$HOME" "*.png *.jpg *.jpeg" "Sélectionnez une image à convertir")
    
    if [ -z "$image_path" ] || [ ! -f "$image_path" ]; then
        echo "Aucune image sélectionnée"
        return 1
    fi
    
    # Vérifier et installer ImageMagick si nécessaire
    if ! command -v convert >/dev/null; then
        echo "Installation d'ImageMagick..."
        sudo apt install imagemagick -y || sudo pacman -S imagemagick --noconfirm || sudo dnf install ImageMagick -y
    fi
    
    # Convertir l'image en ASCII art
    echo "Conversion en cours..."
    ascii_art=$(convert "$image_path" -resize 60x30 -colors 16 -define txt:compliance=SVG txt:- 2>/dev/null | \
                grep -Eo '#[0-9A-F]{6}' | \
                awk '{printf "\\033[38;2;%d;%d;%dm█\\033[0m", \
                strtonum("0x" substr($1,2,2)), \
                strtonum("0x" substr($1,4,2)), \
                strtonum("0x" substr($1,6,2))}')
    
    # Sauvegarder l'ASCII art
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    echo "$ascii_art" > "$FASTFETCH_CONFIG_DIR/ascii_art.txt"
    
    # Configurer Fastfetch
    cat > "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
{
    "logo": {
        "type": "ascii",
        "source": "$FASTFETCH_CONFIG_DIR/ascii_art.txt",
        "width": 60,
        "height": 30,
        "padding": {
            "top": 1,
            "left": 2
        }
    }
}
EOF
    
    echo "Image convertie en ASCII art avec succès!"
}

function saisir_ascii_personnalise() {
    echo -e "\nASCII ART PERSONNALISÉ"
    echo "Collez votre ASCII art (Ctrl+D pour terminer):"
    echo "Note: Utilisez des caractères ASCII standard pour de meilleurs résultats"
    
    # Lire l'ASCII art multiligne
    ascii_art=$(cat)
    
    if [ -z "$ascii_art" ]; then
        echo "Aucun ASCII art saisi"
        return 1
    fi
    
    # Sauvegarder l'ASCII art
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    echo "$ascii_art" > "$FASTFETCH_CONFIG_DIR/custom_ascii.txt"
    
    # Configurer Fastfetch
    cat > "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
{
    "logo": {
        "type": "ascii",
        "source": "$FASTFETCH_CONFIG_DIR/custom_ascii.txt",
        "width": 60,
        "height": 30,
        "padding": {
            "top": 1,
            "left": 2
        }
    }
}
EOF
    
    echo "ASCII art personnalisé configuré avec succès!"
}

function gerer_modules_fastfetch() {
    echo -e "\nGESTION DES MODULES FASTFETCH"
    
    # Modules disponibles dans Fastfetch
    declare -a all_modules=(
        "title" "separator" "os" "host" "kernel" "uptime" "packages"
        "shell" "display" "de" "wm" "wmtheme" "theme" "icons" "font"
        "cursor" "terminal" "terminalfont" "cpu" "gpu" "memory" "disk"
        "localip" "battery" "locale" "break" "colors" "publicip" "weather"
        "song" "player" "media" "datetime" "datetimecustom" "custom"
    )
    
    # Récupérer les modules actuellement activés
    declare -a current_modules
    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        current_modules=($(grep -A 30 '"modules":' "$FASTFETCH_CONFIG_DIR/config.jsonc" | \
                         grep -E '"[a-z]+"' | tr -d '",[]' | xargs))
    fi
    
    while true; do
        echo -e "\n=== MODULES FASTFETCH ==="
        echo "Modules disponibles (tapez les numéros pour activer/désactiver):"
        echo "---------------------------------------------------------------"
        
        # Afficher tous les modules avec leur statut
        for i in "${!all_modules[@]}"; do
            local module="${all_modules[$i]}"
            local status="(désactivé)"
            
            # Vérifier si le module est actif
            for current in "${current_modules[@]}"; do
                if [ "$current" = "$module" ]; then
                    status="(activé)"
                    break
                fi
            done
            
            printf "%2d. %-20s %s\n" $((i+1)) "$module" "$status"
        done
        
        echo "---------------------------------------------------------------"
        echo "T.  TOUT ACTIVER (tous les modules)"
        echo "D.  TOUT DÉSACTIVER (modules par défaut seulement)"
        echo "A.  APPLIQUER les changements"
        echo "Q.  QUITTER sans appliquer"
        echo "---------------------------------------------------------------"
        
        read -p "Votre choix (numéros séparés par des espaces ou lettre): " input
        
        # Quitter
        if [[ "$input" =~ ^[Qq]$ ]]; then
            echo "Annulation des modifications."
            return 0
        fi
        
        # Appliquer les changements
        if [[ "$input" =~ ^[Aa]$ ]]; then
            update_modules_config "${current_modules[@]}"
            echo "Configuration appliquée avec succès!"
            read -p "Appuyez sur Entrée pour continuer..."
            return 0
        fi
        
        # Activer tous les modules
        if [[ "$input" =~ ^[Tt]$ ]]; then
            current_modules=("${all_modules[@]}")
            echo "Tous les modules ont été activés."
            read -p "Appuyez sur Entrée pour continuer..."
            continue
        fi
        
        # Désactiver tous les modules (réinitialiser aux valeurs par défaut)
        if [[ "$input" =~ ^[Dd]$ ]]; then
            declare -a default_modules=(
                "title" "separator" "os" "host" "kernel" "uptime" "packages"
                "shell" "display" "de" "wm" "wmtheme" "theme" "icons" "font"
                "cursor" "terminal" "terminalfont" "cpu" "gpu" "memory" "disk"
                "localip" "battery" "locale" "break" "colors"
            )
            current_modules=("${default_modules[@]}")
            echo "Modules réinitialisés aux valeurs par défaut."
            read -p "Appuyez sur Entrée pour continuer..."
            continue
        fi
        
        # Traiter la sélection de modules
        if [[ "$input" =~ ^[0-9\ ]+$ ]]; then
            local modified=0
            
            # Traiter chaque numéro saisi
            for num in $input; do
                # Vérifier si le numéro est valide
                if [ "$num" -ge 1 ] && [ "$num" -le ${#all_modules[@]} ]; then
                    local module_index=$((num-1))
                    local module="${all_modules[$module_index]}"
                    local found=0
                    
                    # Vérifier si le module est déjà dans la liste actuelle
                    for i in "${!current_modules[@]}"; do
                        if [ "${current_modules[$i]}" = "$module" ]; then
                            # Module trouvé, le retirer (désactiver)
                            unset 'current_modules[i]'
                            echo "Module désactivé: $module"
                            found=1
                            modified=1
                            break
                        fi
                    done
                    
                    # Si le module n'était pas trouvé, l'ajouter (activer)
                    if [ "$found" -eq 0 ]; then
                        current_modules+=("$module")
                        echo "Module activé: $module"
                        modified=1
                    fi
                else
                    echo "Numéro invalide: $num (doit être entre 1 et ${#all_modules[@]})"
                fi
            done
            
            # Réindexer le tableau pour éviter les trous
            if [ "$modified" -eq 1 ]; then
                current_modules=("${current_modules[@]}")
                echo "Modifications enregistrées. Appuyez sur 'A' pour appliquer."
            fi
            
            read -p "Appuyez sur Entrée pour continuer..."
        else
            echo "Saisie invalide. Veuillez entrer des numéros ou une lettre."
            read -p "Appuyez sur Entrée pour continuer..."
        fi
    done
}

function supprimer_modules() {
    echo -e "\nSUPPRESSION DE MODULES"
    
    # Lire les modules actuels
    current_modules=()
    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        current_modules=($(grep -A 20 '"modules":' "$FASTFETCH_CONFIG_DIR/config.jsonc" | \
                         grep -E '"[a-z]+"' | tr -d '",[]'))
    fi
    
    if [ ${#current_modules[@]} -eq 0 ]; then
        echo "Aucun module configuré"
        return 1
    fi
    
    echo "Modules actuels:"
    for i in "${!current_modules[@]}"; do
        echo "$((i+1)). ${current_modules[$i]}"
    done
    
    read -p "Numéros des modules à supprimer (séparés par des espaces): " modules_to_remove
    
    # Filtrer les modules
    new_modules=()
    for i in "${!current_modules[@]}"; do
        if [[ ! " $modules_to_remove " == *" $((i+1)) "* ]]; then
            new_modules+=("${current_modules[$i]}")
        fi
    done
    
    # Mettre à jour la configuration
    update_modules_config "${new_modules[@]}"
    echo "Modules supprimés avec succès!"
}

function ajouter_modules() {
    echo -e "\nAJOUT DE MODULES"
    
    # Modules disponibles
    declare -a all_modules=(
        "title" "separator" "os" "host" "kernel" "uptime" "packages"
        "shell" "display" "de" "wm" "wmtheme" "theme" "icons" "font"
        "cursor" "terminal" "terminalfont" "cpu" "gpu" "memory" "disk"
        "localip" "battery" "locale" "break" "colors" "publicip" "weather"
        "song" "player" "media" "datetime" "datetimecustom" "custom"
    )
    
    # Lire les modules actuels
    current_modules=()
    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        current_modules=($(grep -A 20 '"modules":' "$FASTFETCH_CONFIG_DIR/config.jsonc" | \
                         grep -E '"[a-z]+"' | tr -d '",[]'))
    fi
    
    echo "Modules disponibles:"
    for i in "${!all_modules[@]}"; do
        # Vérifier si le module est déjà présent
        present=""
        for module in "${current_modules[@]}"; do
            if [ "$module" = "${all_modules[$i]}" ]; then
                present=" (déjà présent)"
                break
            fi
        done
        printf "%2d. %-15s%s\n" $((i+1)) "${all_modules[$i]}" "$present"
    done
    
    read -p "Numéros des modules à ajouter (séparés par des espaces): " modules_to_add
    
    # Ajouter les nouveaux modules
    new_modules=("${current_modules[@]}")
    for num in $modules_to_add; do
        if [ "$num" -ge 1 ] && [ "$num" -le ${#all_modules[@]} ]; then
            module_to_add="${all_modules[$((num-1))]}"
            
            # Vérifier si le module n'est pas déjà présent
            already_present=0
            for module in "${new_modules[@]}"; do
                if [ "$module" = "$module_to_add" ]; then
                    already_present=1
                    break
                fi
            done
            
            if [ "$already_present" -eq 0 ]; then
                new_modules+=("$module_to_add")
                echo "Ajout: $module_to_add"
            else
                echo "Module déjà présent: $module_to_add"
            fi
        fi
    done
    
    # Mettre à jour la configuration
    update_modules_config "${new_modules[@]}"
    echo "Modules ajoutés avec succès!"
}

function reinitialiser_modules() {
    echo -e "\nRÉINITIALISATION DES MODULES"
    
    # Modules par défaut de Fastfetch
    declare -a default_modules=(
        "title" "separator" "os" "host" "kernel" "uptime" "packages"
        "shell" "display" "de" "wm" "wmtheme" "theme" "icons" "font"
        "cursor" "terminal" "terminalfont" "cpu" "gpu" "memory" "disk"
        "localip" "battery" "locale" "break" "colors"
    )
    
    update_modules_config "${default_modules[@]}"
    echo "Modules réinitialisés aux valeurs par défaut!"
}

# Fonction pour mettre à jour la configuration (inchangée)
function update_modules_config() {
    local modules=("$@")
    
    # Créer ou mettre à jour le fichier de configuration
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    
    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        # Conserver les autres paramètres et mettre à jour seulement les modules
        temp_file=$(mktemp)
        grep -v '"modules":' "$FASTFETCH_CONFIG_DIR/config.jsonc" | \
        grep -v '^ *\[$' | grep -v '^ *\]$' > "$temp_file"
        
        # Ajouter les nouveaux modules
        echo '    "modules": [' >> "$temp_file"
        for i in "${!modules[@]}"; do
            if [ $i -eq $(( ${#modules[@]} - 1 )) ]; then
                echo "        \"${modules[$i]}\"" >> "$temp_file"
            else
                echo "        \"${modules[$i]}\"," >> "$temp_file"
            fi
        done
        echo "    ]" >> "$temp_file"
        
        mv "$temp_file" "$FASTFETCH_CONFIG_DIR/config.jsonc"
    else
        # Créer une nouvelle configuration
        cat > "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
{
    "logo": {
        "type": "auto",
        "width": 60,
        "height": 30
    },
    "modules": [
EOF
        
        for i in "${!modules[@]}"; do
            if [ $i -eq $(( ${#modules[@]} - 1 )) ]; then
                echo "        \"${modules[$i]}\"" >> "$FASTFETCH_CONFIG_DIR/config.jsonc"
            else
                echo "        \"${modules[$i]}\"," >> "$FASTFETCH_CONFIG_DIR/config.jsonc"
            fi
        done
        
        cat >> "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
    ]
}
EOF
    fi
}

function activer_couleurs_aleatoires() {
    echo -e "\nCOULEURS ALÉATOIRES POUR LE LOGO"
    
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    
    # Lire la configuration actuelle ou créer une nouvelle
    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        # Ajouter la configuration des couleurs aléatoires
        if ! grep -q "randomColor" "$FASTFETCH_CONFIG_DIR/config.jsonc"; then
            sed -i '/"logo": {/a \        "randomColor": true,' "$FASTFETCH_CONFIG_DIR/config.jsonc"
        else
            sed -i 's/"randomColor": *[a-z]*/"randomColor": true/' "$FASTFETCH_CONFIG_DIR/config.jsonc"
        fi
    else
        # Créer une nouvelle configuration
        cat > "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
{
    "logo": {
        "type": "auto",
        "width": 60,
        "height": 30,
        "randomColor": true,
        "padding": {
            "top": 1,
            "left": 2
        }
    }
}
EOF
    fi
    
    echo "Couleurs aléatoires activées pour le logo!"
    echo "Le logo changera de couleur à chaque lancement de Fastfetch"
}

function afficher_configuration_actuelle() {
    echo -e "\nCONFIGURATION ACTUELLE FASTFETCH"
    
    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        echo "Fichier de configuration: $FASTFETCH_CONFIG_DIR/config.jsonc"
        echo "Contenu:"
        cat "$FASTFETCH_CONFIG_DIR/config.jsonc" | head -20
        echo "..."
    else
        echo "Aucune configuration personnalisée trouvée"
        echo "Fastfetch utilisera sa configuration par défaut"
    fi
    
    # Test rapide
    echo -e "\nAperçu:"
    fastfetch --config "$FASTFETCH_CONFIG_DIR/config.jsonc" 2>/dev/null || \
    echo "Utilisez 'fastfetch' pour voir la configuration actuelle"
}

function appliquer_configuration_fastfetch() {
    echo -e "\nAPPLICATION DE LA CONFIGURATION"
    
    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        echo "Configuration appliquée avec succès!"
        echo "Test:"
        fastfetch --config "$FASTFETCH_CONFIG_DIR/config.jsonc"
    else
        echo "Aucune configuration à appliquer"
        echo "Utilisation de la configuration par défaut:"
        fastfetch
    fi
    
    echo -e "\nPour utiliser cette configuration automatiquement:"
    echo "Ajoutez cette ligne à votre ~/.bashrc ou ~/.zshrc:"
    echo "alias ff='fastfetch --config \"$FASTFETCH_CONFIG_DIR/config.jsonc\"'"
}

function plymouth_video() {
    read -p "Chemin de la vidéo ou GIF : " input
    theme_dir="/usr/share/plymouth/themes/custom_video"
    sudo mkdir -p "$theme_dir/frames"
    ffmpeg -i "$input" -vf "scale=640:-1,fps=20" "$theme_dir/frames/frame%04d.png"
    dominant=$(ffmpeg -i "$input" -vf "scale=1:1" -f image2pipe -vcodec ppm - 2>/dev/null | convert - -format "%[hex:p{0,0}]" info:-)
    echo "[Plymouth Theme]
Name=CustomVideo
Description=Thème généré depuis vidéo/GIF
ModuleName=script

[script]
ImageDir=$theme_dir/frames
ProgressBarColor=$dominant
" | sudo tee "$theme_dir/custom_video.plymouth" >/dev/null
    sudo plymouth-set-default-theme -R custom_video
    echo "Thème Plymouth vidéo activé."
}

function integrer_spicetify() {
    echo -e "\nINSTALLATION DE SPOTIFY ET CONFIGURATION DE SPICETIFY"
    
    # Vérifier si Spotify est déjà installé
    if ! command -v spotify >/dev/null; then
        echo "Spotify n'est pas installé. Installation en cours..."
        
        # Essayer d'abord avec le dépôt existant
        sudo apt update
        if sudo apt install spotify-client -y 2>/dev/null; then
            echo "Spotify installé avec succès via le dépôt existant"
        else
            echo "Tentative alternative d'installation..."
            
            # Méthode alternative: Snap
            if command -v snap >/dev/null; then
                sudo snap install spotify
            # Méthode alternative: Flatpak
            elif command -v flatpak >/dev/null; then
                flatpak install flathub com.spotify.Client -y
            else
                # Réinstallation complète du dépôt
                sudo rm -f /etc/apt/sources.list.d/spotify.list
                sudo rm -f /etc/apt/trusted.gpg.d/spotify.gpg
                
                curl -sS https://download.spotify.com/debian/pubkey_7A3A762FAFD4A51F.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
                echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
                
                sudo apt update
                sudo apt install spotify-client -y
            fi
        fi
        
        # Vérifier que l'installation a réussi
        if ! command -v spotify >/dev/null; then
            echo "Échec de l'installation de Spotify"
            echo "Veuillez installer Spotify manuellement puis relancer cette option"
            return 1
        fi
        
        echo "Spotify installé avec succès"
    else
        echo "Spotify est déjà installé"
    fi
    
    # Installation de Spicetify
    echo "Installation de Spicetify..."
    
    # Méthode officielle
    curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | sh
    
    # Vérification de l'installation
    if ! command -v spicetify >/dev/null; then
        echo "Échec de l'installation de Spicetify"
        return 1
    fi
    
    echo "Spicetify installé avec succès"
    
    # Configuration initiale
    echo "Configuration de Spicetify..."
    spicetify backup apply
    spicetify config prefs_path ~/.config/spotify/prefs
    spicetify config current_theme SpicetifyDefault
    spicetify config color_scheme base
    
    # Installation des thèmes et extensions depuis le marketplace
    echo "Installation des ressources depuis le marketplace..."
    
    # Création des dossiers s'ils n'existent pas
    mkdir -p ~/.config/spicetify/Themes
    mkdir -p ~/.config/spicetify/Extensions
    mkdir -p ~/.config/spicetify/CustomApps
    
    # Téléchargement des thèmes populaires
    echo "Téléchargement des thèmes populaires..."
    git clone https://github.com/spicetify/spicetify-themes ~/.config/spicetify/Themes 2>/dev/null || {
        echo "Les thèmes sont déjà installés ou erreur de téléchargement"
    }
    
    # Téléchargement des extensions
    echo "Téléchargement des extensions..."
    git clone https://github.com/spicetify/spicetify-extensions ~/.config/spicetify/Extensions 2>/dev/null || {
        echo "Les extensions sont déjà installées ou erreur de téléchargement"
    }
    
    # Configuration du marketplace
    echo "Configuration du marketplace..."
    curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.sh | sh
    
    # Application de la configuration
    echo "Application de la configuration..."
    spicetify apply
    
    echo -e "\nINSTALLATION TERMINÉE !"
    echo "Spotify et Spicetify sont maintenant configurés"
    echo "Thèmes disponibles: Dribbblish, Onepunch, Ziro, etc."
    echo "Extensions disponibles: lyrics, playlist-icons, shuffle+"
    echo "Marketplace accessible: Ouvrez Spotify → Spicetify → Marketplace"
    echo ""
    echo "Commandes utiles:"
    echo "  spicetify apply          # Appliquer les changements"
    echo "  spicetify backup apply   # Restaurer la sauvegarde"
    echo "  spicetify restore        # Restaurer l'original"
    echo ""
    echo "Redémarrez Spotify pour voir les changements!"
}

#!/bin/bash

# Interface utilisateur
menu_principal() {
    while true; do
        echo
        echo "BearGrubChanger - Menu Principal"

        echo -e "\033[1;34m INSTALLATION & MAJ \033[0m"
        echo "1.  Installer tous les thèmes, polices, icônes + GRUB + Plymouth + SDDM"
        echo "2.  Mettre à jour tous les logiciels du système"

        echo -e "\033[1;34m GESTION GRUB \033[0m"
        echo "3.  Changer le thème GRUB"
        echo "4.  Appliquer une police pour le menu GRUB"
        echo "5.  Remplacer les icônes GRUB"
        echo "6.  Ajuster le délai de sélection GRUB"

        echo -e "\033[1;34m GESTION PLYMOUTH \033[0m"
        echo "7.  Activer/choisir un thème Plymouth"
        echo "8.  Plymouth animé depuis vidéo/GIF"

        echo -e "\033[1;34m GESTION LOGIN (SDDM) \033[0m"
        echo "9.  Changer le thème SDDM"

        echo -e "\033[1;34m KDE / GNOME \033[0m"
        echo "10. Activer un splashscreen KDE Plasma (GIF supporté)"
        echo "11. Fond d'écran animé KDE Plasma (sélection vidéo)"    
        echo "12. Thème global (icônes, couleurs...)"
        echo "13. Changer le thème GTK/QT système (clair/sombre/auto)"

        echo -e "\033[1;34m LOCKSCREEN \033[0m"
        echo "14. Changer le thème de l'écran de verrouillage"

        echo -e "\033[1;34m FASTFETCH \033[0m"
        echo "15. Customiser Fastfetch"

        echo -e "\033[1;34m SYSTEME \033[0m"
        echo "16. Changer la police système"
        echo "17. Configurer la disposition clavier au boot"
        echo "18. Configurer un fond sonore de login/boot"
        echo "19. Installer un thème sonore (GNOME/KDE)"
        echo "20. Installer NerdFonts"

        echo -e "\033[1;34m TOOLS \033[0m"
        echo "21. Export d'un profil complet"
        echo "22. Import d'un profil complet"
        echo "23. Téléchargeur de vidéos universel"

        echo -e "\033[1;34m MUSIQUE \033[0m"
        echo "24. Télécharger musique Spotify/YouTube"
        echo "25. Intégration Spicetify (thèmes + extensions)"

        echo -e "\033[1;34m QUITTER \033[0m"
        echo "0.  Quitter"
        
        read -p "Choix : " opt

        case "$opt" in
            1)  verifier_et_installer_grub; cloner_depot; install_assets; forcer_grub; installer_plymouth; installer_sddm; sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg ;;
            2)  maj_system ;;

            3)  appliquer_theme ;;
            4)  appliquer_police ;;
            5)  remplacer_icones ;;
            6)  ajuster_delai_grub ;;

            7)  choisir_plymouth ;;
            8)  plymouth_video ;;

            9)  choisir_sddm ;;

            10) activer_splashscreen_kde ;;
            11) wallpaper_video ;;
            12) appliquer_icons_sys ;;
            13) basculer_theme_systeme ;;

            14) configurer_lockscreen ;;

            15) fastfetch ;;

            16) appliquer_police_systeme ;;
            17) configurer_clavier ;;
            18) configurer_son_login ;;
            19) installer_theme_sonore ;;
            20) installer_nerdfonts ;;

            21) exporter_profil ;;
            22) importer_profil ;;
            23) telecharger_videos ;;

            24) telecharger_musique ;;
            25) integrer_spicetify ;;

            0)  echo "Merci d'utiliser BearGrubChanger !"; exit 0 ;;
            *)  echo "Option invalide." ;;
        esac
    done
}
# Modifier les options 18, 19 et vérifier le bon fonctionnement des autres fonctions
menu_principal
