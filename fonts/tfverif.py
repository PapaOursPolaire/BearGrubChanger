import os
import sys
import subprocess

# Modifie ce chemin selon ton installation de FontForge
FONTFORGE_PATH = r"C:\Program Files (x86)\FontForgeBuilds\bin\fontforge.exe"

def is_pf2_valid(pf2_path):
    """
    Tente d'ouvrir le fichier .pf2 avec FontForge.
    Retourne True si l'ouverture réussit, False sinon.
    """
    # On utilise une commande FontForge minimaliste qui ouvre puis ferme la police
    try:
        subprocess.run([
            FONTFORGE_PATH,
            "-lang=ff",
            "-c",
            f'Open("{pf2_path.replace("\\", "/")}"); Close();'
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False

def check_and_clean_pf2(folder):
    if not os.path.isdir(folder):
        print("Erreur : dossier non trouvé.")
        return

    pf2_files = [f for f in os.listdir(folder) if f.lower().endswith(".pf2")]

    if not pf2_files:
        print("Aucun fichier .pf2 trouvé dans ce dossier.")
        return

    print(f"Vérification de {len(pf2_files)} fichiers .pf2 dans : {folder}\n")

    removed_count = 0
    for pf2 in pf2_files:
        pf2_full_path = os.path.join(folder, pf2)
        if not is_pf2_valid(pf2_full_path):
            try:
                os.remove(pf2_full_path)
                print(f"Corrompu et supprimé : {pf2}")
                removed_count += 1
            except Exception as e:
                print(f"Erreur en supprimant {pf2} : {e}")
        else:
            print(f"Valide : {pf2}")

    print(f"\nVérification terminée. {removed_count} fichier(s) corrompu(s) supprimé(s).")

def main():
    if len(sys.argv) > 1:
        folder = sys.argv[1]
    else:
        folder = input("Chemin complet du dossier à vérifier les .pf2 : ").strip()

    check_and_clean_pf2(folder)

if __name__ == "__main__":
    main()
