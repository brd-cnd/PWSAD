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
    <#

    fonction DISPLAY

    DESCRIPTION
    Affichage de la description du programme actuel

    TYPE DE RETOUR
    void (affichage simple)
    
    #>
    Write-Description -NeedAdminRights $True -Description "Creation des groupes & utilisateurs d'une entreprise avec affectation aux groupes de securite"
}

function Tierslieux_CreateGroups{

    <#

    fonction Tierslieux_CreateGroups

    /!\ Note 29.06.2026 : REFAIRE LA LOGIQUE !!! PAS BON !!! Que faire si groupe DL non existant ? if... else imbriqués : à revoir

    DESCRIPTION
    Crée les groupes d'étendue globale et domaine local. Vérifie en amont si ces derniers n'existent pas déjà.
    Si un groupe global est créé, on recherche automatiquement son miroir domaine local.
    Si le groupe domaine local existe déjà, demander s'il faut intégrer le groupe global comme membre.
    Si le groupe domaine local n'existe pas, rien ne se passe.

    PARAMETRES
    $Name (string) : nom de l'entreprise
    $Array (string[]) : tableau de noms de groupes
    $Path (string) : path du groupe
    $Scope (string) : étendue du groupe

    VARIABLES
    $noProblem (bool) : prend la valeur $false dès que la création d'un groupe échoue, et $true si l'ensemble s'est bien passé
    $exists (bool) : $true si le groupe existe, $false sinon
    $element (string) : variable d'itération
    $groupScope (string) : préfixe de l'étendue du groupe ("GG", "DL" ou "UV")
    $firmName (string) : nom de l'entreprise
    $statusOrService (string) : statut ou service auquel le groupe courant fait référence
    $Description (string) : chaîne de caractères décrivant le groupe
    $success (bool) : contient $true si l'action de création de groupe a réussi, $false sinon
    $groupDLName (string) : transformation du nom du groupe global en son nom équivalent de groupe domaine local (modification du préfixe)
    $existsDL (string) : test de l'existence d'un groupe domaine local rattaché au groupe global courant
    $reponse (string) : saisie de l'utilisateur concernant la création ('y') ou non ('n') de l'ajout d'un groupe global à son groupe domaine local associé

    TYPE DE RETOUR
    bool

    #>

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
    <#

    fonction Tierslieux_Creation

    DESCRIPTION
    Création des groupes domaine local et globaux selon les statuts et les services existants dans l'entreprise, en les recensant 
    à partir du fichier .csv.

    PARAMETRES
    $Name (string) : nom de l'entreprise
    $ETP (string) : demande si l'entreprise à intégrer est l'ETP ou non
    $PathGG (string) : path de l'OU des groupes globaux
    $PathDL (string) : path de l'OU des groupes domaine local

    VARIABLES
    $presenceOUGG (string) : vérification de la présence de l'OU contenant les groupes globaux
    $presenceOUDL (string) : vérification de la présence de l'OU contenant les groupes domaine local
    $listeCSV : tableau d'objets représentant les lignes du CSV 
    $tabServices (string[]) : tableau des services existant dans l'entreprise
    $nomDLServices (string[]) : tableau des noms des groupes globaux des services
    $nomGGservices (string[]) : tableau des noms des groupes domaine local des services
    $creaDLServices (bool) : création des groupes domaine local associés aux services
    $creaGGServices (bool) : création des groupes globaux associés aux services
    $noProblemServices (bool) : ET logique entre $creaDLServices et $creaGGServices : contient $true si tout s'est bien passé, $false si la création d'un groupe s'est mal passée
    $tabStatuts (string[]) : tableau des statuts existant dans l'entreprise
    $nomDLStatuts (string[]) : tableau des noms des groupes globaux des statuts
    $nomGGStatuts (string[]) : tableau des noms des groupes domaine local des statuts
    $creaDLStatuts (bool) : création des groupes domaine local associés aux statuts
    $creaGGStatuts (bool) : création des groupes globaux associés aux statuts
    $noProblemStatuts (bool) : ET logique entre $creaDLStatuts et $creaGGStatuts : contient $true si tout s'est bien passé, $false si la création d'un groupe s'est mal passée

    #>
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
    <#

    fonction TYPE_AJOUT

    DESCRIPTION
    Création des unités d'organisation de l'entreprise à intégrer.
    Les chemins de création des unités d'organisation diffèrent selon que l'entreprise intégrée est l'ETP lui-même ou une entreprise cliente.

    VARIABLES
    $nomEntreprise (string) : nom de l'entreprise
    $verifCSV (string) : path du fichier .csv des utilisateurs
    $verifLogins (string) : path du dossier des logins
    $verifOU (string) : à supprimer ?
    $verifGroupes (string) : à supprimer ?
    $existenceFiles (bool) : renvoie $true si le dossier des logins ainsi que le fichier .csv des utilisateurs existent, $false sinon
    $existsPathGG (bool) : renvoie $true si l'unité d'organisation pour les groupes globaux spécifiée par le chemin $pathExistence existe, $false sinon
    $existsPathDL (bool) : renvoie $true si l'unité d'organisation pour les groupes domaine local spécifiée par le chemin $pathExistence existe, $false sinon
    $typeAjout (string) : saisie utilisateur. Choix entre l'intégration d'une entreprise cliente ou de l'ETP lui-même
    $pathGG (string) : path de l'unité d'organisation des groupes globaux
    $pathDL (string) : path de l'unité d'organisation des groupes domaine local
    $pathExistence (string) : path de l'unité d'organisation de l'entreprise, contenant les sous-OU des groupes et des utilisateurs
    $checkOU (bool) : renvoie $true si l'unité d'organisation pour l'unité d'organisation de l'entreprise spécifiée par le chemin $pathExistence existe, $false sinon
    $creationGroupes (bool) : renvoie $true si la création des groupes s'est déroulée sans problème, $false sinon

    #>
    [string]$nomEntreprise = ""
    [string]$verifCSV = $filePathCSV
    [string]$verifLogins = ""
    [string[]]$verifOU = ""
    [string[]]$verifGroupes = ""
    [bool]$existenceFiles = $false
    [bool]$existsPathGG = $false
    [bool]$existsPathDL = $false
    Write-Host "Structure des employes a ajouter : " -ForegroundColor Yellow
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
            if(-not($existsPathGG)){
                Write-Host "OU 'Groupes globaux' introuvable pour $nomEntreprise.`nVeuillez verifier l'existence de cette sous-unite d'organisation." -ForegroundColor Red
            }
            if(-not($existsPathDL)){
                Write-Host "OU 'Groupes domaine local' introuvable pour $nomEntreprise.`nVeuillez verifier l'existence de cette sous-unite d'organisation." -ForegroundColor Red
            }
        }
    }
    else{
        Write-Host "Unite d'organisation de l'entreprise $nomEntreprise introuvable.`nVeuillez verifier l'existence de l'OU de l'entreprise." -ForegroundColor Red
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