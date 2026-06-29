function Entry{
    <#

    fonction Entry

    DESCRIPTION
    Fonction de contrôle de saisie.
    Restreint la saisie à deux valeurs possibles : 'y' ("yes") ou 'n' ("non").

    PARAMETRES
    $Question (string) : question fermée à poser à l'utilisateur

    VARIABLES
    $valid (bool) : contient la valeur $false tant que la saisie est fausse, $true lorsqu'elle l'est
    $reponse (string) : saisie de l'utilisateur

    TYPE DE RETOUR
    bool

    #>
    param(
        [Parameter(Mandatory=$True)][string]$Question
    )
    [bool]$valid = $false
    [string]$reponse = ""
	Write-Host "$Question [y/n] : " -NoNewLine -ForegroundColor Yellow
	do{
		try{
			$reponse = Read-Host
			if(($reponse -eq "y") -or ($reponse -eq "n")){
				$valid = $true
			}
            else{
                Write-Host "Saisie incorrecte. Entrer 'y' (yes/oui) ou 'n' (no/non) : " -NoNewLine -ForegroundColor Red
            }
		}
		catch{
			Write-Host "Saisie incorrecte. Entrer 'y' (yes/oui) ou 'n' (no/non) : " -NoNewLine -ForegroundColor Red
		}
	}while(-not($valid))
    return $reponse
}

function OU_Existence {
    <#

    fonction OU_Existence

    DESCRIPTION
    Teste si une unité d'organisation est présente. Retourne $true si c'est le cas, $false sinon.

    PARAMETRES
    $Path (string) : path de l'unité d'organisation dont l'existence est à tester

    TYPE DE RETOUR
    bool

    #>
    param(
        [Parameter(Mandatory=$true)][string]$Path
    )
    try {
        Get-ADOrganizationalUnit -Identity $Path -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Group_Existence {
    <#

    fonction Group_Existence

    DESCRIPTION
    Teste si un groupe existe. Renvoie $true si cela est le cas, $false sinon.

    PARAMETRES
    $Name (string) : nom du groupe
    $SearchBase (string) : path dans lequel chercher le groupe
    $Scope (string) : étendue du groupe

    VARIABLES
    $group : récupère le groupe spécifié par le nom, le path et le scope

    TYPE DE RETOUR
    bool

    #>
    param(
	[Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Searchbase,
        [Parameter(Mandatory=$true)][ValidateSet("Global","DomainLocal","Universal")]
        [string]$Scope
    )

    try {
        $group = Get-ADGroup -Filter "Name -eq '$Name' -and GroupScope -eq '$Scope'" -SearchBase $SearchBase -ErrorAction Stop
        if ($group) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }
}

function Success_Fail{
    <#

    fonction Success

    DESCRIPTION
    Teste si une action a réussi ou pas, affiche un message de réussite/échec en fonction et renvoie le booléen associé :
    $true si l'action a réussi, et $false sinon.

    PARAMETRES
    $Text (string) : texte générique décrivant l'action qui est testée
    $SpecificText (string) : ajoute un texte personnalisé
    $Action : opération dont la réussite est à tester

    TYPE DE RETOUR
    bool

    #>

    param(
        [Parameter(Mandatory=$True)][string]$Text,
        [Parameter(Mandatory=$False)][string]$SpecificText,
        [Parameter(Mandatory=$True)]$Action
    )
    Write-Host "$Text " -NoNewLine -ForegroundColor Gray
    Write-Host $SpecificText
    
    try{
        & $Action
        Write-Host "Statut : ......................... " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Reussite`n" -ForegroundColor Green
        return $True
    }
    catch{
        Write-Host "Statut : ......................... " -NoNewline -ForegroundColor DarkYellow
        Write-Host "Echec`n" -ForegroundColor Red
        return $False
    }
}

function Verify_FilesCSV{
    <#

    fonction Verify_FilesCSV

    DESCRIPTION
    Vérifie la présence du dossier LOGINS et du fichier .csv des utilisateurs. Est appelé avant d'initier l'intégration des utilisateurs.

    PARAMETRES
    $Name (string) : nom de l'entreprise

    VARIABLES
    $nomCSV (string) : nom du fichier .csv
    $nomLogins (string) : nom du dossier contenant les futurs documents de connexion .docx nominatifs
    $CSV (string) : nom du path de $nomCSV
    $Logins (string) : nom du path de $nomLogins
    $resultat (bool) : renvoie $true si la création du dossier LOGINS a réussi, $false sinon
    $presenceCSV (bool) : $true si le CSV est présent là où il faut, $false sinon
    $presenceLogins (bool) : $true si le dossier des logins de l'entreprise est présent, $false sinon

    TYPE DE RETOUR
    bool

    #>
    param(
        [Parameter(Mandatory=$true)][string]$Name
    )
    [string]$nomCSV = "${Name}-Users.csv"
    [string]$nomLogins = "${Name}-logins"
    [string]$CSV = Join-Path $filePathCSV $nomCSV
    [string]$Logins = Join-Path $filePathLogins $nomLogins
    [bool]$local:resultat = $false

    #Vérification de la présence du fichier .csv
    Write-Host "`nVerification de la presence du fichier .csv contenant les informations utilisateurs..." -ForegroundColor Yellow
    $presenceCSV = Test-Path $CSV
    if($presenceCSV){
        Write-Host "Fichier .csv présent." -ForegroundColor Green
    }
    else{
        Write-Host "Fichier .csv introuvable.`nVérifiez que le fichier est nommé selon la norme et placé dans le bon répertoire." -ForegroundColor Red
        return $false
    }

    #Vérification de la présence du dossier des logins de l'entreprise
    Write-Host "`nVerification de la presence du dossier de l'entreprise $Name..." -ForegroundColor Yellow
    $presenceLogins = Test-Path $Logins
    if($presenceLogins){
        Write-Host "Dossier present" -ForegroundColor Green
        return $true
    }
    else{
        Write-Host "Le dossier contenant les identifiants de connexion des membres de l'entreprise est manquant." -ForegroundColor Gray
        $resultat = Success_Fail -Text "Creation du dossier " -SpecificText $nomLogins {New-Item -Path $filePathLogins -Name "${Name}-logins" -ItemType Directory -Force}
        return $resultat
    }
}

Export-ModuleMember Entry, OU_Existence, Group_Existence, Success_Fail, Verify_FilesCSV