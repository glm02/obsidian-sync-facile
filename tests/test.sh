#!/bin/sh
# Teste l'outil de bout en bout sous Windows (Git Bash), avec un faux GitHub local.
# Rien n'est créé sur un vrai compte : "gh" est remplacé par tests/gh.cmd.
R=$(cd "$(dirname "$0")/.." && pwd -W)
R_POSIX=$(cd "$(dirname "$0")/.." && pwd)
T="$(cd "${TMPDIR:-/tmp}" && pwd -W)/essai_obsidian_$$"
rm -rf "$T"; mkdir -p "$T"
echecs=0
ok() { if eval "$2"; then echo "OK    $1"; else echo "ECHEC $1"; echecs=$((echecs+1)); fi; }
inst() { powershell -NoProfile -ExecutionPolicy Bypass -File "$R/installer.ps1" -NonInteractif "$@" > "$T/sortie.txt" 2>&1; code=$?; }
sync() { powershell -NoProfile -ExecutionPolicy Bypass -File "$1/sync-obsidian.ps1" -NoPause > "$T/sortie.txt" 2>&1; code=$?; }

export FAUX_GH_LOG="$T/gh.log"
export FAUX_DISTANT="$T/gh.git"
# Chemin au format Git Bash : le « C: » d'un chemin Windows couperait le PATH en deux.
export PATH="$R_POSIX/tests:$PATH"
# Sécurité : sans le faux gh, les tests créeraient un vrai dépôt sur le compte connecté.
GH_VU=$(powershell -NoProfile -Command "(Get-Command gh).Source" | tr -d '\r')
case "$GH_VU" in
  *tests\\gh.cmd) ;;
  *) echo "ARRET : gh n'est pas le faux ($GH_VU). Rien n'a été lancé."; rm -rf "$T"; exit 3 ;;
esac
git init -q --bare -b main "$T/gh.git"

echo "--- 1. Créer : coffre avec espaces et accents, gitignore existant"
C="$T/Mon coffre é"; mkdir -p "$C/.obsidian" "$C/Notes"
printf 'Bonjour\n' > "$C/Notes/Première note.md"; echo '{}' > "$C/.obsidian/app.json"
echo 'SECRET=1' > "$C/.env"; printf 'mes-regles/\n' > "$C/.gitignore"
inst -Mode creer -Dossier "$C" -NomDepot coffre-test -Prenom Alice -Inviter ami-test
ok "code de sortie 0" '[ "$code" = 0 ]'
ok "dépôt créé en privé" 'grep -q "repo create coffre-test --private --source . --remote origin --push" "$T/gh.log"'
ok "invitation demandée" 'grep -q "collaborators/ami-test" "$T/gh.log"'
L=$(git -C "$T/gh.git" -c core.quotepath=false ls-tree -r main --name-only)
ok "la note est envoyée" 'echo "$L" | grep -q "Notes/Première note.md"'
ok "les scripts sont envoyés" 'echo "$L" | grep -q "^SYNC.bat$" && echo "$L" | grep -q "^sync.command$"'
ok ".env non envoyé" '! echo "$L" | grep -q "\.env"'
ok ".obsidian non envoyé" '! echo "$L" | grep -q "^\.obsidian/"'
ok "gitignore existant conservé" 'grep -q "mes-regles/" "$C/.gitignore" && grep -q "^\.env$" "$C/.gitignore"'
ok "sync.command exécutable" 'git -C "$T/gh.git" ls-tree main sync.command | grep -q "^100755"'
ok "SYNC.bat en CRLF" 'git -C "$C" show HEAD:SYNC.bat >/dev/null && od -c "$C/SYNC.bat" | grep -q "\\\\r"'

echo "--- 2. Créer : refus sans rien casser"
inst -Mode creer -Dossier "$C" -NomDepot x
ok "dossier déjà relié refusé" '[ "$code" = 1 ] && grep -a -q "déjà relié" "$T/sortie.txt"'
D="$T/OneDrive/coffre"; mkdir -p "$D"; echo a > "$D/n.md"
inst -Mode creer -Dossier "$D" -NomDepot x
ok "OneDrive refusé" '[ "$code" = 1 ] && grep -a -q "OneDrive" "$T/sortie.txt" && [ ! -e "$D/.git" ]'
D2="$T/surveille"; mkdir -p "$D2/.tmp.driveupload"; echo a > "$D2/n.md"
inst -Mode creer -Dossier "$D2" -NomDepot x
ok "dossier surveillé par Drive refusé" '[ "$code" = 1 ] && [ ! -e "$D2/.git" ]'
inst -Mode creer -Dossier "$T/inexistant" -NomDepot x
ok "dossier inexistant refusé" '[ "$code" = 1 ]'

echo "--- 3. Rejoindre"
B="$T/Chez Bob"
inst -Mode rejoindre -Distant "$T/gh.git" -Dossier "$B" -Prenom Bob
ok "coffre récupéré" '[ "$code" = 0 ] && [ -f "$B/Notes/Première note.md" ]'
inst -Mode rejoindre -Distant "$T/gh.git" -Dossier "$B" -Prenom Bob
ok "dossier non vide refusé" '[ "$code" = 1 ] && grep -a -q "pas vide" "$T/sortie.txt"'
inst -Mode rejoindre -Distant "$T/absent.git" -Dossier "$T/Autre" -Prenom Bob
ok "adresse fausse : message clair" '[ "$code" = 1 ] && grep -a -q "invitation" "$T/sortie.txt"'
git init -q --bare -b main "$T/nu.git"; git clone -q "$T/nu.git" "$T/nu_s" 2>/dev/null
echo x > "$T/nu_s/note.md"; git -C "$T/nu_s" add -A; git -C "$T/nu_s" -c user.name=i -c user.email=i@x commit -qm i; git -C "$T/nu_s" push -q origin main
inst -Mode rejoindre -Distant "$T/nu.git" -Dossier "$T/Nu" -Prenom Bob
ok "dépôt sans scripts : scripts ajoutés" '[ -f "$T/Nu/SYNC.bat" ]'

echo "--- 4. Synchroniser à deux"
printf '\nde Alice\n' >> "$C/Notes/Première note.md"; sync "$C"; sync "$B"
ok "Bob reçoit la note" 'grep -q "de Alice" "$B/Notes/Première note.md"'
printf '\nLIGNE-A\n' >> "$C/Notes/Première note.md"; printf '\nLIGNE-B\n' >> "$B/Notes/Première note.md"
sync "$C"; sync "$B"; sync "$C"
ok "même note : les deux versions gardées" 'grep -q LIGNE-A "$C/Notes/Première note.md" && grep -q LIGNE-B "$C/Notes/Première note.md"'
ok "aucun marqueur de conflit" '! grep -q "<<<<<<<" "$C/Notes/Première note.md"'
printf 'A' > "$C/image.png"; sync "$C"; sync "$B"
printf 'VERSION-A' > "$C/image.png"; printf 'VERSION-B' > "$B/image.png"; sync "$C"; sync "$B"
ok "fichier binaire : code conflit" '[ "$code" = 2 ]'
BR=$(git -C "$T/gh.git" branch --format='%(refname:short)' | grep sauvegarde | head -1)
ok "version de Bob sauvegardée" 'git -C "$T/gh.git" show "$BR:image.png" | grep -q VERSION-B'
ok "Bob a la version de GitHub" 'grep -q VERSION-A "$B/image.png"'

echo "--- 5. Garde-fous de SYNC"
i=1; while [ $i -le 12 ]; do echo x > "$C/n$i.md"; i=$((i+1)); done; sync "$C"; sync "$B"
AVANT=$(git -C "$T/gh.git" rev-parse main)
rm "$C"/n*.md; sync "$C"
ok "12 fichiers disparus : rien envoyé" '[ "$code" = 1 ] && [ "$AVANT" = "$(git -C "$T/gh.git" rev-parse main)" ]'
git -C "$C" checkout -q -- .
truncate -s 96M "$C/gros.bin"; sync "$C"
ok "fichier de 96 Mo : rien envoyé" '[ "$code" = 1 ] && [ "$AVANT" = "$(git -C "$T/gh.git" rev-parse main)" ]'
rm "$C/gros.bin"
mkdir "$C/.tmp.driveupload"; sync "$C"
ok "Drive signalé, sans bloquer" '[ "$code" = 0 ] && grep -a -q "Google Drive" "$T/sortie.txt"'
rmdir "$C/.tmp.driveupload"
sync "$C"; sync "$B"

echo "--- 6. sync.command (Mac et Linux, simulé sous Git Bash)"
printf '\nvia sh\n' >> "$B/Notes/Première note.md"
sh "$B/sync.command" < /dev/null > "$T/sortie.txt" 2>&1; code=$?
ok "envoi réussi" '[ "$code" = 0 ] && grep -a -q "Tout est à jour" "$T/sortie.txt"'
sync "$C"
ok "Alice reçoit" 'grep -q "via sh" "$C/Notes/Première note.md"'
i=1; while [ $i -le 12 ]; do echo x > "$B/m$i.md"; i=$((i+1)); done; sh "$B/sync.command" < /dev/null >/dev/null 2>&1
AVANT=$(git -C "$T/gh.git" rev-parse main); rm "$B"/m*.md
sh "$B/sync.command" < /dev/null > "$T/sortie.txt" 2>&1; code=$?
ok "12 fichiers disparus : rien envoyé" '[ "$code" = 1 ] && [ "$AVANT" = "$(git -C "$T/gh.git" rev-parse main)" ]'
git -C "$B" checkout -q -- .
truncate -s 96M "$B/gros.bin"; sh "$B/sync.command" < /dev/null > "$T/sortie.txt" 2>&1; code=$?
ok "fichier de 96 Mo : rien envoyé" '[ "$code" = 1 ] && grep -a -q "100 Mo" "$T/sortie.txt"'
rm "$B/gros.bin"

echo "--- 7. Inviter sans GitHub CLI : pas de faux succès"
git init -q --bare -b main "$T/sansgh.git"
S="$T/Sans gh"; mkdir -p "$S"; echo a > "$S/n.md"
( PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vE 'GitHub CLI|/tests$' | paste -sd: -); inst -Mode creer -Dossier "$S" -Distant "$T/sansgh.git" -Prenom Alice -Inviter quelquun )
ok "le coffre est quand même envoyé" 'git -C "$T/sansgh.git" rev-parse -q --verify main >/dev/null'
ok "aucune invitation annoncée" '! grep -a -q "est invité" "$T/sortie.txt"'
ok "explication affichée" 'grep -a -q "Settings > Collaborators" "$T/sortie.txt"'

rm -rf "$T"
echo; if [ "$echecs" = 0 ]; then echo "TOUT EST BON"; else echo "$echecs ECHEC(S)"; exit 1; fi
