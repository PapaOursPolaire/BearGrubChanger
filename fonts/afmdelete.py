import os
import sys

def remove_afm_files(folder):
    if not os.path.isdir(folder):
        print("Erreur : dossier non trouvé.")
        return

    afm_files = [f for f in os.listdir(folder) if f.lower().endswith('.afm')]

    if not afm_files:
        print("Aucun fichier .afm trouvé dans ce dossier.")
        return

    print(f"Suppression de {len(afm_files)} fichiers .afm dans : {folder}\n")
    for afm in afm_files:
        afm_path = os.path.join(folder, afm)
        try:
            os.remove(afm_path)
            print(f"Supprimé : {afm}")
        except Exception as e:
            print(f"Erreur en supprimant {afm} : {e}")

    print("\nSuppression terminée.")

def main():
    if len(sys.argv) > 1:
        folder = sys.argv[1]
    else:
        folder = input("Chemin complet du dossier à nettoyer des .afm : ").strip()

    remove_afm_files(folder)

if __name__ == "__main__":
    main()
