#!/bin/bash

# Gif to Plymouth Theme Converter - by PapaOursPolaire (GPTC)
# Vérifie les dépendances
command -v ffmpeg >/dev/null || { echo "❌ ffmpeg manquant. Installe-le."; exit 1; }

# Entrée : nom du fichier gif
GIF="$1"
THEME_NAME="$2"

if [ -z "$GIF" ] || [ -z "$THEME_NAME" ]; then
    echo "Utilisation : $0 fichier.gif nom_du_theme"
    exit 1
fi

# Crée le dossier de thème
mkdir -p "$THEME_NAME"
cd "$THEME_NAME" || exit 1

# Extraction des frames PNG
echo "📤 Extraction des frames PNG depuis $GIF..."
ffmpeg -i "../$GIF" background-%04d.png

# Nombre d’images
TOTAL=$(ls background-*.png | wc -l)

# Fichier .plymouth
cat <<EOF > "$THEME_NAME.plymouth"
[Plymouth Theme]
Name=$THEME_NAME
Description=Animation basée sur $GIF
ModuleName=script
EOF

# Fichier .script
cat <<EOF > "$THEME_NAME.script"
for (i = 0; i < $TOTAL; i++) {
    img = Image("background-" + sprintf("%04d", i + 1) + ".png");
    screen.clear();
    screen.draw_image(img, 0, 0, screen_width, screen_height);
    sleep(0.05);
}
EOF

echo "✅ Thème $THEME_NAME généré avec $TOTAL images."
