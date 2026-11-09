# Synchronisation : mode d'emploi

## Au quotidien

1. **En arrivant :** double-clic sur `SYNC.bat` (ou `sync.command` sur Mac et Linux).
2. **En partant :** attends 2 ou 3 secondes après ta dernière frappe, puis relance-le.

Obsidian peut rester ouvert. Les changements n'arrivent chez l'autre que lorsqu'il lance la synchronisation à son tour.

## Inviter quelqu'un

Sur GitHub, dans ton dépôt : **Settings**, **Collaborators**, **Add people**. Cette personne lance ensuite `INSTALLER.bat` et choisit « Rejoindre ».

## Si deux personnes ont modifié la même chose

- **Une note :** les deux versions sont gardées à la suite. Rien n'est perdu, il reste à faire le tri.
- **Une image, un PDF, un tableur, une toile :** ton dossier prend la version de GitHub, et la tienne part dans une branche `sauvegarde-…` sur GitHub.

Pour éviter ça : synchronisez souvent, et séparez vos notes, par exemple un dossier par personne.

## Les messages

| Message | Que faire |
|---|---|
| `Tout est à jour sur GitHub` | Rien |
| `Impossible de joindre GitHub` | Vérifie ta connexion et l'invitation |
| `Envoi impossible` | Accepte l'invitation reçue par email |
| `fichiers ont disparu du dossier` | Vérifie le dossier avant de confirmer |
| `GitHub refuse les fichiers de plus de 100 Mo` | Retire ce fichier du coffre |
| `Google Drive surveille ce dossier` | Retire le coffre de Google Drive |

## À garder en tête

- **Garde le dépôt privé**, surtout si tes notes sont personnelles.
- **Pas de Google Drive, OneDrive, Dropbox ni iCloud** sur ce dossier : ils peuvent abîmer le dépôt.
- **Pas de mots de passe** dans les notes.
