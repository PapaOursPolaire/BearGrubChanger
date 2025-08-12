import os
import sys

def remove_ttf_files(folder):
    if not os.path.isdir(folder):
        print("Erreur : dossier non trouvé.")
        return

    ttf_files = [f for f in os.listdir(folder) if f.lower().endswith('.ttf')]

    if not ttf_files:
        print("Aucun fichier .ttf trouvé dans ce dossier.")
        return

    print(f"Suppression de {len(ttf_files)} fichiers .ttf dans : {folder}\n")
    for ttf in ttf_files:
        ttf_path = os.path.join(folder, ttf)
        try:
            os.remove(ttf_path)
            print(f"Supprimé : {ttf}")
        except Exception as e:
            print(f"Erreur en supprimant {ttf} : {e}")

    print("\nSuppression terminée.")

def main():
    if len(sys.argv) > 1:
        folder = sys.argv[1]
    else:
        folder = input("Chemin complet du dossier à nettoyer des .ttf : ").strip()

    remove_ttf_files(folder)

if __name__ == "__main__":
    main()
