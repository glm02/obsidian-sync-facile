# Met un coffre Obsidian sur GitHub, ou récupère celui de quelqu'un d'autre.
# Lancé par INSTALLER.bat. Les paramètres servent aux tests automatiques.
param(
    [ValidateSet('', 'creer', 'rejoindre')][string]$Mode = '',
    [string]$Dossier = '',
    [string]$Distant = '',
    [string]$NomDepot = '',
    [string]$Prenom = '',
    [string]$Inviter = '',
    [switch]$NonInteractif
)

$ErrorActionPreference = 'Continue'
# PowerShell 5.1 lit la sortie de git dans un autre encodage que l'UTF-8 : sans ça, les accents sont cassés.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$Modele = Join-Path $PSScriptRoot 'modele'
$LimiteGitHubMo = 95   # GitHub refuse les fichiers de plus de 100 Mo

function Ok($msg)     { Write-Host "  OK  $msg" -ForegroundColor Green }
function Info($msg)   { Write-Host "  ..  $msg" -ForegroundColor Cyan }
function Erreur($msg) { Write-Host "  !!  $msg" -ForegroundColor Red }
function Fin($code) {
    Write-Host ""
    if (-not $NonInteractif) { Read-Host "Appuie sur Entrée pour fermer" | Out-Null }
    exit $code
}
function Demander($question, $defaut = '') {
    if ($NonInteractif) { return $defaut }
    $suffixe = if ($defaut) { " [$defaut]" } else { '' }
    $rep = Read-Host "  $question$suffixe"
    if (-not $rep) { return $defaut }
    # Glisser un dossier dans la fenêtre ajoute des guillemets autour du chemin
    return $rep.Trim().Trim('"')
}
function Confirmer($question) {
    if ($NonInteractif) { return $false }
    return (Read-Host "  $question (o/N)") -match '^[oOyY]'
}
function RechargerPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function OutilPresent($commande) { return [bool](Get-Command $commande -ErrorAction SilentlyContinue) }

function InstallerOutil($commande, $idWinget, $nom, $lien) {
    if (OutilPresent $commande) { return $true }
    Info "$nom n'est pas installé."
    if ((OutilPresent 'winget') -and (Confirmer "L'installer maintenant ?")) {
        winget install --id $idWinget -e --source winget --accept-source-agreements --accept-package-agreements
        RechargerPath
        if (OutilPresent $commande) { Ok "$nom est installé."; return $true }
    }
    Erreur "$nom est nécessaire : installe-le depuis $lien, puis relance."
    return $false
}

# Un service de synchronisation modifie .git pendant que git travaille, et peut casser le dépôt.
function DossierSousCloud($chemin) {
    if ($chemin -match '(?i)(OneDrive|Google ?Drive|My Drive|Mon Drive|Dropbox|iCloud)') { return $true }
    return (Test-Path -LiteralPath (Join-Path $chemin '.tmp.driveupload')) -or (Test-Path -LiteralPath (Join-Path $chemin '.tmp.drivedownload'))
}
function RefuserCloud($chemin) {
    if (DossierSousCloud $chemin) {
        Erreur "Ce dossier semble synchronisé par OneDrive, Google Drive, Dropbox ou iCloud."
        Erreur "Avec git en plus, le dépôt peut être abîmé. Déplace-le ou retire-le de ce service, puis relance."
        Fin 1
    }
}

function EcrireUtf8($chemin, $texte) {
    [IO.File]::WriteAllText($chemin, $texte, (New-Object System.Text.UTF8Encoding($false)))
}
# Ajoute seulement les lignes manquantes : les règles déjà présentes dans le coffre restent intactes.
function FusionnerLignes($source, $cible) {
    $nouvelles = [IO.File]::ReadAllLines($source)
    if (-not (Test-Path -LiteralPath $cible)) { Copy-Item -LiteralPath $source -Destination $cible; return }
    $existantes = [IO.File]::ReadAllLines($cible)
    $manquantes = @($nouvelles | Where-Object { $_ -and -not $_.StartsWith('#') -and ($existantes -notcontains $_) })
    if ($manquantes.Count -gt 0) {
        EcrireUtf8 $cible ((($existantes + '' + '# Ajouté par obsidian-sync-facile' + $manquantes) -join "`n") + "`n")
    }
}
function CopierModele($cible) {
    foreach ($f in Get-ChildItem -LiteralPath $Modele -Force -File) {
        $dest = Join-Path $cible $f.Name
        if ($f.Name -in '.gitignore', '.gitattributes') { FusionnerLignes $f.FullName $dest }
        elseif ($f.Extension -eq '.md' -and (Test-Path -LiteralPath $dest)) { continue }
        else { Copy-Item -LiteralPath $f.FullName -Destination $dest -Force }
    }
}
function PosterIdentite {
    git config core.quotepath false
    if (git config user.name) { return }
    $n = if ($Prenom) { $Prenom } else { Demander "Ton prénom (il apparaît dans l'historique)" 'Moi' }
    git config user.name "$n"
    git config user.email "$($n.ToLower() -replace '[^a-z0-9]', '')@users.noreply.github.com"
}
function FichiersTropGros {
    return @(git diff --cached --name-only --diff-filter=AM | Where-Object {
        (Test-Path -LiteralPath $_) -and ((Get-Item -LiteralPath $_).Length -gt ($LimiteGitHubMo * 1MB))
    })
}

function CreerAvecGh {
    if (-not (InstallerOutil 'gh' 'GitHub.cli' 'GitHub CLI' 'https://cli.github.com')) { return $false }
    gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        Info "Connexion à GitHub : ton navigateur va s'ouvrir."
        gh auth login --web --git-protocol https --hostname github.com
        if ($LASTEXITCODE -ne 0) { Erreur "Connexion à GitHub échouée."; return $false }
    }
    gh auth setup-git *> $null
    # Toujours privé : un coffre contient souvent des notes personnelles.
    $sortie = gh repo create $script:NomFinal --private --source . --remote origin --push 2>&1
    if ($LASTEXITCODE -ne 0) { Erreur "Création du dépôt impossible : $sortie"; return $false }
    return $true
}

function Creer {
    $d = if ($Dossier) { $Dossier } else { Demander "Glisse ici le dossier de ton coffre Obsidian, puis appuie sur Entrée" }
    if (-not $d -or -not (Test-Path -LiteralPath $d -PathType Container)) { Erreur "Dossier introuvable : $d"; Fin 1 }
    $d = (Resolve-Path -LiteralPath $d).Path
    RefuserCloud $d
    Set-Location -LiteralPath $d

    if (Test-Path -LiteralPath '.git') {
        git remote get-url origin *> $null
        if ($LASTEXITCODE -eq 0) { Erreur "Ce dossier est déjà relié à un dépôt. Rien n'a été modifié."; Fin 1 }
    } else {
        git init -q -b main
    }
    PosterIdentite
    CopierModele $d

    git add -A 2> $null
    git update-index --chmod=+x sync.command 2> $null
    $gros = FichiersTropGros
    if ($gros.Count -gt 0) {
        git reset -q
        Erreur "GitHub refuse les fichiers de plus de 100 Mo. Retire ce fichier du coffre : $($gros[0])"
        Fin 1
    }
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { git commit -q -m "Premier envoi du coffre" }
    Ok "Coffre prêt."

    if ($Distant) {
        git remote add origin "$Distant"
        git push -q -u origin (git symbolic-ref --short HEAD) *> $null
        if ($LASTEXITCODE -ne 0) { Erreur "Envoi impossible vers $Distant."; Fin 1 }
    } else {
        $defaut = (Split-Path $d -Leaf) -replace '[^A-Za-z0-9._-]', '-'
        if ($defaut -notmatch '[A-Za-z0-9]') { $defaut = 'mon-coffre' }
        $script:NomFinal = if ($NomDepot) { $NomDepot } else { Demander "Nom du dépôt sur GitHub" $defaut }
        if (-not (CreerAvecGh)) {
            Write-Host ""
            Info "Autre solution : crée un dépôt vide et PRIVÉ sur https://github.com/new, puis colle son adresse."
            $url = Demander "Adresse du dépôt (https://github.com/...)"
            if (-not $url) { Erreur "Pas d'adresse : le coffre reste sur ton PC, rien n'a été envoyé."; Fin 1 }
            git remote add origin "$url"
            git push -q -u origin (git symbolic-ref --short HEAD)
            if ($LASTEXITCODE -ne 0) { Erreur "Envoi impossible : vérifie l'adresse et ta connexion."; Fin 1 }
        }
    }
    $adresse = git remote get-url origin
    Ok "Ton coffre est sur GitHub : $adresse"

    # Inviter envoie un email à l'autre personne : uniquement sur demande explicite.
    $invite = if ($Inviter) { $Inviter } else { Demander "Pseudo GitHub d'une personne à inviter (Entrée pour personne)" }
    if ($invite -and -not (OutilPresent 'gh')) {
        # Sans gh, le code de retour serait celui de la commande précédente : un faux succès.
        Erreur "GitHub CLI est absent : invite cette personne depuis Settings > Collaborators sur GitHub."
    } elseif ($invite) {
        $complet = gh repo view --json nameWithOwner -q .nameWithOwner 2> $null
        gh api -X PUT "repos/$complet/collaborators/$invite" -f permission=push *> $null
        if ($LASTEXITCODE -eq 0) { Ok "$invite est invité : il doit accepter l'invitation reçue par email." }
        else { Erreur "Invitation impossible : vérifie le pseudo, ou invite depuis Settings > Collaborators sur GitHub." }
    }
    Write-Host ""
    Write-Host "Pour la personne qui te rejoint :" -ForegroundColor White
    Write-Host "  1. Télécharger cet outil, puis lancer INSTALLER.bat et choisir « Rejoindre »."
    Write-Host "  2. Coller cette adresse : $adresse"
    Conclure $d
}

function Rejoindre {
    if (-not (InstallerOutil 'git' 'Git.Git' 'Git' 'https://git-scm.com/download/win')) { Fin 1 }
    $url = if ($Distant) { $Distant } else { Demander "Adresse du dépôt (https://github.com/...)" }
    if (-not $url) { Erreur "Il me faut l'adresse du dépôt."; Fin 1 }
    $nom = ($url.TrimEnd('/') -split '[/\\]')[-1] -replace '\.git$', ''
    $defaut = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $nom
    $d = if ($Dossier) { $Dossier } else { Demander "Où le mettre sur ton PC ?" $defaut }
    RefuserCloud $d
    if ((Test-Path -LiteralPath $d) -and (Get-ChildItem -LiteralPath $d -Force | Select-Object -First 1)) {
        Erreur "Ce dossier existe déjà et n'est pas vide. Choisis-en un autre : rien n'a été modifié."
        Fin 1
    }
    Info "Récupération du coffre. Si GitHub le demande, connecte-toi dans la fenêtre qui s'ouvre."
    git clone -q "$url" "$d"
    if ($LASTEXITCODE -ne 0) {
        Erreur "Récupération impossible. As-tu accepté l'invitation reçue par email ? L'adresse est-elle exacte ?"
        Fin 1
    }
    Set-Location -LiteralPath $d
    PosterIdentite
    # Un dépôt créé sans cet outil n'a pas les scripts : on les ajoute, sans toucher au reste.
    if (-not (Test-Path -LiteralPath 'SYNC.bat')) { CopierModele (Get-Location).Path; Info "Scripts de synchronisation ajoutés." }
    Ok "Coffre récupéré dans : $d"
    Conclure $d
}

function Conclure($d) {
    Write-Host ""
    Write-Host "C'est prêt. Il reste :" -ForegroundColor White
    Write-Host "  1. Dans Obsidian : « Ouvrir un dossier en tant que coffre », puis choisir :"
    Write-Host "     $d"
    Write-Host "  2. Au quotidien : double-clic sur SYNC.bat dans ce dossier, en arrivant et en partant."
    Fin 0
}

# --- Départ --------------------------------------------------------------------
Write-Host ""
Write-Host "=== Obsidian + GitHub, version facile ===" -ForegroundColor White
Write-Host ""
if (-not (InstallerOutil 'git' 'Git.Git' 'Git' 'https://git-scm.com/download/win')) { Fin 1 }

$choix = $Mode
if (-not $choix) {
    Write-Host "  1. Mettre mon coffre sur GitHub (je commence)"
    Write-Host "  2. Rejoindre le coffre de quelqu'un (ou le récupérer sur un autre PC)"
    Write-Host ""
    $rep = Demander "Ton choix : 1 ou 2"
    if ($rep -eq '1') { $choix = 'creer' } elseif ($rep -eq '2') { $choix = 'rejoindre' }
    else { Erreur "Réponds 1 ou 2. Relance INSTALLER.bat."; Fin 1 }
}
if ($choix -eq 'creer') { Creer } else { Rejoindre }
