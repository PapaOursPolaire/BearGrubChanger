import os
import sys
import subprocess

# Modifie ce chemin si besoin
FONTFORGE_PATH = r"C:\Program Files (x86)\FontForgeBuilds\bin\fontforge.exe"

def convert_ttf_to_pf2(ttf_path):
    pf2_path = os.path.splitext(ttf_path)[0] + ".pf2"

    # Remplacer \ par / pour que FontForge puisse lire correctement
    ttf_ff_path = ttf_path.replace("\\", "/")
    pf2_ff_path = pf2_path.replace("\\", "/")

    try:
        subprocess.run([
            FONTFORGE_PATH,
            "-lang=ff",
            "-c",
            f'Open("{ttf_ff_path}"); Generate("{pf2_ff_path}"); Close();'
        ], check=True)
        print(f"Converti : {os.path.basename(ttf_path)} -> {os.path.basename(pf2_path)}")

        os.remove(ttf_path)
        print(f"Supprimé : {os.path.basename(ttf_path)}")
    except subprocess.CalledProcessError:
        print(f"Erreur lors de la conversion : {os.path.basename(ttf_path)}")

def main():
    if len(sys.argv) > 1:
        folder = sys.argv[1]
    else:
        folder = input("Chemin complet du dossier contenant les .ttf : ").strip()

    if not os.path.isdir(folder):
        print("Erreur : dossier non trouvé.")
        sys.exit(1)

    ttf_files = [f for f in os.listdir(folder) if f.lower().endswith(".ttf")]
    if not ttf_files:
        print("Aucun fichier .ttf trouvé dans ce dossier.")
        sys.exit(0)

    print(f"Conversion des {len(ttf_files)} fichiers .ttf dans : {folder}\n")
    for ttf in ttf_files:
        ttf_full_path = os.path.join(folder, ttf)
        convert_ttf_to_pf2(ttf_full_path)

    print("\nConversion terminée.")

if __name__ == "__main__":
    main()
