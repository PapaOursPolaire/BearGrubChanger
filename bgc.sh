#!/bin/bash
#
# BearGrubChanger - réécriture complète (v3.0)
# Basé sur le script original de PapaOursPolaire, reconstruit pour être
# universel (multi-distro), maintenable et sûr (pas de suppression de
# paquets critiques pendant une session active, pas de conflit entre
# display managers, gestion d'erreurs partout).
#
# Distributions supportées : Debian/Ubuntu/Mint (apt), Fedora/RHEL (dnf),
# Arch/Manjaro (pacman), openSUSE (zypper).

set -o pipefail
set -E   # les traps ERR sont hérités par les fonctions et sous-shells

# ============================================================
# 0. GESTION D'ERREUR GLOBALE
# ============================================================
# Note : on n'active volontairement PAS "set -e" strict. Ce script est un
# menu interactif où chaque fonction gère déjà ses propres échecs via
# "cmd || { log_err ...; return 1; }" et retourne au menu plutôt que de
# tout arrêter — un "set -e" global ferait quitter le script entier au
# premier grep/find qui ne trouve rien, ce qui casserait ce comportement.
# On garde en revanche un trap ERR pour logguer les échecs inattendus
# (ceux qui ne sont pas déjà interceptés par un || explicite) sans jamais
# faire planter le script.
_trap_erreur() {
    local code=$? ligne=$1
    [ "$code" -eq 0 ] && return 0
    log_warn "Commande non interceptée en échec (ligne ${ligne}, code ${code}) — le script continue."
}
trap '_trap_erreur $LINENO' ERR

# ============================================================
# 1. CONFIGURATION GLOBALE
# ============================================================

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
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"
FASTFETCH_IMAGES_DIR="$REPO_DIR/fastfetch/images"
BACKUP_DIR="$LOCAL_DIR/backups"

PKG_MANAGER=""   # apt | dnf | pacman | zypper
CURRENT_DE=""    # plasma | gnome | xfce | cinnamon | mate | inconnu

# ============================================================
# 2. FONCTIONS UTILITAIRES GÉNÉRIQUES
# ============================================================

log_info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
log_ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
log_warn()  { echo -e "\033[1;33m[ATTENTION]\033[0m $*"; }
log_err()   { echo -e "\033[1;31m[ERREUR]\033[0m $*" >&2; }

# confirm "question" -> retourne 0 (oui) ou 1 (non). Défaut = non.
confirm() {
    local reponse
    read -r -p "$1 (y/N): " reponse
    [[ "$reponse" =~ ^[Yy]$ ]]
}

# confirm_dangereux "question" -> exige de taper OUI en toutes lettres.
# Utilisé avant toute opération destructive (suppression de paquets,
# modification du display manager, etc.)
confirm_dangereux() {
    local reponse
    log_warn "$1"
    read -r -p "Tapez OUI (en majuscules) pour continuer, autre chose pour annuler : " reponse
    [ "$reponse" = "OUI" ]
}

backup_fichier() {
    local fichier="$1"
    [ -f "$fichier" ] || return 0
    mkdir -p "$BACKUP_DIR"
    local nom_backup
    nom_backup="$BACKUP_DIR/$(basename "$fichier").$(date +%Y%m%d-%H%M%S).bak"
    sudo cp -a "$fichier" "$nom_backup" 2>/dev/null && \
        log_info "Sauvegarde créée : $nom_backup"
}

# détecte la distribution et prépare les commandes de paquets
detecter_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "Distribution détectée : ${NAME:-inconnue} ${VERSION:-}"
        case "${ID:-}" in
            debian|ubuntu|linuxmint|pop|elementary|zorin) PKG_MANAGER="apt" ;;
            fedora|rhel|centos|rocky|almalinux)           PKG_MANAGER="dnf" ;;
            arch|manjaro|endeavouros)                      PKG_MANAGER="pacman" ;;
            opensuse*|sles)                                PKG_MANAGER="zypper" ;;
            *)
                # Repli sur les ID_LIKE si la distro n'est pas reconnue directement
                case "${ID_LIKE:-}" in
                    *debian*) PKG_MANAGER="apt" ;;
                    *fedora*|*rhel*) PKG_MANAGER="dnf" ;;
                    *arch*) PKG_MANAGER="pacman" ;;
                    *suse*) PKG_MANAGER="zypper" ;;
                    *)
                        log_warn "Distribution non reconnue, tentative avec APT par défaut."
                        PKG_MANAGER="apt"
                        ;;
                esac
                ;;
        esac
    else
        log_warn "Impossible de lire /etc/os-release, utilisation d'APT par défaut."
        PKG_MANAGER="apt"
    fi
    log_info "Gestionnaire de paquets : $PKG_MANAGER"
}

# pkg_install pkg1 pkg2 ... : installe des paquets avec le bon gestionnaire.
# Les noms de paquets doivent être ceux d'APT ; une table de correspondance
# simple est appliquée pour les autres gestionnaires quand nécessaire via
# pkg_traduire_nom().
pkg_install() {
    [ -n "$PKG_MANAGER" ] || detecter_distribution
    local paquets=("$@")
    case "$PKG_MANAGER" in
        apt)
            sudo apt update -qq
            sudo apt install -y "${paquets[@]}"
            ;;
        dnf)
            sudo dnf install -y "${paquets[@]}"
            ;;
        pacman)
            sudo pacman -Sy --needed --noconfirm "${paquets[@]}"
            ;;
        zypper)
            sudo zypper --non-interactive install "${paquets[@]}"
            ;;
        *)
            log_err "Gestionnaire de paquets inconnu."
            return 1
            ;;
    esac
}

# pkg_remove pkg1 pkg2 ... : retire des paquets. Ne JAMAIS appeler sur des
# paquets liés à l'environnement de bureau ou au display manager actif
# sans être passé par confirm_dangereux() avant.
pkg_remove() {
    [ -n "$PKG_MANAGER" ] || detecter_distribution
    local paquets=("$@")
    case "$PKG_MANAGER" in
        apt)    sudo apt remove --purge -y "${paquets[@]}" ;;
        dnf)    sudo dnf remove -y "${paquets[@]}" ;;
        pacman) sudo pacman -Rns --noconfirm "${paquets[@]}" ;;
        zypper) sudo zypper --non-interactive remove "${paquets[@]}" ;;
        *)      log_err "Gestionnaire de paquets inconnu."; return 1 ;;
    esac
}

pkg_maj_systeme() {
    [ -n "$PKG_MANAGER" ] || detecter_distribution
    log_info "Mise à jour du système..."
    case "$PKG_MANAGER" in
        apt)    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y ;;
        dnf)    sudo dnf upgrade --refresh -y ;;
        pacman) sudo pacman -Syu --noconfirm ;;
        zypper) sudo zypper refresh && sudo zypper --non-interactive update ;;
    esac
    log_ok "Système à jour."
}

regenerer_grub() {
    if command -v update-grub >/dev/null 2>&1; then
        sudo update-grub
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        log_err "Impossible de trouver grub-mkconfig / update-grub."
        return 1
    fi
}

regenerer_initramfs() {
    if command -v update-initramfs >/dev/null 2>&1; then
        sudo update-initramfs -u -k all
    elif command -v dracut >/dev/null 2>&1; then
        sudo dracut -f --regenerate-all
    elif command -v mkinitcpio >/dev/null 2>&1; then
        sudo mkinitcpio -P
    else
        log_warn "Aucun outil d'initramfs connu trouvé (update-initramfs/dracut/mkinitcpio)."
    fi
}

# Remplace ou ajoute une variable dans un fichier de config type /etc/default/grub
# maj_grub_var "GRUB_TIMEOUT" "15"
maj_grub_var() {
    local var="$1" valeur="$2" fichier="${3:-$GRUB_FILE}"
    backup_fichier "$fichier"
    if sudo grep -q "^${var}=" "$fichier" 2>/dev/null; then
        sudo sed -i "s|^${var}=.*|${var}=\"${valeur}\"|" "$fichier"
    else
        echo "${var}=\"${valeur}\"" | sudo tee -a "$fichier" >/dev/null
    fi
}

# Sélecteur générique interactif. Usage :
#   choisir_dans_liste "Titre" element1 element2 element3
# Remplit la variable globale CHOIX_SELECTIONNE avec l'élément choisi,
# ou la laisse vide si annulé / invalide.
choisir_dans_liste() {
    local titre="$1"; shift
    local elements=("$@")
    CHOIX_SELECTIONNE=""

    if [ "${#elements[@]}" -eq 0 ]; then
        log_warn "Aucun élément disponible pour : $titre"
        return 1
    fi

    echo "$titre"
    local i=1
    for e in "${elements[@]}"; do
        echo "  $i. $e"
        ((i++))
    done

    local choix
    read -r -p "Votre choix : " choix
    if ! [[ "$choix" =~ ^[0-9]+$ ]] || (( choix < 1 || choix > ${#elements[@]} )); then
        log_err "Choix invalide."
        return 1
    fi

    CHOIX_SELECTIONNE="${elements[$((choix-1))]}"
    return 0
}

# Liste les sous-dossiers d'un répertoire et laisse choisir. Remplit
# CHOIX_SELECTIONNE avec le nom (pas le chemin complet).
choisir_sous_dossier() {
    local dir="$1" titre="$2"
    local noms=()
    if [ -d "$dir" ]; then
        for d in "$dir"/*/; do
            [ -d "$d" ] || continue
            noms+=("$(basename "$d")")
        done
    fi
    if [ "${#noms[@]}" -eq 0 ]; then
        log_warn "Aucun élément trouvé dans $dir"
        return 1
    fi
    choisir_dans_liste "$titre" "${noms[@]}"
}

# Clone ou met à jour le dépôt d'assets (thèmes, polices, icônes...)
assurer_depot() {
    mkdir -p "$LOCAL_DIR"
    if ! command -v git >/dev/null 2>&1; then
        log_info "git n'est pas installé, installation..."
        pkg_install git || { log_err "Impossible d'installer git."; return 1; }
    fi
    if [ ! -d "$REPO_DIR/.git" ]; then
        log_info "Clonage du dépôt BearGrubChanger..."
        git clone --depth 1 --branch "$GIT_BRANCH" "$GIT_REPO" "$REPO_DIR" || {
            log_err "Clonage échoué."; return 1;
        }
    else
        log_info "Mise à jour du dépôt..."
        git -C "$REPO_DIR" pull --ff-only || log_warn "Mise à jour du dépôt impossible (pas bloquant)."
    fi
}

# Détecte l'environnement de bureau actuellement actif (processus en cours).
detecter_de_actif() {
    if pgrep -x plasmashell    >/dev/null 2>&1; then CURRENT_DE="plasma"
    elif pgrep -x gnome-shell  >/dev/null 2>&1; then CURRENT_DE="gnome"
    elif pgrep -x xfce4-panel  >/dev/null 2>&1; then CURRENT_DE="xfce"
    elif pgrep -x cinnamon-session >/dev/null 2>&1; then CURRENT_DE="cinnamon"
    elif pgrep -x mate-panel   >/dev/null 2>&1; then CURRENT_DE="mate"
    else CURRENT_DE="inconnu"
    fi
}

# Applique un réglage (police ou thème clair/sombre) à l'environnement de
# bureau actif, en centralisant toute la logique KDE/GNOME/XFCE en un seul
# endroit au lieu de la dupliquer à chaque option de menu.
# Usage : appliquer_reglage_de "font" "Nom de la police"
#         appliquer_reglage_de "theme" "dark"|"light"
appliquer_reglage_de() {
    local type="$1" valeur="$2"
    detecter_de_actif

    case "$CURRENT_DE" in
        plasma)
            if ! command -v kwriteconfig6 >/dev/null 2>&1 && ! command -v kwriteconfig5 >/dev/null 2>&1; then
                log_err "kwriteconfig introuvable, impossible de configurer KDE."
                return 1
            fi
            local kwriteconfig
            kwriteconfig=$(command -v kwriteconfig6 || command -v kwriteconfig5)
            case "$type" in
                font)
                    "$kwriteconfig" --file kdeglobals --group General --key font "$valeur,10,-1,5,50,0,0,0,0,0"
                    ;;
                theme)
                    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
                        if [ "$valeur" = "dark" ]; then plasma-apply-colorscheme BreezeDark
                        else plasma-apply-colorscheme BreezeLight
                        fi
                    else
                        log_warn "plasma-apply-colorscheme introuvable, réglage manuel requis."
                    fi
                    ;;
            esac
            ;;
        gnome)
            case "$type" in
                font)
                    gsettings set org.gnome.desktop.interface font-name "$valeur 11"
                    gsettings set org.gnome.desktop.interface document-font-name "$valeur 11"
                    ;;
                theme)
                    if [ "$valeur" = "dark" ]; then
                        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
                    else
                        gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
                    fi
                    ;;
            esac
            ;;
        xfce)
            case "$type" in
                font)
                    xfconf-query -c xsettings -p /Gtk/FontName -s "$valeur 11" 2>/dev/null
                    ;;
                theme)
                    if [ "$valeur" = "dark" ]; then
                        xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark" 2>/dev/null
                    else
                        xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita" 2>/dev/null
                    fi
                    ;;
            esac
            ;;
        *)
            log_warn "Environnement de bureau non détecté ou non supporté pour cette action."
            log_info "Vous pouvez régler ce paramètre manuellement dans les préférences de votre DE."
            return 1
            ;;
    esac
    log_ok "Réglage appliqué pour $CURRENT_DE."
}

# ============================================================
# 3. GRUB
# ============================================================

verifier_et_installer_grub() {
    if command -v grub-install >/dev/null 2>&1 || command -v grub2-install >/dev/null 2>&1; then
        log_ok "GRUB est déjà installé."
        return 0
    fi
    log_info "GRUB n'est pas installé, installation..."
    case "$PKG_MANAGER" in
        apt)    pkg_install grub2-common grub-pc ;;
        pacman) pkg_install grub ;;
        dnf)    pkg_install grub2 ;;
        zypper) pkg_install grub2 ;;
    esac || { log_err "Échec de l'installation de GRUB."; return 1; }
}

forcer_menu_grub() {
    log_info "Forçage de l'affichage du menu GRUB..."
    maj_grub_var "GRUB_TIMEOUT_STYLE" "menu"
    maj_grub_var "GRUB_TIMEOUT" "15"
    sudo sed -i '/^GRUB_HIDDEN_TIMEOUT=/d' "$GRUB_FILE"
    regenerer_grub && log_ok "Menu GRUB forcé."
}

ajuster_delai_grub() {
    local delai
    read -r -p "Délai souhaité en secondes (0-60) : " delai
    if ! [[ "$delai" =~ ^[0-9]+$ ]] || (( delai < 0 || delai > 60 )); then
        log_err "Valeur invalide."
        return 1
    fi
    maj_grub_var "GRUB_TIMEOUT" "$delai"
    regenerer_grub && log_ok "Délai GRUB réglé sur ${delai}s."
}

appliquer_theme_grub() {
    if [ ! -d "$THEMES_DIR" ] || [ -z "$(ls -A "$THEMES_DIR" 2>/dev/null)" ]; then
        log_warn "Aucun thème GRUB installé. Utilisez l'option 1 pour tout installer d'abord."
        return 1
    fi
    choisir_sous_dossier "$THEMES_DIR" "Thèmes GRUB disponibles :" || return 1
    local selected="$CHOIX_SELECTIONNE"

    if [ ! -f "$THEMES_DIR/$selected/theme.txt" ]; then
        log_err "theme.txt introuvable dans $THEMES_DIR/$selected"
        return 1
    fi

    maj_grub_var "GRUB_THEME" "$THEMES_DIR/$selected/theme.txt"
    regenerer_grub && log_ok "Thème GRUB '$selected' appliqué."
}

appliquer_police_grub() {
    local dossier_polices="$LOCAL_DIR/fonts"
    local polices=()
    if [ -d "$dossier_polices" ]; then
        while IFS= read -r -d '' f; do polices+=("$(basename "$f")"); done \
            < <(find "$dossier_polices" -maxdepth 1 -type f \( -iname '*.pf2' -o -iname '*.ttf' -o -iname '*.otf' \) -print0)
    fi
    if [ "${#polices[@]}" -eq 0 ]; then
        log_warn "Aucune police trouvée dans $dossier_polices. Utilisez l'option 1 d'abord."
        return 1
    fi
    choisir_dans_liste "Polices disponibles pour GRUB :" "${polices[@]}" || return 1
    local selected="$CHOIX_SELECTIONNE"

    local theme_actuel
    theme_actuel=$(grep "^GRUB_THEME=" "$GRUB_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"')
    if [ -z "$theme_actuel" ] || [ ! -f "$theme_actuel" ]; then
        log_err "Aucun thème GRUB actif trouvé. Appliquez d'abord un thème (option 3)."
        return 1
    fi

    backup_fichier "$theme_actuel"
    sudo sed -i '/^terminal-font:/d' "$theme_actuel"
    echo "terminal-font: \"$dossier_polices/$selected\"" | sudo tee -a "$theme_actuel" >/dev/null
    regenerer_grub && log_ok "Police GRUB '$selected' appliquée."
}

remplacer_icones_grub() {
    local dossier_icones="$LOCAL_DIR/icons"
    if [ ! -d "$dossier_icones" ] || [ -z "$(ls -A "$dossier_icones" 2>/dev/null)" ]; then
        log_warn "Aucune icône trouvée dans $dossier_icones. Utilisez l'option 1 d'abord."
        return 1
    fi
    local theme_actuel
    theme_actuel=$(grep "^GRUB_THEME=" "$GRUB_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"')
    if [ -z "$theme_actuel" ]; then
        log_err "Aucun thème GRUB actif. Appliquez d'abord un thème (option 3)."
        return 1
    fi
    local dossier_theme
    dossier_theme="$(dirname "$theme_actuel")"
    sudo cp -r "$dossier_icones/"* "$dossier_theme/" && \
        regenerer_grub && log_ok "Icônes copiées dans le thème GRUB actif."
}

DETECTEUR_ACCEL_VIDEO_FAIT=false

# Vérifie qu'un GPU NVIDIA dispose bien de son driver VAAPI dédié avant
# d'utiliser un thème vidéo (Plymouth ou SDDM). Sans ce paquet, le décodage
# vidéo matériel échoue silencieusement puis peut faire planter le
# compositeur/greeter — le bug exact rencontré et corrigé sur ce système.
# Ne bloque jamais : avertit et propose une correction automatique.
verifier_accel_video() {
    "$DETECTEUR_ACCEL_VIDEO_FAIT" && return 0
    DETECTEUR_ACCEL_VIDEO_FAIT=true

    command -v lspci >/dev/null 2>&1 || pkg_install pciutils 2>/dev/null

    local gpu_lines
    gpu_lines=$(lspci 2>/dev/null | grep -iE "VGA|3D controller|Display controller" || true)
    echo "$gpu_lines" | grep -qi "nvidia" || return 0   # pas de GPU NVIDIA, rien à faire

    log_info "GPU NVIDIA détecté : vérification du driver VAAPI dédié..."

    if ! command -v vainfo >/dev/null 2>&1; then
        pkg_install libva-utils 2>/dev/null || pkg_install vainfo 2>/dev/null
    fi

    if command -v vainfo >/dev/null 2>&1 && vainfo &>/dev/null; then
        log_ok "VAAPI fonctionnel."
        return 0
    fi

    log_warn "VAAPI non fonctionnel ou driver NVIDIA dédié absent."
    if confirm "Installer le paquet VAAPI NVIDIA maintenant (recommandé, évite un écran figé/plantage) ?"; then
        case "$PKG_MANAGER" in
            apt)    pkg_install nvidia-vaapi-driver ;;
            pacman) pkg_install libva-nvidia-driver ;;
            dnf)    pkg_install nvidia-vaapi-driver ;;
            zypper) pkg_install nvidia-vaapi-driver ;;
        esac
        if command -v vainfo >/dev/null 2>&1 && vainfo &>/dev/null; then
            log_ok "VAAPI fonctionnel après installation."
        fi
    else
        log_warn "Poursuite sans correction VAAPI."
    fi

    # Filet de sécurité systemd, quel que soit l'état de VAAPI ci-dessus :
    # une session de debug complète a révélé une chaîne de races distinctes
    # au cold boot sous Wayland avec un GPU NVIDIA, indépendantes de VAAPI :
    #   1) SIGSEGV dans QRhi::addCleanupCallback (plugin vidéo FFmpeg de
    #      Qt6Multimedia vs boucle de rendu Qt Quick threadée) → corrigé par
    #      QSG_RENDER_LOOP=basic.
    #   2) "Could not take device: Device or resource busy" / "couldn't
    #      commit new state: Permission denied" → Weston sans seatd retombe
    #      sur logind, qui entre en course avec Plymouth pour le rôle DRM
    #      master → corrigé par l'installation de seatd + ajout de
    #      l'utilisateur sddm au groupe "video".
    # Un Restart=on-failure reste en dernier recours : si une race résiduelle
    # survient malgré tout, SDDM se relance seul (~1s) plutôt que de laisser
    # un écran figé nécessitant "systemctl restart sddm" manuel.
    log_info "Mise en place du filet de sécurité SDDM pour GPU NVIDIA sous Wayland (seatd, rendu, auto-restart)"

    case "$PKG_MANAGER" in
        apt)    pkg_install seatd ;;
        pacman) pkg_install seatd ;;
        dnf)    pkg_install seatd ;;
        zypper) pkg_install seatd ;;
    esac
    if command -v seatd >/dev/null 2>&1; then
        sudo systemctl enable --now seatd 2>/dev/null
        sudo usermod -aG video sddm 2>/dev/null
        log_ok "seatd activé, utilisateur sddm ajouté au groupe video"
    else
        log_warn "seatd non installé — SDDM restera exposé à la race logind/Plymouth au cold boot"
    fi

    sudo systemctl enable --now nvidia-persistenced 2>/dev/null

    # Nettoie l'ancien filet de sécurité partiel s'il existe (versions
    # précédentes de ce script), pour ne pas avoir deux fichiers qui se
    # contredisent dans /etc/systemd/system/sddm.service.d/.
    sudo rm -f /etc/systemd/system/sddm.service.d/nvidia-ffmpeg-fallback.conf

    sudo mkdir -p /etc/systemd/system/sddm.service.d
    sudo tee /etc/systemd/system/sddm.service.d/nvidia-gpu-wait.conf >/dev/null <<'EOF'
[Unit]
After=nvidia-persistenced.service seatd.service plymouth-quit-wait.service
Requires=seatd.service

[Service]
ExecStartPre=/bin/sh -c 'for i in $(seq 1 30); do nvidia-smi >/dev/null 2>&1 && exit 0; sleep 0.5; done; exit 0'
Environment=QSG_RENDER_LOOP=basic
#Environment=QT_FFMPEG_DECODING_HW_DEVICE_TYPES=none
Restart=on-failure
RestartSec=1
EOF
    sudo systemctl daemon-reload
    log_ok "Filet de sécurité installé : /etc/systemd/system/sddm.service.d/nvidia-gpu-wait.conf"

    # Modules DKMS NVIDIA dans l'initramfs, sinon Plymouth affiche un rendu
    # dégradé (carrés blancs) faute d'accès au GPU dès le début du boot.
    local modules_file="/etc/initramfs-tools/modules"
    if [[ -f "$modules_file" ]]; then
        local mod besoin_regen=false
        for mod in nvidia nvidia-modeset nvidia-drm nvidia-uvm; do
            if ! grep -qxF "$mod" "$modules_file"; then
                echo "$mod" | sudo tee -a "$modules_file" >/dev/null
                besoin_regen=true
            fi
        done
        [[ -f /etc/modprobe.d/nvidia-drm-kms.conf ]] && \
            sudo sed -i 's/nvidia-current-drm/nvidia-drm/' /etc/modprobe.d/nvidia-drm-kms.conf
        if $besoin_regen; then
            sudo depmod -a "$(uname -r)" 2>/dev/null
            sudo update-initramfs -u -k all
            log_ok "Modules NVIDIA ajoutés à l'initramfs (correction Plymouth)"
        fi
    fi
}

# ============================================================
# 4. PLYMOUTH
# ============================================================

installer_plymouth() {
    log_info "Installation de Plymouth..."
    case "$PKG_MANAGER" in
        apt)    pkg_install plymouth plymouth-themes plymouth-x11 ;;
        pacman) pkg_install plymouth ;;
        dnf)    pkg_install plymouth plymouth-scripts ;;
        zypper) pkg_install plymouth ;;
    esac || { log_err "Échec installation Plymouth."; return 1; }

    maj_grub_var "GRUB_CMDLINE_LINUX_DEFAULT" "quiet splash"
    regenerer_grub
    log_ok "Plymouth installé et GRUB configuré pour l'afficher."
}

choisir_theme_plymouth() {
    if ! command -v plymouth >/dev/null 2>&1; then
        log_warn "Plymouth n'est pas installé (option 1 ou 7 d'abord)."
        return 1
    fi
    if [ ! -d "$REPO_DIR/plymouth" ]; then
        log_warn "Dossier Plymouth du dépôt introuvable. Utilisez l'option 1 d'abord."
        return 1
    fi

    local themes=()
    for d in "$REPO_DIR/plymouth"/*/; do
        [ -d "$d" ] || continue
        local nom; nom="$(basename "$d")"
        [ -f "$d/$nom.plymouth" ] && themes+=("$nom")
    done
    choisir_dans_liste "Thèmes Plymouth disponibles :" "${themes[@]}" || return 1
    local selected="$CHOIX_SELECTIONNE"

    sudo mkdir -p "$PLYMOUTH_DIR"
    sudo cp -r "$REPO_DIR/plymouth/$selected" "$PLYMOUTH_DIR/"

    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        sudo plymouth-set-default-theme "$selected"
    else
        sudo mkdir -p /etc/plymouth
        {
            echo "[Daemon]"
            echo "Theme=$selected"
        } | sudo tee /etc/plymouth/plymouthd.conf >/dev/null
        if command -v update-alternatives >/dev/null 2>&1; then
            sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
                "$PLYMOUTH_DIR/$selected/$selected.plymouth" 100
            sudo update-alternatives --set default.plymouth "$PLYMOUTH_DIR/$selected/$selected.plymouth"
        fi
    fi

    regenerer_initramfs
    log_ok "Thème Plymouth '$selected' appliqué. Redémarrez pour le voir."
}

plymouth_depuis_media() {
    verifier_accel_video
    local chemin
    read -r -p "Chemin complet de la vidéo/GIF à utiliser comme animation de boot : " chemin
    if [ ! -f "$chemin" ]; then
        log_err "Fichier introuvable : $chemin"
        return 1
    fi
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log_info "ffmpeg requis pour convertir le média, installation..."
        pkg_install ffmpeg || { log_err "Impossible d'installer ffmpeg."; return 1; }
    fi

    local nom_theme="custom-media"
    local dest="$PLYMOUTH_DIR/$nom_theme"

    # ── Vérification d'espace disque avant extraction ─────────────────────
    # Une vidéo longue à 15fps peut générer des milliers de PNG. On estime
    # grossièrement (durée × 15 fps × ~150 Ko/frame en 1280px) et on compare
    # à l'espace disponible sur la partition cible, avec une marge x2.
    local duree_sec espace_dispo_ko estimation_ko
    duree_sec=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$chemin" 2>/dev/null | cut -d'.' -f1)
    if [ -n "$duree_sec" ] && [ "$duree_sec" -gt 0 ] 2>/dev/null; then
        estimation_ko=$(( duree_sec * 15 * 150 ))
        espace_dispo_ko=$(df --output=avail "$(dirname "$PLYMOUTH_DIR")" 2>/dev/null | tail -1)
        if [ -n "$espace_dispo_ko" ] && [ "$espace_dispo_ko" -lt "$((estimation_ko * 2))" ]; then
            log_err "Espace disque insuffisant : ~$((estimation_ko / 1024)) Mo estimés nécessaires,"
            log_err "seulement $((espace_dispo_ko / 1024)) Mo disponibles sur $(dirname "$PLYMOUTH_DIR")."
            log_err "Utilisez une vidéo plus courte, un fps plus bas, ou libérez de l'espace."
            return 1
        fi
        if [ "$duree_sec" -gt 30 ]; then
            log_warn "Vidéo de ${duree_sec}s : ça fera ~$((duree_sec * 15)) images extraites."
            confirm "C'est long pour un écran de boot, continuer quand même ?" || return 1
        fi
    else
        log_warn "Durée de la vidéo non détectable (ffprobe absent ou échec) — pas de vérification d'espace possible."
        confirm "Continuer sans vérification préalable ?" || return 1
    fi

    sudo mkdir -p "$dest/frames"

    log_info "Extraction des images (peut prendre un moment)..."
    sudo ffmpeg -y -i "$chemin" -vf "fps=15,scale=1280:-1" "$dest/frames/frame_%04d.png" -loglevel error || {
        log_err "Échec de l'extraction des frames."
        return 1
    }

    local nb_frames
    nb_frames=$(find "$dest/frames" -name 'frame_*.png' | wc -l)

    {
        echo "[Plymouth Theme]"
        echo "Name=Custom Media"
        echo "Description=Animation générée depuis $chemin"
        echo "ModuleName=script"
        echo ""
        echo "[script]"
        echo "ImageDir=$dest/frames"
        echo "ScriptFile=$dest/custom.script"
    } | sudo tee "$dest/$nom_theme.plymouth" >/dev/null

    cat <<SCRIPT | sudo tee "$dest/custom.script" >/dev/null
frame_count = $nb_frames;
current_frame = 0;
fun refresh_callback() {
    frame_image = Image("frame_" + string(current_frame + 1, "%04d") + ".png");
    sprite = Sprite(frame_image);
    sprite.SetX(Window.GetWidth()  / 2 - frame_image.GetWidth()  / 2);
    sprite.SetY(Window.GetHeight() / 2 - frame_image.GetHeight() / 2);
    current_frame = (current_frame + 1) % frame_count;
}
Plymouth.SetRefreshFunction(refresh_callback);
SCRIPT

    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        sudo plymouth-set-default-theme "$nom_theme"
    fi
    regenerer_initramfs
    log_ok "Animation Plymouth personnalisée créée et appliquée ($nb_frames images)."
}

# ============================================================
# 5. SDDM
# ============================================================

# Détecte le display manager actuellement activé par systemd, quel qu'il soit.
detecter_dm_actif() {
    for dm in sddm gdm3 gdm lightdm lxdm ly; do
        if systemctl is-enabled "$dm" &>/dev/null; then
            echo "$dm"
            return 0
        fi
    done
    echo ""
}

installer_sddm() {
    if command -v sddm >/dev/null 2>&1; then
        log_ok "SDDM est déjà installé."
    else
        log_info "Installation de SDDM..."
        pkg_install sddm || { log_err "Échec de l'installation de SDDM."; return 1; }
    fi

    local ancien_dm
    ancien_dm="$(detecter_dm_actif)"

    if [ -n "$ancien_dm" ] && [ "$ancien_dm" != "sddm" ]; then
        if ! confirm_dangereux "Le display manager actif est '$ancien_dm'. Il va être désactivé au profit de SDDM (effectif au prochain redémarrage, pas dans la session en cours)."; then
            log_info "Opération annulée."
            return 1
        fi
        sudo systemctl disable "$ancien_dm" 2>/dev/null
    fi

    # dpkg-reconfigure garde /etc/X11/default-display-manager ET le lien
    # systemd display-manager.service cohérents (Debian/Ubuntu).
    if command -v dpkg-reconfigure >/dev/null 2>&1; then
        echo "sddm shared/default-x-display-manager select sddm" | sudo debconf-set-selections 2>/dev/null
        sudo dpkg-reconfigure sddm 2>/dev/null
    fi

    sudo systemctl enable sddm
    log_ok "SDDM activé. Il prendra effet au prochain redémarrage."
}

choisir_theme_sddm() {
    echo "Quel type de thème SDDM voulez-vous ?"
    echo "  1. Thème statique/image (géré ici, depuis le dépôt d'assets BearGrubChanger)"
    echo "  2. Thème vidéo façon Fallout (script dédié, plus complet)"
    local sous_choix
    read -r -p "Votre choix [1-2] : " sous_choix

    if [ "$sous_choix" = "2" ]; then
        verifier_accel_video
        log_info "Les thèmes SDDM vidéo sont gérés par un script à part, plus complet"
        log_info "(installation des dépendances Qt6/multimédia, choix Wayland/X11, mode test avant application...)."
        log_info "Dépôt : https://github.com/PapaOursPolaire/SDDM-video"
        log_info "Téléchargez et lancez sddm-video.sh depuis ce dépôt pour l'installer."
        return 0
    fi

    command -v sddm >/dev/null 2>&1 || { installer_sddm || return 1; }

    if [ ! -d "$SDDM_THEMES_DIR" ]; then
        log_warn "Dossier des thèmes SDDM introuvable. Utilisez l'option 1 d'abord."
        return 1
    fi

    local themes=()
    for d in "$SDDM_THEMES_DIR"/*/; do
        [ -d "$d" ] || continue
        local nom; nom="$(basename "$d")"
        [ -f "$d/metadata.desktop" ] && themes+=("$nom")
    done
    choisir_dans_liste "Thèmes SDDM disponibles :" "${themes[@]}" || return 1
    local selected="$CHOIX_SELECTIONNE"
    local chemin_source="$SDDM_THEMES_DIR/$selected"

    sudo mkdir -p "$SDDM_DIR/$selected"
    sudo cp -r "$chemin_source"/* "$SDDM_DIR/$selected/"

    sudo mkdir -p "$SDDM_CONFIG_DIR"
    {
        echo "[Theme]"
        echo "Current=$selected"
    } | sudo tee "$SDDM_CONFIG_DIR/bear-theme.conf" >/dev/null

    log_ok "Thème SDDM '$selected' appliqué."
    log_info "Redémarrez SDDM pour voir le changement : sudo systemctl restart sddm"
    log_warn "Ne faites 'restart sddm' que depuis une console texte (Ctrl+Alt+F3), pas depuis votre session graphique en cours."
}

# ============================================================
# 6. FASTFETCH
# ============================================================

configurer_fastfetch() {
    if ! command -v fastfetch >/dev/null 2>&1; then
        log_info "fastfetch n'est pas installé, installation..."
        pkg_install fastfetch || { log_err "Échec installation fastfetch."; return 1; }
    fi

    mkdir -p "$FASTFETCH_CONFIG_DIR"

    echo "Source du logo :"
    echo "  1. Logo depuis le dépôt d'assets BearGrubChanger"
    echo "  2. Image locale (chemin de votre choix)"
    echo "  3. Logo intégré d'une autre distro (ex: Ubuntu, Fedora, Debian...)"
    echo "  4. Ne rien changer, juste (re)générer une config par défaut"
    local choix logo_type logo_source
    read -r -p "Votre choix [1-4] : " choix

    case "$choix" in
        1)
            if [ ! -d "$FASTFETCH_IMAGES_DIR" ] || [ -z "$(ls -A "$FASTFETCH_IMAGES_DIR" 2>/dev/null)" ]; then
                log_warn "Aucune image trouvée dans le dépôt. Utilisez l'option 1 (installation complète) d'abord."
                return 1
            fi
            local logos=()
            while IFS= read -r -d '' f; do logos+=("$(basename "$f")"); done \
                < <(find "$FASTFETCH_IMAGES_DIR" -maxdepth 1 -type f -print0)
            choisir_dans_liste "Logos disponibles :" "${logos[@]}" || return 1
            mkdir -p "$FASTFETCH_CONFIG_DIR/logos"
            cp "$FASTFETCH_IMAGES_DIR/$CHOIX_SELECTIONNE" "$FASTFETCH_CONFIG_DIR/logos/"
            logo_type="kitty"
            logo_source="$FASTFETCH_CONFIG_DIR/logos/$CHOIX_SELECTIONNE"
            ;;
        2)
            read -r -p "Chemin complet de l'image : " logo_source
            if [ ! -f "$logo_source" ]; then
                log_err "Fichier introuvable : $logo_source"
                return 1
            fi
            logo_type="kitty"
            ;;
        3)
            read -r -p "Nom du logo intégré (ex: Ubuntu, Fedora, Debian, Arch, openSUSE) : " logo_source
            [ -z "$logo_source" ] && logo_source="Linux"
            logo_type="builtin"
            ;;
        4|*)
            fastfetch --gen-config --gen-config-force 2>/dev/null || fastfetch --gen-config 2>/dev/null
            log_ok "Configuration fastfetch par défaut (re)générée dans $FASTFETCH_CONFIG_DIR/config.jsonc"
            return 0
            ;;
    esac

    if [ -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
        if ! confirm "Une configuration fastfetch existe déjà. La remplacer par une config propre avec ce logo ?"; then
            log_info "Annulé. Fichier de logo copié le cas échéant, mais config.jsonc non modifié."
            return 0
        fi
    fi

    # On écrit une config complète et cohérente plutôt que de patcher un
    # fichier JSONC existant (fragile à cause des commentaires autorisés).
    local logo_json
    if [ "$logo_type" = "builtin" ]; then
        logo_json="\"type\": \"builtin\", \"source\": \"$logo_source\""
    else
        logo_json="\"type\": \"kitty\", \"source\": \"$logo_source\""
    fi

    cat > "$FASTFETCH_CONFIG_DIR/config.jsonc" <<EOF
{
    "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        $logo_json,
        "padding": { "top": 1, "right": 2 }
    },
    "display": { "separator": " -> " },
    "modules": [
        "title",
        "separator",
        "os",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "de",
        "wm",
        "terminal",
        "cpu",
        "gpu",
        "memory",
        "disk",
        "break",
        "colors"
    ]
}
EOF
    log_ok "Configuration fastfetch appliquée avec le logo sélectionné."
    fastfetch 2>&1 | head -5
}

# ============================================================
# 6bis. SPLASHSCREEN KDE ET ICÔNES SYSTÈME
# ============================================================

activer_splashscreen_kde() {
    detecter_de_actif
    if [ "$CURRENT_DE" != "plasma" ]; then
        log_warn "KDE Plasma n'est pas détecté comme environnement actif. Cette option est spécifique à Plasma."
        return 1
    fi

    if [ ! -d "$REPO_DIR/splashscreens" ]; then
        log_warn "Dossier splashscreens introuvable. Utilisez l'option 1 (installation complète) d'abord."
        return 1
    fi

    local themes=() chemins=()
    for d in "$REPO_DIR/splashscreens"/*/; do
        [ -d "$d" ] || continue
        local qml
        qml=$(find "$d" -name 'Splash.qml' -type f | head -1)
        if [ -n "$qml" ]; then
            themes+=("$(basename "$d")")
            chemins+=("$d")
        fi
    done

    if [ "${#themes[@]}" -eq 0 ]; then
        log_warn "Aucun splashscreen valide (Splash.qml manquant) dans $REPO_DIR/splashscreens"
        return 1
    fi

    choisir_dans_liste "Splashscreens KDE disponibles :" "${themes[@]}" || return 1
    local index
    for i in "${!themes[@]}"; do
        [ "${themes[$i]}" = "$CHOIX_SELECTIONNE" ] && index=$i
    done
    local source_dir="${chemins[$index]}"

    local nom_theme="bearsplash"
    local dest_dir="$HOME/.local/share/plasma/look-and-feel/$nom_theme"

    rm -rf "$dest_dir"
    mkdir -p "$(dirname "$dest_dir")"
    cp -r "$source_dir" "$dest_dir"

    local metadata
    metadata=$(find "$dest_dir" -name 'metadata.desktop' -type f | head -1)
    if [ -n "$metadata" ]; then
        sed -i "s/^X-KDE-PluginInfo-Name=.*/X-KDE-PluginInfo-Name=$nom_theme/" "$metadata"
    else
        cat > "$dest_dir/metadata.desktop" <<EOF
[Desktop Entry]
Name=Bear Splash
Comment=Splashscreen personnalisé BearGrubChanger
X-KDE-PluginInfo-Author=BearGrubChanger
X-KDE-PluginInfo-Name=$nom_theme
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL
X-KDE-ServiceTypes=Plasma/LookAndFeel
Type=Service
EOF
    fi

    if [ ! -f "$dest_dir/contents/Splash.qml" ] && [ -z "$(find "$dest_dir" -name Splash.qml)" ]; then
        log_err "Splash.qml manquant après copie, structure invalide."
        return 1
    fi

    # Seule la clé ksplashrc est modifiée : on n'utilise volontairement PAS
    # lookandfeeltool -a, qui appliquerait un thème complet (couleurs,
    # curseurs, fond d'écran...) en plus du splash — bien plus invasif que
    # ce que demande cette option.
    local kwriteconfig
    kwriteconfig=$(command -v kwriteconfig6 || command -v kwriteconfig5)
    if [ -n "$kwriteconfig" ]; then
        "$kwriteconfig" --file ksplashrc --group KSplash --key Theme "$nom_theme"
        "$kwriteconfig" --file ksplashrc --group KSplash --key Engine "KSplashQML"
    else
        log_err "kwriteconfig introuvable, impossible d'activer le splashscreen automatiquement."
        return 1
    fi

    log_ok "Splashscreen '$CHOIX_SELECTIONNE' installé et activé pour le prochain démarrage de session."
    if confirm "Redémarrer plasmashell maintenant pour un aperçu rapide (sinon, effectif à la prochaine connexion) ?"; then
        (command -v kquitapp6 >/dev/null 2>&1 && kquitapp6 plasmashell) || (command -v kquitapp5 >/dev/null 2>&1 && kquitapp5 plasmashell)
        sleep 1
        (command -v kstart6 >/dev/null 2>&1 && kstart6 plasmashell &) || (kstart5 plasmashell & 2>/dev/null) || (plasmashell & disown)
    fi
}

appliquer_theme_icones() {
    local icons_repo_dir="$REPO_DIR/icons-themes"
    if [ ! -d "$icons_repo_dir" ]; then
        log_warn "Dossier icons-themes introuvable dans le dépôt. Utilisez l'option 1 d'abord."
        return 1
    fi

    local archives=()
    while IFS= read -r -d '' f; do archives+=("$(basename "$f")"); done \
        < <(find "$icons_repo_dir" -maxdepth 1 -type f \( -iname '*.tar.gz' -o -iname '*.tar.xz' -o -iname '*.tar.bz2' \
            -o -iname '*.tgz' -o -iname '*.tbz' -o -iname '*.zip' -o -iname '*.7z' \) -print0)

    if [ "${#archives[@]}" -eq 0 ]; then
        log_warn "Aucune archive de thème d'icônes trouvée (.tar.*, .zip, .7z) dans $icons_repo_dir"
        return 1
    fi

    choisir_dans_liste "Thèmes d'icônes disponibles :" "${archives[@]}" || return 1
    local archive="$icons_repo_dir/$CHOIX_SELECTIONNE"
    local dest_dir="$HOME/.local/share/icons"
    mkdir -p "$dest_dir"

    case "$archive" in
        *.tar.gz|*.tgz)  tar -xzf "$archive" -C "$dest_dir" ;;
        *.tar.xz)        tar -xJf "$archive" -C "$dest_dir" ;;
        *.tar.bz2|*.tbz) tar -xjf "$archive" -C "$dest_dir" ;;
        *.zip)
            command -v unzip >/dev/null 2>&1 || pkg_install unzip
            unzip -q "$archive" -d "$dest_dir"
            ;;
        *.7z)
            command -v 7z >/dev/null 2>&1 || pkg_install p7zip-full 2>/dev/null || pkg_install p7zip
            7z x "$archive" -o"$dest_dir" -y >/dev/null
            ;;
    esac

    fc-cache -f "$dest_dir" >/dev/null 2>&1

    local nom_theme
    nom_theme=$(find "$dest_dir" -maxdepth 1 -type d ! -path "$dest_dir" -printf '%f\n' | head -1)
    if [ -z "$nom_theme" ]; then
        log_warn "Thème extrait mais impossible d'en déterminer le nom automatiquement."
        log_info "Vérifiez le contenu de $dest_dir et appliquez-le manuellement dans les réglages d'apparence."
        return 0
    fi

    detecter_de_actif
    case "$CURRENT_DE" in
        gnome) gsettings set org.gnome.desktop.interface icon-theme "$nom_theme" ;;
        plasma)
            local kwriteconfig
            kwriteconfig=$(command -v kwriteconfig6 || command -v kwriteconfig5)
            [ -n "$kwriteconfig" ] && "$kwriteconfig" --file kdeglobals --group Icons --key Theme "$nom_theme"
            ;;
        xfce) xfconf-query -c xsettings -p /Net/IconThemeName -s "$nom_theme" 2>/dev/null ;;
        *) log_warn "Thème '$nom_theme' installé, appliquez-le manuellement dans les préférences d'apparence." ;;
    esac
    log_ok "Thème d'icônes '$nom_theme' installé et appliqué (si votre DE est supporté)."
}

# ============================================================
# 7. SYSTÈME (police, clavier, sons, nerdfonts)
# ============================================================

changer_police_systeme() {
    local dossier_polices="$LOCAL_DIR/fonts"
    local polices=()
    if [ -d "$dossier_polices" ]; then
        while IFS= read -r -d '' f; do polices+=("$(basename "$f")"); done \
            < <(find "$dossier_polices" -maxdepth 1 -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)
    fi
    if [ "${#polices[@]}" -eq 0 ]; then
        log_warn "Aucune police système trouvée dans $dossier_polices. Utilisez l'option 1 d'abord."
        return 1
    fi
    choisir_dans_liste "Polices système disponibles :" "${polices[@]}" || return 1
    local selected="$CHOIX_SELECTIONNE"

    sudo mkdir -p /usr/share/fonts/custom
    sudo cp "$dossier_polices/$selected" /usr/share/fonts/custom/
    sudo fc-cache -f >/dev/null 2>&1

    local famille
    famille=$(fc-query --format='%{family}' "$dossier_polices/$selected" 2>/dev/null | head -n1 | cut -d',' -f1)
    [ -z "$famille" ] && famille="${selected%.*}"

    appliquer_reglage_de "font" "$famille"
}

basculer_theme_clair_sombre() {
    choisir_dans_liste "Mode d'affichage :" "Clair" "Sombre" || return 1
    local mode="clair"
    [ "$CHOIX_SELECTIONNE" = "Sombre" ] && mode="dark" || mode="light"
    appliquer_reglage_de "theme" "$mode"
}

configurer_clavier_boot() {
    local dispo
    dispo=$(localectl list-x11-keymap-layouts 2>/dev/null | head -20)
    echo "Dispositions disponibles (aperçu) :"
    echo "$dispo"
    local layout
    read -r -p "Code de la disposition clavier à utiliser au boot (ex: fr, us, de) : " layout
    if [ -z "$layout" ]; then
        log_err "Aucune valeur saisie."
        return 1
    fi
    sudo localectl set-x11-keymap "$layout" 2>/dev/null
    sudo localectl set-keymap "$layout" 2>/dev/null
    maj_grub_var "GRUB_CMDLINE_LINUX_DEFAULT" "$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" | cut -d'"' -f2) vconsole.keymap=$layout"
    regenerer_grub
    log_ok "Disposition clavier '$layout' appliquée (console et X11)."
}

configurer_son_login() {
    if ! command -v canberra-gtk-play >/dev/null 2>&1 && ! command -v paplay >/dev/null 2>&1; then
        log_info "Installation des outils audio nécessaires..."
        pkg_install libcanberra-gtk3-module pulseaudio-utils 2>/dev/null
    fi
    local fichier_son
    read -r -p "Chemin du fichier son (.ogg/.wav) à jouer au login : " fichier_son
    if [ ! -f "$fichier_son" ]; then
        log_err "Fichier introuvable."
        return 1
    fi
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/bgc-login-sound.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=paplay "$fichier_son"
Hidden=false
X-GNOME-Autostart-enabled=true
Name=Son de connexion
EOF
    log_ok "Le son sera joué à chaque connexion graphique."
}

installer_theme_sonore() {
    detecter_de_actif
    case "$CURRENT_DE" in
        gnome) pkg_install sound-theme-freedesktop && gsettings set org.gnome.desktop.sound theme-name 'freedesktop' ;;
        plasma) pkg_install oxygen-sounds ;;
        *) log_warn "Thème sonore automatique non supporté pour '$CURRENT_DE', installation générique du thème freedesktop." ; pkg_install sound-theme-freedesktop ;;
    esac
    log_ok "Thème sonore installé."
}

installer_nerdfonts() {
    if ! command -v curl >/dev/null 2>&1; then
        pkg_install curl
    fi
    read -r -p "Nom de la Nerd Font à installer (ex: FiraCode, JetBrainsMono, Hack) : " police
    [ -z "$police" ] && police="JetBrainsMono"
    local dest="$HOME/.local/share/fonts/NerdFonts"
    mkdir -p "$dest"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${police}.zip"
    log_info "Téléchargement de $police depuis nerd-fonts..."
    if curl -fLo /tmp/nerdfont.zip "$url"; then
        unzip -o /tmp/nerdfont.zip -d "$dest" >/dev/null
        rm -f /tmp/nerdfont.zip
        fc-cache -f "$dest" >/dev/null 2>&1
        log_ok "Nerd Font '$police' installée dans $dest."
    else
        log_err "Téléchargement échoué. Vérifiez le nom exact sur https://www.nerdfonts.com/font-downloads"
    fi
}

# ============================================================
# 8. OUTILS (export/import profil, téléchargement vidéo)
# ============================================================

exporter_profil() {
    local dest
    read -r -p "Chemin du fichier d'export (ex: ~/bgc-profil.tar.gz) : " dest
    dest="${dest/#\~/$HOME}"
    [ -z "$dest" ] && dest="$HOME/bgc-profil.tar.gz"

    local elements=()
    [ -f "$GRUB_FILE" ] && elements+=("$GRUB_FILE")
    [ -d "$LOCAL_DIR" ] && elements+=("$LOCAL_DIR")
    [ -f /etc/plymouth/plymouthd.conf ] && elements+=("/etc/plymouth/plymouthd.conf")
    [ -d "$SDDM_CONFIG_DIR" ] && elements+=("$SDDM_CONFIG_DIR")
    [ -d "$FASTFETCH_CONFIG_DIR" ] && elements+=("$FASTFETCH_CONFIG_DIR")

    if [ "${#elements[@]}" -eq 0 ]; then
        log_warn "Rien à exporter (aucune configuration BearGrubChanger détectée)."
        return 1
    fi

    sudo tar -czf "$dest" "${elements[@]}" 2>/dev/null && \
        sudo chown "$USER:$USER" "$dest" && \
        log_ok "Profil exporté vers $dest"
}

importer_profil() {
    local source
    read -r -p "Chemin de l'archive à importer : " source
    source="${source/#\~/$HOME}"
    if [ ! -f "$source" ]; then
        log_err "Fichier introuvable."
        return 1
    fi

    # ── Vérification du contenu AVANT toute extraction ────────────────────
    # On liste les chemins de l'archive et on refuse tout ce qui sort du
    # périmètre attendu (boot/grub, home BearGrubChanger, plymouth, sddm,
    # fastfetch) ou qui contient une tentative de traversée de répertoire
    # (../). Une archive "tar -xzf ... -C /" en root sans ce contrôle est
    # une exécution de code arbitraire si l'archive est piégée.
    local contenu
    contenu=$(sudo tar -tzf "$source" 2>/dev/null) || {
        log_err "Archive invalide ou illisible (tar -tzf a échoué)."
        return 1
    }

    if [ -z "$contenu" ]; then
        log_err "Archive vide."
        return 1
    fi

    local chemins_suspects=()
    while IFS= read -r chemin; do
        # Rejet des traversées de répertoire et des chemins absolus déguisés
        case "$chemin" in
            *..*) chemins_suspects+=("$chemin (traversée de répertoire)") ;;
        esac
        # Le tar produit des chemins relatifs (boot/grub/..., home/user/...)
        # car -C / retire le / de tête ; on n'autorise que les préfixes
        # correspondant à ce que exporter_profil a pu produire.
        case "$chemin" in
            boot/grub/*|home/*/.grub-themes/*|etc/plymouth/*|etc/sddm.conf.d/*|home/*/.config/fastfetch/*) ;;
            *) chemins_suspects+=("$chemin (hors périmètre attendu)") ;;
        esac
    done <<< "$contenu"

    if [ "${#chemins_suspects[@]}" -gt 0 ]; then
        log_err "L'archive contient des chemins non conformes ou suspects :"
        printf '  - %s\n' "${chemins_suspects[@]}" | head -20
        log_err "Import refusé par sécurité (extraction root non vérifiée = risque d'écrasement de fichiers système)."
        return 1
    fi

    local nb_entrees
    nb_entrees=$(echo "$contenu" | wc -l)
    log_info "Contenu de l'archive ($nb_entrees entrée(s)) vérifié : conforme au périmètre BearGrubChanger."
    echo "$contenu" | head -15
    [ "$nb_entrees" -gt 15 ] && log_info "(... $(( nb_entrees - 15 )) entrées supplémentaires)"

    if ! confirm_dangereux "Ceci va écraser votre configuration BearGrubChanger actuelle (GRUB/Plymouth/SDDM/Fastfetch)."; then
        log_info "Import annulé."
        return 1
    fi

    # --no-same-owner : évite qu'un fichier avec un UID/GID arbitraire dans
    # l'archive ne recrée une propriété inattendue sur le système cible.
    sudo tar -xzf "$source" -C / --no-same-owner && \
        log_ok "Profil importé. Redémarrez pour appliquer les changements GRUB/Plymouth."
}

# ============================================================
# 10. INSTALLATION GLOBALE (option 1) ET MAJ (option 2)
# ============================================================

installer_assets() {
    log_info "Copie des thèmes, icônes, polices, Plymouth, SDDM..."
    sudo mkdir -p "$THEMES_DIR"
    [ -d "$REPO_DIR/themes" ]  && sudo cp -r "$REPO_DIR/themes/"*  "$THEMES_DIR/" 2>/dev/null
    mkdir -p "$LOCAL_DIR/icons" "$LOCAL_DIR/fonts"
    [ -d "$REPO_DIR/icons" ] && cp -r "$REPO_DIR/icons/"* "$LOCAL_DIR/icons/" 2>/dev/null
    [ -d "$REPO_DIR/fonts" ] && cp -r "$REPO_DIR/fonts/"* "$LOCAL_DIR/fonts/" 2>/dev/null
    if [ -d "$REPO_DIR/plymouth" ]; then
        sudo mkdir -p "$PLYMOUTH_DIR"
        sudo cp -r "$REPO_DIR/plymouth/"* "$PLYMOUTH_DIR/" 2>/dev/null
    fi
    if [ -d "$REPO_DIR/sddm" ]; then
        sudo mkdir -p "$SDDM_DIR"
        sudo cp -r "$REPO_DIR/sddm/"* "$SDDM_DIR/" 2>/dev/null
    fi
    log_ok "Fichiers installés."
}

installation_complete() {
    detecter_distribution
    verifier_et_installer_grub || return 1
    assurer_depot || return 1
    installer_assets
    forcer_menu_grub
    installer_plymouth
    installer_sddm
    regenerer_grub
    log_ok "Installation complète terminée."
}

# ============================================================
# 11. MENU PRINCIPAL
# ============================================================

afficher_menu() {
    echo
    echo "===== BearGrubChanger v3.1 ====="
    echo -e "\033[1;34mINSTALLATION & MAJ\033[0m"
    echo " 1.  Installer tous les thèmes/polices/icônes + GRUB + Plymouth + SDDM"
    echo " 2.  Mettre à jour tous les logiciels du système"
    echo -e "\033[1;34mGESTION GRUB\033[0m"
    echo " 3.  Changer le thème GRUB"
    echo " 4.  Appliquer une police pour le menu GRUB"
    echo " 5.  Remplacer les icônes GRUB"
    echo " 6.  Ajuster le délai de sélection GRUB"
    echo -e "\033[1;34mGESTION PLYMOUTH\033[0m"
    echo " 7.  Activer/choisir un thème Plymouth"
    echo " 8.  Plymouth animé depuis vidéo/GIF"
    echo -e "\033[1;34mGESTION LOGIN (SDDM)\033[0m"
    echo " 9.  Changer le thème SDDM"
    echo -e "\033[1;34mKDE PLASMA\033[0m"
    echo "10. Activer un splashscreen KDE Plasma"
    echo -e "\033[1;34mAPPARENCE SYSTÈME\033[0m"
    echo "11. Changer la police système"
    echo "12. Installer un thème d'icônes complet"
    echo "13. Changer le thème clair/sombre système"
    echo -e "\033[1;34mSYSTÈME\033[0m"
    echo "14. Configurer la disposition clavier au boot"
    echo "15. Configurer un son de login/boot"
    echo "16. Installer un thème sonore (GNOME/KDE)"
    echo "17. Installer des Nerd Fonts"
    echo -e "\033[1;34mFASTFETCH\033[0m"
    echo "18. Customiser Fastfetch"
    echo -e "\033[1;34mOUTILS\033[0m"
    echo "19. Export d'un profil complet"
    echo "20. Import d'un profil complet"
    echo -e "\033[1;34mQUITTER\033[0m"
    echo " 0.  Quitter"
}

menu_principal() {
    [ -n "$PKG_MANAGER" ] || detecter_distribution
    while true; do
        afficher_menu
        local opt
        read -r -p "Choix : " opt
        case "$opt" in
            1)  installation_complete ;;
            2)  pkg_maj_systeme ;;
            3)  appliquer_theme_grub ;;
            4)  appliquer_police_grub ;;
            5)  remplacer_icones_grub ;;
            6)  ajuster_delai_grub ;;
            7)  choisir_theme_plymouth ;;
            8)  plymouth_depuis_media ;;
            9)  choisir_theme_sddm ;;
            10) activer_splashscreen_kde ;;
            11) changer_police_systeme ;;
            12) appliquer_theme_icones ;;
            13) basculer_theme_clair_sombre ;;
            14) configurer_clavier_boot ;;
            15) configurer_son_login ;;
            16) installer_theme_sonore ;;
            17) installer_nerdfonts ;;
            18) configurer_fastfetch ;;
            19) exporter_profil ;;
            20) importer_profil ;;
            0)  echo "Merci d'utiliser BearGrubChanger !"; exit 0 ;;
            *)  log_err "Option invalide." ;;
        esac
    done
}

# ============================================================
# POINT D'ENTRÉE
# ============================================================

if [ "$EUID" -eq 0 ]; then
    log_warn "Ne lancez pas ce script directement en root : il utilise sudo lui-même quand nécessaire."
fi

menu_principal
