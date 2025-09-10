#!/bin/bash

# BearGrubChanger - by PapaOursPolaire 
# Version 178.8, mise à jour le 01/09/2025 - 22:16

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

function forcer_affichage_menu_grub() {
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
function installer_tous_les_assets() {
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

function choisir_theme_plymouth() {
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

function choisir_theme_sddm() {
    echo "Thèmes SDDM disponibles :"
    echo "0. SDDM Customisé (vidéo/GIF/images aléatoires)"
    local i=2
    SDDM_KEYS=()
    SDDM_KEYS[1]="custom"
    for theme in "$SDDM_THEMES_DIR"/*; do
        if [ -d "$theme" ] && [ "$(basename "$theme")" != "custom" ]; then
            name=$(basename "$theme")
            echo "$i. $name"
            SDDM_KEYS[$i]="$name"
            ((i++))
        fi
    done

    read -p "Choix du thème SDDM : " sddm_choice
    if ! [[ "$sddm_choice" =~ ^[0-9]+$ ]] || ((sddm_choice < 0 || sddm_choice >= i)); then
        echo "Choix invalide."; exit 1
    fi

    if [ "$sddm_choice" -eq 0 ]; then
        configurer_sddm_customise
    else
        selected="${SDDM_KEYS[$sddm_choice]}"
        echo "Activation du thème $selected..."
        
        # Créer le dossier de configuration si inexistant
        sudo mkdir -p "$SDDM_CONFIG_DIR"
        
        # Configurer SDDM pour utiliser le thème sélectionné
        sudo tee "$SDDM_CONFIG_DIR/bear-theme.conf" >/dev/null <<EOF
[Theme]
Current=$selected
EOF

        echo "Thème SDDM $selected appliqué."
        echo "Redémarrez SDDM pour voir les changements: sudo systemctl restart sddm"
    fi
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

    echo -e "\n=== CONFIGURATION TERMINEE ==="
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

    # Détecter les thèmes de splashscreen valides (structure contents/)
    declare -a valid_splashscreens
    declare -a splash_paths
    declare -a splash_files
    local i=1

    echo "Détection des splashscreens KDE disponibles..."
    
    # Parcourir tous les dossiers dans splashscreens/
    for splash_dir in "$REPO_DIR/splashscreens"/*; do
        if [ -d "$splash_dir" ]; then
            local splash_name=$(basename "$splash_dir")
            local contents_dir="$splash_dir/contents"
            
            # Vérifier la structure requise
            if [ -d "$contents_dir" ] && [ -f "$contents_dir/Splash.qml" ]; then
                # Chercher les fichiers multimédias dans contents/
                local media_files=()
                
                # Chercher différents types de fichiers multimédias
                while IFS= read -r -d $'\0' media_file; do
                    media_files+=("$(basename "$media_file")")
                done < <(find "$contents_dir" -maxdepth 1 -type f \( \
                    -iname "*.gif" -o -iname "*.png" -o -iname "*.jpg" -o \
                    -iname "*.jpeg" -o -iname "*.mp4" -o -iname "*.webm" \
                \) -print0 2>/dev/null)
                
                if [ ${#media_files[@]} -gt 0 ]; then
                    echo "$i. $splash_name"
                    echo "   Structure: contents/Splash.qml + ${#media_files[@]} fichier(s) média"
                    echo "   Médias: ${media_files[*]}"
                    
                    # Vérifier si metadata.desktop existe
                    if [ -f "$splash_dir/metadata.desktop" ]; then
                        local theme_name=$(grep "^Name=" "$splash_dir/metadata.desktop" 2>/dev/null | cut -d'=' -f2)
                        if [ -n "$theme_name" ]; then
                            echo "   Nom: $theme_name"
                        fi
                    fi
                    
                    valid_splashscreens[$i]="$splash_name"
                    splash_paths[$i]="$splash_dir"
                    splash_files[$i]="${media_files[0]}"  # Premier fichier média trouvé
                    ((i++))
                    echo ""
                fi
            else
                echo "Ignoré: $splash_name (structure invalide - manque contents/Splash.qml)"
            fi
        fi
    done

    if [ ${#valid_splashscreens[@]} -eq 0 ]; then
        echo "Aucun splashscreen KDE valide trouvé dans $REPO_DIR/splashscreens"
        echo ""
        echo "Structure attendue pour chaque splashscreen:"
        echo "nom_du_splashscreen/"
        echo "├── contents/"
        echo "│   ├── Splash.qml"
        echo "│   └── fichier_média.gif (ou .png, .jpg, .mp4, etc.)"
        echo "└── metadata.desktop (optionnel)"
        echo ""
        echo "Note: Les noms de fichiers média peuvent varier, mais Splash.qml est obligatoire"
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
        if [ -f "$THEME_DIR/metadata.desktop" ]; then
            # Modifier l'identifiant du plugin pour éviter les conflits
            sed -i "s/X-KDE-PluginInfo-Name=.*/X-KDE-PluginInfo-Name=bearsplash/" "$THEME_DIR/metadata.desktop"
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
        if [ ! -f "$THEME_DIR/contents/Splash.qml" ]; then
            echo "Erreur: Splash.qml manquant après copie"
            return 1
        fi

        # Détection du type de média principal pour optimisation
        media_ext="${selected_media##*.}"
        echo "Type de média détecté: $media_ext"

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
        echo "Fichier média principal: $selected_media"
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

# Fond d'écran animé KDE Plasma avec explorateur de fichiers
function activer_fond_anime_kde() {
    # Vérifier que KDE Plasma est bien détecté
    if ! pgrep -x "plasmashell" >/dev/null; then
        echo "KDE Plasma n'est pas détecté comme environnement actuel"
        return 1
    fi

    echo -e "\nACTIVATION DE FOND D'ÉCRAN VIDÉO POUR KDE PLASMA"
    
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
    
    # CORRECTION : Boucle while complète et correctement formée
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

    # Configuration du fond d'écran via plasma-apply-wallpaperimage si disponible
    echo "Tentative d'application automatique..."
    
    # Essayer différentes méthodes d'application
    if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
        # Méthode 1: plasma-apply-wallpaperimage (ne fonctionne que pour les images)
        echo "Utilisation de plasma-apply-wallpaperimage..."
    fi
    
    # Méthode 2: Configuration directe via dbus
    if command -v qdbus >/dev/null 2>&1; then
        echo "Configuration via DBus..."
        # Essayer de configurer le bureau principal
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
}

# Thèmes d'icônes système complets (dossier icons-themes du repo)
function appliquer_theme_icones_systeme() {
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

function mettre_a_jour_systeme() {
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

# Fonction principale de customisation Fastfetch
function customiser_fastfetch() {
    echo -e "\nCUSTOMISATION DE FASTFETCH"
    
    # Installer Fastfetch si nécessaire
    installer_fastfetch || return 1
    
    # Créer les dossiers nécessaires
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    mkdir -p "$FASTFETCH_LOGOS_DIR"
    
    # Vérifier si le dossier d'images existe dans le repo
    if [ ! -d "$FASTFETCH_IMAGES_DIR" ]; then
        echo "Dossier d'images Fastfetch non trouvé dans le dépôt"
        echo "Création du dossier pour images personnalisées..."
        mkdir -p "$FASTFETCH_IMAGES_DIR"
    fi
    
    echo "Options de customisation Fastfetch :"
    echo "1. Logo fixe personnalisé"
    echo "2. Logo aléatoire à chaque lancement"
    echo "3. Ajouter une nouvelle image/logo"
    echo "4. Restaurer la configuration par défaut"
    echo "0. Retour au menu principal"
    
    read -p "Votre choix [0-4]: " fastfetch_choice
    
    case "$fastfetch_choice" in
        1) configurer_logo_fixe_fastfetch ;;
        2) configurer_logo_aleatoire_fastfetch ;;
        3) ajouter_image_fastfetch ;;
        4) restaurer_config_fastfetch ;;
        0) return 0 ;;
        *) echo "Choix invalide" ;;
    esac
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

# Interface utilisateur
function menu_principal() {
    while true; do
        echo -e "\nBearGrubChanger - Menu Principal"
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
        echo "11. Thème global"
        echo "12. Mettre à jour tous les logiciels du système"
        echo "13. Customiser Fastfetch (logos personnalisés)"
        echo "0. Quitter"
        read -p "Choix : " opt

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
            10) activer_fond_anime_kde ;;
            11) appliquer_theme_icones_systeme ;;
            12) mettre_a_jour_systeme ;;
            13) customiser_fastfetch ;;
            0) echo "T'a intéret à étoilé mes repos GitHub et me suivre !"; exit 0 ;;
            *) echo "Option invalide." ;;
        esac
    done
}

menu_principal
