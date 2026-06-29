#............................Import des constantes
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsModules.ps1
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsOU.ps1

#............................Import du module
Import-Module $pathAffichages -Verbose
Import-Module $pathVerifications -Verbose

#............................Declaration de variables
[array]$sousOU = @("Groupes globaux","Utilisateurs","Ordinateurs")
[string]$nomEntreprise = ""

#............................Fonctions
function DISPLAY{
	Write-Description -NeedAdminRights $True -Description "Integration des OU d'entreprise(s) cliente(s) a l'arborescence"
}

function RESTART{
	[string]$addFirm
	do{
		ADDFIRM
		$addFirm = Entry -Question "Ajouter une entreprise ?"
	}while($addFirm -eq "y")
}

function ADDFIRM{
	Write-Host "`n__________AJOUT OU ENTREPRISE__________" -ForegroundColor DarkYellow
	Write-Host "Nom de l'entreprise : " -NoNewLine -ForegroundColor Yellow
	$nomEntreprise = Read-Host
	[bool]$existenceEntreprise = $False
    $pathEntreprise = "OU=$nomEntreprise,$path21"
	if((OU_Existence -Path $pathEntreprise)){
		Write-Host "Unite d'organisation deja cree pour l'entreprise [$nomEntreprise]`n" -ForegroundColor DarkGreen
		$existenceEntreprise = $true
    }
	else{
		$existenceEntreprise = Success_Fail -Text "Creation de l'unite d'organisation " -SpecificText $nomEntreprise -Action {New-ADOrganizationalUnit -Name $nomEntreprise -Path $path21 -ProtectedFromAccidentalDeletion $true}
	}
	if($existenceEntreprise){
		foreach($ou in $sousOU){
            $pathSousOU = "OU=$ou,$pathEntreprise"
			if(OU_Existence -Path $pathSousOU){
				Write-Host "Unite d'organisation [$ou] deja presente pour $nomEntreprise `n" -ForegroundColor DarkGreen
			}
			else{
				$null = Success_Fail -Text "Creation de l'unite d'organisation " -SpecificText $ou -Action {New-ADOrganizationalUnit -Name $ou -Path $pathEntreprise -ProtectedFromAccidentalDeletion $true}
			}
		}
	}
}

function main{
	DISPLAY
	if(TESTADMIN){
		RESTART
	}
	DISPLAY_END
}

#............................Execution
main