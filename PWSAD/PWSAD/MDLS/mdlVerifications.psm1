function Entry{
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