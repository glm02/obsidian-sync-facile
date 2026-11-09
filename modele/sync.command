#!/bin/sh
# Synchronise le coffre Obsidian avec GitHub, sur Mac et Linux.
# Ordre : 1) on enregistre ses modifs, 2) on récupère celles des autres, 3) on envoie le tout.
cd "$(dirname "$0")" || exit 1

# Dans un terminal ouvert par double-clic, garder la fenêtre pour lire le résultat.
fin() { echo; if [ -t 0 ]; then printf "Appuie sur Entrée pour fermer "; read -r _; fi; exit "$1"; }

echo; echo "=== Synchronisation du coffre ==="; echo

command -v git >/dev/null 2>&1 || { echo "  !!  Git n'est pas installé : https://git-scm.com/downloads"; fin 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "  !!  Ce dossier n'est pas relié à GitHub."; fin 1; }

git config core.quotepath false
if [ -z "$(git config user.name)" ]; then
  if [ -t 0 ]; then printf "  Premier lancement : ton prénom (pour l'historique) : "; read -r nom; else nom=Moi; fi
  git config user.name "$nom"
  git config user.email "$(printf '%s' "$nom" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')@users.noreply.github.com"
fi
nom=$(git config user.name)
branche=$(git symbolic-ref --short HEAD)

git add -A 2>/dev/null

# GitHub refuse les fichiers de plus de 100 Mo : mieux vaut le dire avant d'échouer.
gros=$(git diff --cached --name-only --diff-filter=AM -z | xargs -0 -I{} sh -c 'test -f "$1" && test "$(wc -c < "$1")" -gt 99614720 && printf "%s\n" "$1"' _ {} | head -1)
if [ -n "$gros" ]; then
  git reset -q
  echo "  !!  GitHub refuse les fichiers de plus de 100 Mo : $gros"
  echo "  !!  Retire-le du coffre, puis relance. Rien n'a été envoyé."
  fin 1
fi

# Beaucoup de fichiers disparus d'un coup, c'est presque toujours un accident (dossier déplacé).
nb=$(git diff --cached --name-only --diff-filter=D | wc -l | tr -d ' ')
if [ "$nb" -gt 10 ]; then
  echo "  !!  $nb fichiers ont disparu du dossier."
  rep=n
  if [ -t 0 ]; then printf "  C'est bien voulu ? Les supprimer aussi sur GitHub ? (o/N) "; read -r rep; fi
  case "$rep" in
    [oOyY]*) ;;
    *) git reset -q; echo "  !!  Par sécurité, rien n'a été envoyé."; fin 1 ;;
  esac
fi

if ! git diff --cached --quiet; then
  git commit -q -m "Modifs de $nom le $(date '+%Y-%m-%d %H:%M')"
  echo "  OK  Tes modifications sont enregistrées."
else
  echo "  ..  Aucune modification de ton côté."
fi

# Deux essais : si quelqu'un envoie pile entre notre récupération et notre envoi, il suffit de recommencer.
for essai in 1 2; do
  echo "  ..  Récupération de la dernière version sur GitHub..."
  git fetch -q origin || { echo "  !!  Impossible de joindre GitHub (connexion ? invitation acceptée ?)."; fin 1; }
  if git rev-parse --verify -q "origin/$branche" >/dev/null; then
    if ! git rebase -q "origin/$branche" >/dev/null 2>&1; then
      # Les notes se fusionnent seules : on n'arrive ici que pour un fichier non fusionnable.
      git rebase --abort >/dev/null 2>&1
      secours="sauvegarde-$(printf '%s' "$nom" | tr -cd 'A-Za-z0-9')-$(date +%Y%m%d-%H%M)"
      git branch "$secours"
      if ! git push -q origin "$secours" >/dev/null 2>&1; then
        echo "  !!  CONFLIT, et la sauvegarde sur GitHub a échoué. Rien n'a été modifié."
        fin 1
      fi
      git reset -q --hard "origin/$branche"
      echo "  !!  CONFLIT : un même fichier non fusionnable a été modifié des deux côtés."
      echo "  !!  Ton dossier contient la version de GitHub. La tienne est sur la branche '$secours'."
      fin 2
    fi
  fi
  if git push -q -u origin "$branche" >/dev/null 2>&1; then
    echo "  OK  Tout est à jour sur GitHub."
    fin 0
  fi
  echo "  ..  GitHub a refusé l'envoi (quelqu'un vient d'envoyer ?), nouvel essai..."
done
echo "  !!  Envoi impossible. As-tu accepté l'invitation GitHub reçue par email ?"
fin 1
