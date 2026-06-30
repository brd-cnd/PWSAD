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

function GIVE_RIGHTS {
    <#

    fonction GIVE_RIGHTS

    DESCRIPTION
    Attribution des droits NTFS et partage de fichiers
    L'administrateur aura contrôle total
    ==> Normalement, il faut mettre "Tout le monde" en "Contrôle total" pour que les droits NTFS régulent ensuite
    mais des problèmes ont été rencontrés à ce niveau, et "Contrôle total" est ajouté ensuite manuellement par l'administrateur

    PARAMETRES
    $Prefix (string) : préfixe du groupe : DL-NomEntreprise-NomFichier
    $PathDL (string) : path du groupe domaine local auquel on attribue les droits
    $FileName (string) : nom du fichier à partager
    $FilePath (string) : path du fichier à partager

    VARIABLES
    $DLGroups : ensemble des groupes domaine local commençant par le préfixe
    $dicoSMB : dictionnaire faisant correspondre le suffixe des droits ("L", "LM" ou "CT") aux droits SMB
    $dicoNTFS : dictionnaire faisant correspondre le suffixe des droits aux droits NTFS
    $currentUser : nom de l'utilisateur courant (l'administrateur)
    $element : variable d'itération sur les éléments de $DLGroups
    $suffixe (string) : suffixe ("L", "LM" ou "CT") en fin du nom du groupe domaine local
    $droitPartage : récupération du droit SMB associé au suffixe du groupe
    $droitNTFS : syntaxe d'attribution des droits NTFS (elementConcerne: (OI)(CI)(M))

    TYPE DE RETOUR
    void (partage de fichiers)

    NOTES PERSONNELLES
    Syntaxe icacls
    OI : Object Inherit — les fichiers contenus hériteront du droit
    CI : Container Inherit — les sous-dossiers contenus hériteront du droit
    IO : Inherit Only — le droit s'applique uniquement par héritage, pas à l'objet lui-même
    NP : No Propagate — l'héritage s'arrête au niveau suivant (ne se propage pas plus loin)

    #>
    param(
        [Parameter(Mandatory=$True)][string]$Prefix,
        [Parameter(Mandatory=$True)][string]$PathDL,
        [Parameter(Mandatory=$True)][string]$FileName,
        [Parameter(Mandatory=$True)][string]$FilePath
    )

    $DLGroups = Get-ADGroup -Filter "Name -like '$Prefix*'" -SearchBase $pathDL

    $dicoSMB = @{
        "L" = "Read"
        "LM" = "Change"
        "CT" = "Full"
    }

    $dicoNTFS = @{
        "L" = "R"
        "LM" = "M"
        "CT" = "F"
    }

    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    New-SmbShare -Name $FileName -Path $FilePath -FullAccess $currentUser

    #Nettoyage des permissions par défaut
    icacls $FilePath /inheritance:d
    icacls $FilePath /remove *S-1-5-32-545 /T


    foreach($element in $DLgroups){
        #Récupération du suffixe ("L", "LM" ou "CT")
        $suffixe = $($element.Name).Split("-")[-1]

        #Conversion du suffixe en droit SMB (string -> string)
        $droitPartage = $dicoSMB[$suffixe]

        #Attribution du droit NTFS
        $droitNTFS = "{0}:(OI)(CI)({1})" -f $($element.Name),$dicoNTFS[$suffixe]
        Grant-SmbShareAccess -Name $FileName -AccountName $element.Name -AccessRight $droitPartage -Force
        icacls $FilePath /grant $droitNTFS /T
    }
}

function CREATE_FILE {
    <#

    fonction CREATE_FILE

    DESCRIPTION
    Création du fichier à partager

    #>
    param(
        [Parameter(Mandatory=$True)][string]$FirmName,
        [Parameter(Mandatory=$true)][string]$PathGG,
        [Parameter(Mandatory=$true)][string]$PathDL
    )

    $dicoRights = @{
        "L" = "Lecture"
        "LM" = "Lecture et modification"
        "CT" = "Controle total"
    }

    #Saisie du chemin du fichier par l'utilisateur
    Write-Host "`nChemin du fichier : " -ForegroundColor Yellow -NoNewLine
    [string]$pathFile = Read-Host

    #Teste si le fichier existe
    $file_exists = Test-Path $pathFile
    $nameFile = Split-Path $pathFile -Leaf

    #Créer le dossier s'il n'existe pas
    if(-not($file_exists)){
        $createFile = Entry -Question "Le dossier n'existe pas. Creer le dossier ? "
        if($createFile -eq "Y"){
            $file_exists = Success_Fail -Text "Creation du dossier " -SpecificText $nameFile -Action {New-Item -ItemType Directory -Path $pathFile -Force}
        }
    }
    Write-Host `n

    #Création de trois groupes domaines local ayant pour nom "DL-nomEntreprise-NomFichier-droit" avec droit \in {"L","LM","CT"}
    if($file_exists){
        foreach($key in $dicoRights.Keys){
            $groupDLName = "{0}-{1}-{2}-{3}" -f "DL",$nomCapitales,$nameFile,$key
            $existsGroup = Group_Existence -Name $groupDLName -SearchBase $pathDL -Scope "DomainLocal"
            if(-not($existsGroup)){
                $null = Success_Fail -Text "Creation du groupe domaine local" -SpecificText $groupDLName -Action {New-ADGroup -Name $groupDLName -Path $pathDL -GroupScope "DomainLocal" -Description "Droit de $dicoRights[$key] sur le fichier $nameFile"}
            }
            else{
                Write-Host "$groupDLName existe deja."
            }
        }

        #récupération des groupes domaine local fraîchement créés
        $prefix = "DL-$nomCapitales-$nameFile"
        $ensObjDLRights = Get-ADGroup -Filter "Name -like '$prefix*'" -SearchBase $pathDL

        #Récupération des groupes globaux de l'entreprise
        $ensObjGG = Get-ADGroup -SearchBase $pathGG -Filter *

        #Affichage des consignes et des groupes globaux associés à un chiffre
        Write-Host "`nAjout de groupes globaux aux groupes domaine local"-ForegroundColor DarkYellow
        Write-Host "---------------------------------------------------" -ForegroundColor DarkYellow
        Write-Host "> Taper [0] pour passer au groupe suivant.`n> Entrer un nom parmi la liste proposee ci-dessous : " -ForegroundColor Gray
        $dictGG = @{}
        [int]$i = 1
        foreach($elementGG in $ensObjGG){
            Write-Host "--- [$i]:$($elementGG.Name)" -ForegroundColor DarkYellow
            $dictGG[$i] = $elementGG
            $i += 1
        }

        #Préparations de variables pour les boucles
        [int]$nbGGTot = $i - 1
        [bool]$error = $true
        [bool]$globalError = $true

        foreach($elementDL in $ensObjDLRights){

            #Affichage sucessif d'un des trois groupes domaine local (en cyan)
            Write-Host "`nGroupe [$($elementDL.Name)]" -ForegroundColor Cyan

            [int]$nbGG = 0
            do {
                #Invitation à saisir le chiffre correspondant au groupe global à ajouter au groupe domaine local
                $input = Read-Host "Numero du groupe"

            } while (-not [int]::TryParse($input, [ref]$nbGG) -or $nbGG -lt 0 -or $nbGG -gt $nbGGTot) #Contrôle de saisie

            #Récupération du groupe global à partir du numéro saisi
            $GrGG = $dictGG[$nbGG]

            #Tant que l'utilisateur n'a pas tapé 0 (et que le numéro reste correct), on réitère la demande d'ajout de groupes
            while($nbGG -gt 0 -and $nbGG -le $nbGGTot){
                $groupeGG = $ensObjGG | Where-Object Name -eq $($GrGG.Name)
                if($null -ne $groupeGG){
                    $error = Success_Fail -Text "Ajout du groupe global" -SpecificText $($dictGG[$nbGG].Name) -Action {Add-ADGroupMember -Identity $elementDL -Members $groupeGG -ErrorAction Stop}
                    $globalError = $globalError -and $error
                }
                
                do {                                                                                          
                    #Invitation à saisir le chiffre correspondant au groupe global suivant à ajouter          
                    $input = Read-Host "Numero du groupe"                                                     
                } while (-not [int]::TryParse($input, [ref]$nbGG) -or $nbGG -lt 0 -or $nbGG -gt $nbGGTot) #Contrôle de saisie
                $GrGG = $dictGG[$nbGG] #Récupération du nouveau groupe global à partir du numéro saisi        # (correction bug : sans cette ligne, le groupe sélectionné n'était jamais mis à jour)
            }
        }
        if($globalError){
            GIVE_RIGHTS -Prefix $prefix -PathDL $pathDL -FileName $nameFile -FilePath $pathFile
        }
        else{
            Write-Host "Probleme d'imbrication de groupes. Veuillez corriger et creer le partage manuellement." -ForegroundColor Red
        }
    }
}

function ANOTHERONE{
    param(
        [Parameter(Mandatory=$true)][string]$FirmName,
        [Parameter(Mandatory=$true)][string]$PathGG,
        [Parameter(Mandatory=$true)][string]$PathDL
    )
    [string]$answer = ""
    do{
        CREATE_FILE -FirmName $FirmName -PathGG $PathGG -PathDL $PathDL
        $answer = Entry -Question "`nCreer d'autres groupes domaine local pour un fichier de cette entreprise ? "
    }while($answer -eq "y")
}

function TYPE_ENTREPRISE {
    Write-Host "Entreprise proprietaire du fichier : " -ForegroundColor Yellow
    Write-Host "[y] ................. ETP" -ForegroundColor Yellow
    Write-Host "[n] ................. Client entreprise" -ForegroundColor Yellow
    $typeAjout = Entry -Question "Choix :"
    [string]$nomEntreprise = ""
    [string]$pathGG = ""
    [string]$pathDL = ""
    [bool]$check_OU = $false
    if($typeAjout -eq "y"){
        $nomEntreprise = "ETP"
        $pathGG = $path31
        $pathDL = $path32
        $check_OU = $true
    }
    else{
        Write-Host "Nom de l'OU de l'entreprise : " -ForegroundColor Yellow -NoNewLine
        $nomEntreprise = Read-Host
        $check_OU = OU_Existence -Path "OU=$nomEntreprise,$path21"
        $pathGG = "OU=Groupes globaux,OU=$nomEntreprise,$path21"
        $pathDL = "OU=Groupes domaine local,OU=$nomEntreprise,$path21"
    }
    $nomCapitales = $nomEntreprise.ToUpper()
    if($check_OU){
        ANOTHERONE -FirmName $nomEntreprise -PathGG $PathGG -PathDL $PathDL
    }
}

function main{
    DISPLAY
    if(TESTADMIN){
        TYPE_ENTREPRISE
    }
    DISPLAY_END
}

main