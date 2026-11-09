# Obsidian Sync Facile

Synchronise un coffre Obsidian avec GitHub en deux double-clics, seul entre plusieurs PC ou à plusieurs. Aucune commande à taper sur Windows, aucune extension à installer. C'est gratuit.

## Démarrer sur Windows

1. **Télécharge l'outil :** bouton vert **Code**, puis **Download ZIP**. Décompresse le dossier.
2. **Double-clique sur `INSTALLER.bat`.**
3. **Choisis :**
   - **1** pour mettre ton coffre sur GitHub ;
   - **2** pour récupérer un coffre existant, celui d'un ami ou le tien sur un autre PC.
4. **Dans Obsidian :** « Ouvrir un dossier en tant que coffre », puis choisis le dossier indiqué à la fin.

L'installateur propose d'installer Git et GitHub CLI s'ils manquent, puis ouvre ton navigateur pour te connecter à GitHub. Il te faut un [compte GitHub](https://github.com/signup), gratuit.

Windows peut afficher un avertissement au lancement d'un fichier téléchargé : clique sur **Informations complémentaires**, puis **Exécuter quand même**. Tu peux lire `installer.ps1` avant, c'est un simple script.

## Ensuite, au quotidien

Double-clique sur **`SYNC.bat`**, dans le dossier de ton coffre, **en arrivant** et **en partant**. Il enregistre tes modifications, récupère celles des autres et envoie le tout. Obsidian affiche les changements sans redémarrer.

## À plusieurs

L'installateur te propose d'inviter quelqu'un avec son pseudo GitHub, et t'affiche l'adresse à lui donner. Cette personne accepte l'invitation reçue par email, lance `INSTALLER.bat`, choisit **2** et colle l'adresse.

Si vous modifiez le même endroit d'une note, **les deux versions sont gardées à la suite**. Pour une image, un PDF ou un tableur, ta version est mise de côté dans une branche `sauvegarde-…` sur GitHub.

## Ce que l'outil fait pour toi

- **Dépôt privé à la création.** Si tu passes par la solution de secours, c'est à toi de cocher « Private » sur GitHub.
- **Réglages Obsidian non partagés** : chacun garde son thème et ses fenêtres.
- **Fichiers `.env`, clés et autres secrets courants ignorés.** Ce filtre repose sur les noms de fichiers : il ne lit pas tes notes, alors n'y mets pas de mots de passe.
- **Coffre sur Google Drive, OneDrive, Dropbox ou iCloud refusé**, car ces services peuvent abîmer le dépôt.
- **Blocage si beaucoup de fichiers disparaissent d'un coup**, et si un fichier dépasse la limite de 100 Mo de GitHub.

## Limites

- **Pas de temps réel :** les changements n'arrivent que lorsque chacun synchronise.
- **Pas de téléphone :** l'outil fonctionne sur ordinateur. Sur mobile, regarde [Obsidian Sync](https://obsidian.md/sync), le service officiel payant.
- **Pas de synchronisation automatique :** pour la déclencher toutes les X minutes, regarde l'extension communautaire Obsidian Git.

## Sur Mac et Linux

L'installateur est réservé à Windows pour l'instant. Avec [Git](https://git-scm.com/downloads) et [GitHub CLI](https://cli.github.com) installés, depuis le dossier décompressé de l'outil :

```sh
# Mettre son coffre sur GitHub
cp modele/.gitignore modele/.gitattributes modele/SYNC.bat modele/sync-obsidian.ps1 modele/sync.command "CHEMIN/DU/COFFRE/"
cd "CHEMIN/DU/COFFRE"
chmod +x sync.command
git init -b main && git add -A && git commit -m "Premier envoi du coffre"
gh auth login --web --git-protocol https
gh repo create mon-coffre --private --source . --remote origin --push

# Ou récupérer un coffre existant
git clone https://github.com/PSEUDO/mon-coffre.git
```

Ensuite, lance `sync.command`. Si macOS bloque le double-clic, fais un clic droit, puis **Ouvrir**.

Ce script a été testé sous Git Bash, pas encore sur un vrai Mac. Les retours sont bienvenus.

## Vérifier l'outil

`sh tests/test.sh` lance les tests sous Windows, avec Git Bash. Ils utilisent un faux GitHub local et ne créent rien sur ton compte.

## Licence

[MIT](LICENSE)
