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
	Write-Description -NeedAdminRights $true -Description "Creation des groupes d'etendue domaine local"
}

function CREATION_GROUPES{
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$CSVFile,
        [Parameter(Mandatory=$true)][string]$PathGL,
        [Parameter(Mandatory=$true)][string]$PathDL
    )
    #Import de CSV
    $listeCSV = Import-CSV -Path $verifCSV -Delimiter ";" -Encoding UTF8

    #Récupérer les noms des statuts et services associés à l'entreprise
    $tabStatuts = $listeCSV.Statut | Select-Object -Unique
    $tabServices = $listeCSV.Service | Select-Object -Unique
    $preTab = $tabStatuts + $tabServices | Select-Object -Unique

    #Créer les noms des groupes domaine local
    $tabNamesDL = Array_GroupName -Name $Name -Array $preTab -Scope "DomainLocal"

    #Création d'un dictionnaire qui prend en clé le nom et en valeur l'objet
    $tabObjGroupsGL = Get-ADGroup -Filter * -SearchBase $PathGL
    $dictGroupsGL = @{}
    foreach ($nameGL in $tabObjGroupsGL) {
        $dictGroupsGL[$nameGL.Name] = $nameGL
    }

    #Créer, pour chaque élément du tableau des noms des groupes domaine local, trois groupes domaine local selon les droits (L, LM et CT)
    $dictRights = @{
        "-L" = "Lecture"
        "-LM" = "Lecture et modification"
        "-CT" = "Controle total"
    }
    foreach($DLName in $tabNamesDL){
        $groupScope, $firmName, $statusOrService = $DLName -split "-"
        foreach($right in $dictRights.GetEnumerator()){
            $DLNameRights = "{0}{1}" -f $DLName, $right.Key
            $exists = Group_Existence -Name $DLNameRights -SearchBase $PathDL -Scope "DomainLocal"
            if($exists){
                Write-Host "Groupe domaine local attribuant le droit [$right.Value] a [$statusOrService] deja present." -ForegroundColor DarkGreen
            }
            else{
                $Description = "Groupe d'etendue domaine local pour le groupe [$statusOrService], avec un droit de $right.Value"
                $success = Success_Fail -Text "Creation du groupe " -SpecificText $DLNameRights -Action {New-ADGroup -Name $DLNameRights -Path $PathDL -GroupScope "DomainLocal" -Description $Description}
                if($success){
                    Write-Host "Ajout de groupes globaux au groupe domaine local $DLNameRights" -ForegroundColor Cyan
                    Write-Host "Taper [y] pour ajouter le groupe, [n] sinon" -ForegroundColor Cyan
                    foreach($couple in $dictGroupsGL.GetEnumerator()){
                        $add = Entry -Question $couple.Key
                        if($add -eq "y"){
                            $null = Success_Fail -Text "Ajout du groupe " -SpecificText $couple.Key -Action {Add-ADGroupMember -Identity $DLNameRights -Members $couple.Value -ErrorAction Stop}
                        }
                    }
                }
            }
        }
    }
    return
}

function CHECK{
    [string]$nomEntreprise = ""
    [string]$verifCSV = $filePathCSV
    [string]$verifLogins = ""
    [string[]]$verifOU = ""
    [string[]]$verifGroupes = ""
    [bool]$existenceFiles = $false
    [bool]$existsPathGG = $false
    [bool]$existsPathDL = $false
    Write-Host "Création des groupes domaine local associés aux droits pour : " -ForegroundColor Yellow
    Write-Host "ETP ......................... [y]" -ForegroundColor Yellow
    Write-Host "Client entreprise ........... [n]" -ForegroundColor Yellow
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

            Write-Host "`nVerification de la presence du fichier .csv contenant les informations utilisateurs..." -ForegroundColor Yellow
            $presenceCSV = Test-Path $verifCSV
            if($presenceCSV){
                Write-Host "Fichier .csv présent. Import..." -ForegroundColor Green
                CREATION_GROUPES -Name $nomEntreprise -CSVFile $verifCSV -PathGL $pathGG -PathDL $pathDL
            }
            else{
                Write-Host "Fichier .csv introuvable.`nVérifiez que le fichier est nommé selon la norme et placé dans le bon répertoire." -ForegroundColor Red
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
    if(TESTADMIN){
        CHECK
    }
    DISPLAY_END
}

#............................Exécution
main