# Synchronise le coffre Obsidian avec GitHub.
# Ordre : 1) on enregistre ses modifs, 2) on récupère celles des autres, 3) on envoie le tout.
# Obsidian peut rester ouvert : il recharge tout seul les fichiers que git vient de changer.
param([switch]$NoPause)

$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath $PSScriptRoot
# PowerShell 5.1 lit la sortie de git dans un autre encodage que l'UTF-8 : sans ça, les accents sont cassés.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Fin($code) {
    Write-Host ""
    if (-not $NoPause) { Read-Host "Appuie sur Entrée pour fermer" | Out-Null }
    exit $code
}
function Ok($msg)     { Write-Host "  OK  $msg" -ForegroundColor Green }
function Info($msg)   { Write-Host "  ..  $msg" -ForegroundColor Cyan }
function Erreur($msg) { Write-Host "  !!  $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "=== Synchronisation du coffre ===" -ForegroundColor White
Write-Host ""

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Erreur "Git n'est pas installé : https://git-scm.com/download/win"
    Fin 1
}
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    Erreur "Ce dossier n'est pas relié à GitHub. Lance d'abord INSTALLER.bat."
    Fin 1
}
if ((Test-Path -LiteralPath '.tmp.driveupload') -or (Test-Path -LiteralPath '.tmp.drivedownload')) {
    Erreur "Attention : Google Drive surveille ce dossier, et il peut abîmer le dépôt."
    Erreur "Retire-le dans les préférences de Google Drive, rubrique « Mon ordinateur »."
}

git config core.quotepath false
$nom = git config user.name
if (-not $nom) {
    $nom = if ($NoPause) { 'Moi' } else { Read-Host "  Premier lancement : ton prénom (pour l'historique)" }
    git config user.name "$nom"
    git config user.email "$($nom.ToLower() -replace '[^a-z0-9]', '')@users.noreply.github.com"
}

$branche = git symbolic-ref --short HEAD
$date = Get-Date -Format 'yyyy-MM-dd HH:mm'

# --- 1) Enregistrer ses propres modifs --------------------------------------
git add -A 2> $null

# GitHub refuse les gros fichiers : mieux vaut le dire avant d'échouer sur un message obscur.
$gros = @(git diff --cached --name-only --diff-filter=AM | Where-Object {
    (Test-Path -LiteralPath $_) -and ((Get-Item -LiteralPath $_).Length -gt (95MB))
})
if ($gros.Count -gt 0) {
    git reset -q
    Erreur "GitHub refuse les fichiers de plus de 100 Mo : $($gros[0])"
    Erreur "Retire-le du coffre, puis relance. Rien n'a été envoyé."
    Fin 1
}

# Beaucoup de fichiers disparus d'un coup, c'est presque toujours un accident (dossier déplacé).
$supprimes = @(git diff --cached --name-only --diff-filter=D)
if ($supprimes.Count -gt 10) {
    Erreur "$($supprimes.Count) fichiers ont disparu du dossier (ex. : $(Split-Path $supprimes[0] -Leaf))."
    $rep = if ($NoPause) { 'n' } else { Read-Host "  C'est bien voulu ? Les supprimer aussi sur GitHub ? (o/N)" }
    if ($rep -notmatch '^[oOyY]') {
        git reset -q
        Erreur "Par sécurité, rien n'a été envoyé."
        Fin 1
    }
}

git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    $resume = (git diff --cached --name-only | ForEach-Object { Split-Path $_ -Leaf }) -join ', '
    if ($resume.Length -gt 60) { $resume = $resume.Substring(0, 57) + '...' }
    git commit -q -m "Modifs de $nom le $date : $resume"
    Ok "Tes modifications sont enregistrées."
} else {
    Info "Aucune modification de ton côté."
}

# --- 2) Récupérer celles des autres, 3) envoyer ------------------------------
# Deux essais : si quelqu'un envoie pile entre notre récupération et notre envoi, il suffit de recommencer.
for ($essai = 1; $essai -le 2; $essai++) {
    Info "Récupération de la dernière version sur GitHub..."
    git fetch -q origin
    if ($LASTEXITCODE -ne 0) {
        Erreur "Impossible de joindre GitHub (connexion internet ? invitation acceptée ?)."
        Fin 1
    }

    git rev-parse --verify -q "origin/$branche" *> $null
    if ($LASTEXITCODE -eq 0) {
        $avant = git rev-parse HEAD
        git rebase -q "origin/$branche" *> $null
        if ($LASTEXITCODE -ne 0) {
            # Les notes se fusionnent seules (voir .gitattributes). On n'arrive donc ici que pour
            # un fichier non fusionnable modifié des deux côtés, comme une image ou un tableur.
            git rebase --abort *> $null
            $secours = "sauvegarde-$($nom -replace '[^A-Za-z0-9]', '')-$(Get-Date -Format 'yyyyMMdd-HHmm')"
            git branch $secours
            git push -q origin $secours *> $null
            if ($LASTEXITCODE -ne 0) {
                # Sans copie sur GitHub, on ne touche à rien : le travail reste ici.
                Erreur "CONFLIT, et la sauvegarde sur GitHub a échoué. Rien n'a été modifié."
                Erreur "Ta version reste dans ce dossier. Vérifie ta connexion et relance."
                Fin 1
            }
            git reset -q --hard "origin/$branche"
            Erreur "CONFLIT : un même fichier non fusionnable a été modifié des deux côtés."
            Erreur "Ton dossier contient maintenant la version de GitHub."
            Erreur "La tienne est sauvegardée sur GitHub dans la branche '$secours'."
            Fin 2
        }
        if ($avant -ne (git rev-parse HEAD)) { Ok "Modifications des autres récupérées." }
        else { Info "Rien de nouveau sur GitHub." }
    }

    git push -q -u origin $branche *> $null
    if ($LASTEXITCODE -eq 0) {
        Ok "Tout est à jour sur GitHub."
        Write-Host ""
        Write-Host "Derniers changements :" -ForegroundColor White
        git --no-pager log -5 --format="  %ad  %s" --date=format:"%d/%m %H:%M"
        Fin 0
    }
    Info "GitHub a refusé l'envoi (quelqu'un vient d'envoyer ?), nouvel essai..."
}
Erreur "Envoi impossible. As-tu accepté l'invitation GitHub reçue par email ? Relance ensuite."
Fin 1
