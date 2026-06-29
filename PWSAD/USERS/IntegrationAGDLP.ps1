#............................Import des constantes
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsModules.ps1
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsOU.ps1
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsAGDLP.ps1

#............................Import du module
Import-Module $pathAffichages -Verbose
Import-Module $pathVerifications -Verbose
Import-Module $pathCreations -Verbose

#............................Fonctions
function DISPLAY{
    Write-Description -NeedAdminRights $True -Description "Creation des groupes & utilisateurs d'une entreprise avec affectation aux groupes de securite"
}

function Tierslieux_CreateGroups{
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string[]]$Array,
        [Parameter(Mandatory=$true)][string]$Path,
        [ValidateSet("Global","DomainLocal","Universal")]
        [Parameter(Mandatory=$true)][string]$Scope
    )
    $noProblem = $false
    $exists = $false
    foreach($element in $Array){
        $exists = Group_Existence -Name $element -SearchBase $Path -Scope $Scope
        $groupScope, $firmName, $statusOrService = $element -split "-"
        if(-not($exists)){
            Write-Host "Le groupe $element n'existe pas dans $Path" -ForegroundColor DarkYellow
            $Description = "Groupe d'etendue [$Scope] regroupant le personnel [$statusOrService] de l'entreprise $Name"
            $success = Success_Fail -Text "Creation du groupe " -SpecificText $element -Action {New-ADGroup -Name $element -Path $Path -GroupScope $Scope -Description $Description}
            if($success){
                $noProblem = $true
                #Chercher groupe equivalent domaine local et demander s'il faut le faire membre de ce groupe
                if($Scope -eq "Global"){
                    $groupDLName = "{0}-{1}-{2}" -f "DL",$firmName,$statusOrService
                    $existsDL = Group_Existence -Name $groupDLName -SearchBase $path32 -Scope "DomainLocal"
                    if($existsDL){
                        Write-Host "Un groupe equivalent d'etendue domaine local existe : $groupDLName" -ForegroundColor Cyan
                        $reponse = Entry -Question "Ajouter le groupe global a ce groupe domaine local ?"
                        if($reponse -eq "y"){
                            $null = Success_Fail -Text "Ajout au groupe global" -Action {Add-ADGroupMember -Identity $groupDLName -Members $element -ErrorAction Stop}
                        }
                    }
                }
            }
            else{
                $noProblem = $false
            }
        }
        else{
            Write-Host "Groupe $element present dans $Path" -ForegroundColor DarkGreen 
            $noProblem = $true
        }
    }
    return $noProblem
}

function Tierslieux_Creation{
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [ValidateSet("y","n")]
        [Parameter(Mandatory=$true)][string]$ETP,
        [Parameter(Mandatory=$true)][string]$PathGG,
        [Parameter(Mandatory=$true)][string]$PathDL
    )
    
    #Verification de la presence des OU des groupes globaux et domaine local
    $presenceOUGG = OU_Existence -Path $PathGG
    $presenceOUDL = OU_Existence -Path $PathDL
    if(-not($presenceOUGG)){
        Write-Host "L'OU des groupes globaux de la structure n'est pas creee. Veuillez la creer au bon endroit avant de poursuivre." -ForegroundColor Red    
        return $false
    }
    if(-not($presenceOUDL)){
        Write-Host "L'OU des groupes domaine local n'est pas creee. Veuillez la creer au bon endroit avant de poursuivre." -ForegroundColor Red
        return $false
    }

    #Import du module .csv
    $listeCSV = Import-CSV -Path $verifCSV -Delimiter ";" -Encoding UTF8

    #...................................................................................................Services
    #Creation des noms de groupe globaux, domaine local et verification par les noms de leur presence
    if($listeCSV[0].PSObject.Properties.Name -contains "Service"){
        $tabServices = $listeCSV.Service | Select-Object -Unique

        #Creation des noms de groupe globaux, domaine local
        $nomDLServices = Array_GroupName -Name $Name -Array $tabServices -Scope "DomainLocal"
        $nomGGServices = Array_GroupName -Name $Name -Array $tabServices -Scope "Global"
        
        #Verification de la presence des groupes selon leur nom et creation si absents
        Write-Host "`n..........Creation des groupes pour la categorie des services"
        $creaDLServices = Tierslieux_CreateGroups -Name $Name -Array $nomDLServices -Path $PathDL -Scope "DomainLocal"
        $creaGGServices = Tierslieux_CreateGroups -Name $Name -Array $nomGGServices -Path $PathGG -Scope "Global"
        
        #Stockage du bon (true) ou mauvais (false) deroule des verifications et creation
        $noProblemServices = $creaGGServices -and $creaDLServices
    }
    else{
        $noProblemServices = $true
    }
    
    #...................................................................................................Statuts
    if($listeCSV[0].PSObject.Properties.Name -contains "Statut"){
        $tabStatuts = $listeCSV.Statut | Select-Object -Unique

        #Creation des noms de groupe globaux, domaine local et verification par les noms de leur presence
        $nomDLStatuts = Array_GroupName -Name $Name -Array $tabStatuts -Scope "DomainLocal"
        $nomGGStatuts = Array_GroupName -Name $Name -Array $tabStatuts -Scope "Global"

        #Verification de la presence des groupes selon leur nom et creation si absents
        $creaDLStatuts = Tierslieux_CreateGroups -Name $Name -Array $nomDLStatuts -Path $PathDL -Scope "DomainLocal"
        $creaGGStatuts = Tierslieux_CreateGroups -Name $Name -Array $nomGGStatuts -Path $PathGG -Scope "Global"

        #Stockage du bon (true) ou mauvais (false) deroule des verifications et creation
        $noProblemStatuts = $creaGGStatuts -and $creaDLStatuts
    }
    else{
        Write-Host "La colonne [Statut] n'est pas indiquee dans le fichier .csv. Cela est necessaire pour l'attribution de droits.`nVeuillez specifier le statut (employe/responsable) de chaque utilisateur avant de poursuivre." -ForegroundColor Red
        return $false
    }
    return $noProblemServices -and $noProblemStatuts
}

function TYPE_AJOUT{
    [string]$nomEntreprise = ""
    [string]$verifCSV = $filePathCSV
    [string]$verifLogins = ""
    [string[]]$verifOU = ""
    [string[]]$verifGroupes = ""
    [bool]$existenceFiles = $false
    [bool]$existsPathGG = $false
    [bool]$existsPathDL = $false
    Write-Host "Structure des employes a  ajouter : " -ForegroundColor Yellow
    Write-Host "[y] ................. ETP" -ForegroundColor Yellow
    Write-Host "[n] ................. Client entreprise" -ForegroundColor Yellow
    $typeAjout = Entry -Question "Choix :"

    #Creation des paths
    if($typeAjout -eq "n"){
        Write-Host "`nNom de l'OU de l'entreprise : " -NoNewLine -ForegroundColor Yellow
        $nomEntreprise = Read-Host
        $pathGG = "OU=Groupes globaux,OU=$nomEntreprise,$path21"
        $pathDL = "OU=Groupes domaine local,OU=$nomEntreprise,$path21"
        $pathExistence = "OU=$nomEntreprise,$path21"
    }
    else{
        $nomEntreprise = "ETP"
        $pathGG = $path31
        $pathDL = $path32
        $pathExistence = $path1
    }
    Write-Host `n
    $checkOU = OU_Existence -Path $pathExistence
    if($checkOU){
        $existsPathGG = OU_Existence -Path $pathGG
        $existsPathDL = OU_Existence -Path $pathDL
        if($existsPathGG -and $existsPathDL){
            $verifCSV += "\${nomEntreprise}-Users.csv"

            #Verification de la presence des fichiers .csv et du dossier logins
            $existenceFiles = Verify_FilesCSV -Name $nomEntreprise
            if($existenceFiles){
                $creationGroupes = Tierslieux_Creation -Name $nomEntreprise -ETP $typeAjout -PathGG $pathGG -PathDL $pathDL
                if($creationGroupes){
                    #Import du module Word
                    Import-Module PSWriteWord -Verbose
                    Tierslieux_AddUsersGenerateDoc -FirmName $nomEntreprise -PathGroup $pathGG
                }
            }
        }
        else{
            Write-Host "Unite(s) d'organisation(s) introuvable(s).`nVeuillez verifier l'existence de l'OU de l'entreprise ainsi que de ses sous-unites." -ForegroundColor Red
        }
    }
    else{
        Write-Host "Unite(s) d'organisation(s) introuvable(s).`nVeuillez verifier l'existence de l'OU de l'entreprise ainsi que de ses sous-unites." -ForegroundColor Red
    }
}

function main{
    DISPLAY
    if (TESTADMIN){
        TYPE_AJOUT
    }
    DISPLAY_END
}

main