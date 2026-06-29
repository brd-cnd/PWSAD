#............................Import des constantes
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsModules.ps1
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsOU.ps1

#............................Import du module
Import-Module $pathAffichages -Verbose
Import-Module $pathVerifications -Verbose

#............................Déclaration de constantes
[string[]]$nomUnites = @("ETP Chasseneuil","Administration","Adh�rents","Clients entreprises","Groupes","Groupes globaux","Groupes domaine local")
[string[]]$pathUnites = @($path0,$path1,$path1,$path1,$path1,$path22,$path22)
[int]$t = $nomUnites.Length

#............................Fonctions
function DISPLAY{
    <#

    fonction DISPLAY

    DESCRIPTION
    Affichage de la description du programme actuel

    TYPE DE RETOUR
    void (affichage simple)
    
    #>
    Write-Description -NeedAdminRights $True -Description "Construction de l'arborescence primaire de l'ETP Chasseneuil"
}

function CREATION {
    foreach ($i in 0..($nomUnites.Length - 1)) {
        $nom = $nomUnites[$i]
        $path = $pathUnites[$i]
        $pathTest = "OU=$nom,$path"
        if(OU_Existence -Path $pathTest){
            Write-Host "Unite d'organisation [$nom] deja presente dans l'arborescence`n" -ForegroundColor DarkGreen
        }
        else{
            $null = Success_Fail -Text "Creation de l'unite d'organisation " -SpecificText $nom  -Action {New-ADOrganizationalUnit -Name $nom -Path $path -ProtectedFromAccidentalDeletion $true}
        }
    }
}

function main{
    DISPLAY
    CREATION
    DISPLAY_END
}

#............................Execution

main