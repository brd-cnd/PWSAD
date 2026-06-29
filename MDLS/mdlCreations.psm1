. C:\Users\Administrateur\PWSAD\CSTES\constsPathsOU.ps1
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsAGDLP.ps1

function Array_GroupName{
    <#

    fonction Array_GroupName

    DESCRIPTION
    Crée un tableau de noms de groupes Active Directory selon la syntaxe suivante :
    [Portée du Groupe]-[Nom de l'entreprise]-[Élement numéro x de la catégorie N de l'entreprise]

    Les catégories en question se retrouvent dans les fichiers .csv. Il s'agit soit du statut (employé ou responsable),
    soit du service (qualité, commerce, IT, recherche, par exemple.)

    Schématiquement, imaginons une telle organisation dans une entreprise : 

    Nom de l'entreprise : greenbeans
    
    | STATUTS | Employés | Responsables |
    On regroupe cela dans un tableau : $tabStatuts = ["Employes","Responsables"]

    | SERVICES | Production | Qualité | IT | RH | Commerce | Direction |
    Idem : $tabServices = ["Production","Qualite","IT","RH","Commerce","Direction"]

    On peut appeler cette fonction pour générer par exemple des groupes globaux pour chaque service :
    Array_GroupName -Name Greenbeans -Array $tabServices -Scope "Global"

    La fonction retournera le tableau contenant les noms de groupes suivants :
    - GG-GREANBEANS-Production
    - GG-GREANBEANS-Qualite
    - GG-GREANBEANS-IT
    - GG-GREANBEANS-RH
    - GG-GREANBEANS-Commerce
    - GG-GREANBEANS-Direction

    Si on souhaitait avoir le tableau de noms de groupes des statuts de Greenbeans :
    Array_GroupName -Name Greenbeans -Array $tabStatuts -Scope "DomainLocal"
    - DL-GREENBEANS-Employes
    - DL-GREENBEANS-Responsables
    
    PARAMETRES
    $Name (string) : nom de l'entreprise
    $Array (string[]) : tableau de catégorie (statut, service...)
    $Scope (string) : portée du groupe. Accepte uniquement les valeurs "Global", "DomainLocal" et "Universal"

    VARIABLES
    $uppercaseName (string) : contient le nom de l'entreprise en majuscules
    $prefix (string) : préfixe associé à chaque portée de groupe. Prend par exemple la valeur "GG" pour un groupe global, ou "UV" pour un groupe universel
    ($exists et $description à vérifier : possibilité de les supprimer ?)

    #>
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string[]]$Array,
        [ValidateSet("Global","DomainLocal","Universal")]
        [Parameter(Mandatory=$true)][string]$Scope
    )
    [string]$uppercaseName = $Name.ToUpper()
    [string]$prefix = ""
    [bool]$exists = $false
    [string]$description = ""

    switch($Scope){
        "Global"{$prefix = "GG"}
        "DomainLocal"{$prefix = "DL"}
        "Universal"{$prefix = "UV"}
    }
    $newArray = foreach($item in $Array){
        "{0}-{1}-{2}" -f $prefix,$uppercaseName,$item
    }
    return $newArray
}

function Array_DLGroupName{
    <#

    fonction Array_DLGroupName

    DESCRIPTION
    Ajoute un suffixe correspondant à la permission que l'on va attribuer au groupe domaine local.
    Par exemple, Array_DLGroupName -Name Sharedfolder renvoie le tableau contenant les trois noms suivants :
    - DL-SHAREFOLDER-L
    - DL-SHAREFOLDER-LM
    - DL-SHAREFOLDER-CT

    PARAMETRES
    $Name (string) : élément numéro deux de la chaîne de caractères

    VARIABLES
    $RightsArray (string) : tableau des préfixes contenant les valeurs "L", "LM" et "CT", respectivement pour "Lecture", "Lecture et modification" et "Contrôle total"
    $partOfName (string) : chaîne de caractères intermédiaire juxtaposant le préfixe "DL" à la chaîne de caractères entrée en paramètres
    $newArray (string[]) : valeur de retour. Contient le tableau des trois noms des groupes domaine local
    $item (string) : variable d'itération

    TYPE DE RETOUR
    string[]

    #>
    param(
        [Parameter(Mandatory=$true)][string]$Name
    )
    [string[]]$RightsArray = @("L","LM","CT")
    [string]$partOfName = "DL-{0}-" -f $Name
    $newArray = foreach($item in $RightsArray){
        "{0}{1}" -f $partOfName,$item
    }
    return $newArray
}

function Tierslieux_DLGroups{
    <#

    fonction Tierslieux_DLGroups

    DESCRIPTION
    Reçoit un tableau de chaînes de caractères ainsi qu'un path, contenant respectivement le nom de groupes domaine local et l'endroit où ces 
    derniers se trouvent.
    Vérifie, pour chaque groupe domaine local s'il existe ou non.
    Si oui, un message de validation s'affiche.
    Si non, un message d'information s'affiche, et le groupe domaine local est créé (avec information de réussite ou d'échec de création)
    
    PARAMETRES
    $Array (string[]) : tableau de noms de groupes d'étendue domaine local
    $PathDL (string) : path de l'emplacement des groupes d'étendue domaine local du tableau $Array

    VARIABLES
    $DLGroupName (string) : variable d'itération
    $exists (bool) : contient vrai si le groupe domaine local spécifié existe, et faux sinon
    $Description (string) : affiche le nom du groupe domaine local qui sera créé si les conditions de création sont réunies
    $success (bool) : stockage de la valeur de vérité du déroulement de la création du groupe domaine local
                      ($true en cas de réussite, $false en cas d'échec)

    #>
    param(
        [Parameter(Mandatory=$true)][string]$Array,
        [Parameter(Mandatory=$true)][string]$PathDL
    )
    foreach($DLGroupName in $Array){
        $exists = Group_Existence -Name $DLGroupName -SearchBase $PathDL -Scope "DomainLocal"
        if(-not $exists){
            Write-Host "Le groupe $DLGroupName n'existe pas dans $PathDL" -ForegroundColor DarkYellow
            $Description = "Groupe d'etendue domaine local $DLGroupName"
            $success = Success_Fail -Text "Creation du groupe d'étendue domaine local " -SpecificText $DLGroupName -Action {New-ADGroup -Name $DLGroupName -Path $PathDL -GroupScope "DomainLocal" -Description $Description}
        }
        else{
            Write-Host "Groupe $DLGroupName present" -ForegroundColor DarkGreen 
        }
    }
}

function DeleteSpaces{
    <#

    fonction DeleteSpaces

    DESCRIPTION
    Supprime les espaces d'une chaîne de caractère. Des fonctions natives auraient pu faire l'affaire (Trim(), -replace...),
    mais autant travailler un peu les boucles ici.

    PARAMETRES
    $Word (string) : chaîne de caractère pour laquelle on supprime les espaces

    VARIABLES
    $t (int) : variable contenant la taille du mot $Word entré en paramètre. Évite de recalculer la taille à chaque tour de boucle.
    $i (int) : indice du caractère courant dans la boucle. Permet de copier caractère par caractère, selon l'indice, un mot, sauf
               si le caractère courant est un espace : $i saute alors cet indice et passe directement au caractère suivant.
    $newWord (string) : variable contenant la valeur de retour, qui est le nouveau mot sans espace

    TYPE DE RETOUR
    string


    #>
    param(
        [Parameter(Mandatory=$true)][string]$Word
    )
    [int]$t = $Word.Length
    [int]$i = 0
    [string]$newWord = ""
    if($Word.Contains(" ")){
        $i = 0
        while($i -lt $t){
            if($Word[$i] -eq " "){
                $i += 1
            }
            $newWord = $newWord+$Word[$i]
            $i += 1
        }
        $Word = $newWord
    }
    return $Word
}

#Créé à l'aide de l'intelligence artificielle
function RemoveDiacritics{
    <#

    fonction RemoveDiacritics

    DESCRIPTION
    Supprime les accents de la manière suivante en décomposant la chaîne de caractères au format Unicode
    (exemple : aïoli -> ai¨oli) et supprime les caractères accentulés (ai¨oli -> aioli)
    Agit aussi sur le c cédille et le remplace par un "c" normal.
    
    PARAMETRES
    $Text (string) : chaîne de caractère dont les accents sont à enlever

    VARIABLES
    $normalized (string) : contient la chaîne de caractère $Text normalisée au format Unicode FormD
    $builder (StringBuilder) : car les chaînes de caractère en Powershell sont immuables
    $char : caractère courant, variable d'itération de boucle
    $chars (char[]) : contient le tableau de caractères de $normalized
    $nonSpacingMarks : contient [Globalization.UnicodeCategory]::NonSpacingMark, c'est-à-dire la catégorie Unicode des signes qui se 
                       combinent avec le caractère précédent sans occuper de place à eux-seuls
    $category : contient la catégorie Unicode d'un caractère (par exemple, prend la valeur "MathSymbol" si le caractère est le symbole"+")
    $result (string) : variable de retour

    TYPE DE RETOUR
    string

    NOTES PERSONNELLES
    [Text.NormalizationForm] :
        Classe (énumération) qui définit le type de normalisation à effectuer
        Documentation officielle : https://learn.microsoft.com/fr-fr/dotnet/api/system.text.normalizationform?view=net-10.0
    ::FormD :
        Méthode statique sur [Text.Normalization].
        "Indique qu’une chaîne Unicode est normalisée à l’aide de la décomposition canonique complète.". Source :
        documentation officielle : https://learn.microsoft.com/fr-fr/dotnet/api/system.text.normalizationform?view=net-10.0
    .Normalize :
        "Retourne une nouvelle chaîne dont la valeur textuelle est la même que cette chaîne, mais dont la représentation 
        binaire se trouve dans le formulaire de normalisation Unicode spécifié." Source :
        documentation officielle https://learn.microsoft.com/fr-fr/dotnet/api/system.string.normalize?view=net-10.0
    .ToCharArray() :
        Transforme une chaîne de caractèrs en tableau de caractères ("oie" -> @('o','i','e'))

    En résumé : 
    $Text.Normalize(x) : "Normaliser la chaîne de caractères $Text" selon le format x spécifié entre parenthèses
    x = [Text.NormalizationForm]::FormD : le format choisi pour cette normalisation est l'Unicode FormD
    
    FormD : "Indique qu’une chaîne Unicode est normalisée à l’aide de la décomposition canonique complète." source :
    documentation officielle : https://learn.microsoft.com/fr-fr/dotnet/api/system.text.normalizationform?view=net-10.0

    #>
    param(
        [Parameter(Mandatory=$true)][string]$Text
    )

    #Normalisation des caractères : dissociation entre la lettre et son accent
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)

    # Instanciation de $builder en objet StringBuilder
    $builder = New-Object System.Text.StringBuilder

    #Déclaration et affectation de variables pour éviter les calculs redondants
    $chars = $normalized.ToCharArray() # Transformation de la chaîne de caractères en tableau de caractères (char)
    $nonSpacingMark = [Globalization.UnicodeCategory]::NonSpacingMark # Variable représentant la catégorie même des accents au format Unicode
    
    #Transformation de $normalized en tableau et itération sur les éléments pour filtrer les accents
    foreach ($char in $chars) {

        # Récupération de la catégorie Unicode du caractère courant
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)

        # Si la catégorie du caractère courant n'est pas de catégorie NonSpacingMark,
        # ajouter le caractère à $builder. [void] permet d'étouffer les messages
        # de sortie de la méthode .Append
        if ($category -ne $nonSpacingMark) {
            [void]$builder.Append($char)
        }
    }

    # Récupération du résultat et élmination des c cédilles
    $result = $builder.ToString() -replace 'ç', 'c' -replace 'Ç', 'C'
    return $result()
}

function NormalizeWord{
    <#

    fonction NormalizeWord

    DESCRIPTION
    Supprime les espaces et les caractères accentués d'une chaîne de caractères.

    PARAMETRES
    $Word (string) : chaîne de caractères à normaliser

    TYPE DE RETOUR
    string

    #>
    param(
        [Parameter(Mandatory=$true)][string]$Word
    )
    $Word = DeleteSpaces -Word $Word
    $Word = RemoveDiacritics -Text $Word
    return $Word
}

function RandomNumber{
    <#

    fonction RandomNumber

    DESCRIPTION
    Fonction qui retourne un nombre à deux chiffres, générés aléatoirement

    VARIABLES
    $NUMBER (string) : variable de retour.
    $CHIFFRE (string) : chaîne de caractères qui contient tous les chiffres

    TYPE DE RETOUR
    string
    #>
    [string]$script:NUMBER = ""
    [string]$local:CHIFFRE = "0123456789"

    #Pioche deux fois de suite au hasard un des chiffres de la chaîne "0123456789"
    #Je n'ai pas simplement fait : return Get-Random -Minimum 10 -Maximum 99
    #pour garder la possibilité d'avoir un nombre comme "01" ou "02" 
    $NUMBER = $CHIFFRE[(Get-Random -minimum 0 -Maximum 10)]+$CHIFFRE[(Get-Random -minimum 0 -Maximum 10)]
    return $NUMBER
}

function Create_Password{
    <#

    fonction Create_Password

    DESCRIPTION
    Création d'un mot de passe créé en faisant se succéder dans l'ordre suivant :
    - minuscule 
    - caractère spécial
    - majuscule
    - minuscule
    - chiffre
    - chiffre
    - majuscule
    - caractère spécial
    - minuscule
    - majuscule
    - minuscule
    - chiffre
    D'une longueur de douze caractères et mélangeant minuscules, majuscules et caractères spéciaux, cela permet de répondre aux exigences
    de robustesse de mots de passe.

    VARIABLES
    $PASS (string) : valeur de retour
    $MAJU (string) : contient toutes les lettres de l'alphabet, en majuscules
    $MINU (string) : contient toutes les lettres de l'alphabet, en minuscules
    $NOMBRE (string) : contient tous les chiffres de base 10
    $SPECIAL (string) : contient les caractères spéciaux que l'on sait autorisés pour les mots de passe

    TYPE DE RETOUR
    string

    #>
    [string]$script:PASS = ""
    [string]$local:MAJU = "AZERTYUIOPQSDFGHJKLMWXCVBN"
    [string]$local:MINU = "azertyuiopqsdfghjklmwxcvbn"
    [string]$local:NOMBRE = "0123456789"
    [string]$local:SPECIAL = "*$!-()"
    $PASS = $MINU[(Get-Random -Minimum 0 -Maximum 25)]+$SPECIAL[(Get-Random -Minimum 0 -Maximum 5)]+$MAJU[(Get-Random -Minimum 0 -Maximum 25)]+$MINU[(Get-Random -Minimum 0 -Maximum 25)]+$NOMBRE[(Get-Random -Minimum 0 -Maximum 9)]+$NOMBRE[(Get-Random -Minimum 0 -Maximum 9)]+$MAJU[(Get-Random -Minimum 0 -Maximum 25)]+$SPECIAL[(Get-Random -Minimum 0 -Maximum 5)]+$MINU[(Get-Random -Minimum 0 -Maximum 25)]+$MAJU[(Get-Random -Minimum 0 -Maximum 25)]+$MINU[(Get-Random -Minimum 0 -Maximum 25)]+$NOMBRE[(Get-Random -Minimum 0 -Maximum 9)]
    return $PASS
}

function Tierslieux_AddUserToGroup{
    <#

    fonction Tierslieux_AddUserToGroup

    DESCRIPTION
    Ajout de l'utilisateur aux groupes globaux des services (et éventuellement des statuts, si spécifié), auquel il appartient.

    PARAMETRES
    $SAM (string) : sAMAccountName de l'utilisateur
    $TabGroups (string[]): tableau de noms de groupes globaux auxquels appartient l'utilisateur
    $UserOU (string) : path où se trouvent les comptes utilisateurs de l'entreprise dans laquelle l'utilisateur travaille
    $PathGG (string) : path des groupes globaux de l'entreprise de l'utilisateur

    TYPE DE RETOUR
    void (simple affichage)

    #>
    param(
        [Parameter(Mandatory=$true)][string]$SAM,
        [Parameter(Mandatory=$true)][string[]]$TabGroups,
        [Parameter(Mandatory=$true)][string]$UserOU,
        [Parameter(Mandatory=$true)][string]$PathGG
    )
    $person = Get-ADUser -Filter "SamAccountName -eq '$SAM'" -SearchBase $UserOU
    foreach($item in $TabGroups){
        $GlobalGroup = Get-ADGroup -Filter "Name -eq '$item' -and GroupScope -eq 'Global'" -SearchBase $PathGG -ErrorAction SilentlyContinue
        if($GlobalGroup){
            $null = Success_Fail -Text "Ajout de l'utilisateur au groupe global " -SpecificText $item -Action {Add-ADGroupMember -Identity $GlobalGroup -Members $person -ErrorAction Stop}
        }
    }
}

function Tierslieux_AddUsersGenerateDoc{
    <#

    fonction Tierslieux_AddUsersGenerateDoc

    DESCRIPTION
    Crée les comptes utilisateurs d'une entreprise à partir du fichier .csv et du nom de l'entreprise.
    Pour chaque utilisateur, il y a :
    - génération d'un fichier .docx contenant ses informations de connexion (identifiant + login)
    - affectation aux groupes globaux du service et du statut auxquels il est rattaché

    Le mot de passe est supprimé dès que le compte a été créé.

    PARAMETRES
    $FirmName (string) : nom de l'entreprise
    $PathGroup (string) : path des groupes globaux de l'entreprise

    VARIABLES
    $pathDossier (string) : path du dossier où enregistrer les documents de connexion des utilisateurs
    $pathCSV (string) : path du fichier .csv des utilisateurs
    $pathOUUsers (string) : path de l'unité d'organisation contenant les comptes utilisateurs de l'entreprise
    $password (string) : mot de passe du compte
    $forename (string) : variable de récupération du prénom de la personne à partir du fichier .csv
    $name (string) : variable de récupération du nom de la personne à partir du fichier .csv
    $newname (string) : à supprimer ? Vérifier
    $login (string) : login de l'utilisateur
    $usersList : tableau d'objets représentant les lignes du CSV 
    $person : variable d'itération sur $usersList (qui est un tableau d'objets)
    $loginName (string) : nom normalisé de l'utilisateur
    $loginSurname (string) : prénom normalisé de l'utilisateur
    $numLogin (string) : nombre aléatoire en suffixe du login de l'utilisateur dans le cas où des utilisateurs auraient le même nom et la même initiale de prénom
    $firstLetter (string) : récupération de la première lettre du prénom
    $doublon : Objet ADUser si le login existe déjà dans l'AD, $null sinon
    $upName (string) : nom de l'utilisateur, mis en majuscules
    $addUser (bool) : stockage et affichage du succès ($true) ou de l'échec ($false) de l'opération de création de compte
    $pathFichier (string) : path du fichier .docx
    $WordDocument : document .docx de connexion pour l'utilisateur
    $IBelongTo : tableau des noms des groupes globaux auxquels appartient l'utilisateur
    $tabGroups : tableau des noms formatés (i.e : comprenant le préfixe GG et le nom de l'entreprise) auxquels appartient l'utilisateur

    TYPE DE RETOUR
    void (création de fichiers Word)

    #>
    param(
        [Parameter(Mandatory=$True)][string]$FirmName,
        [Parameter(Mandatory=$True)][string]$PathGroup
    )
    
    #Création de paths
    [string]$pathDossier = "$filePathLogins\${FirmName}-logins"
    [string]$pathCSV = "$filePathCSV\${FirmName}-Users.csv"
    [string]$pathOUUsers = ""
    if($FirmName -eq "ETP"){
        $pathOUUsers = "OU=Administration,$path1"
    }
    else{
        $pathOUUsers = "OU=Utilisateurs,OU=${FirmName},$path21"
    }

    #Création de variables
    [string]$local:password = ""
    [string]$forename = ""
    [string]$name = ""
    [string]$newname = ""
    [string]$local:numLogin = ""
    [string]$login = ""

    #Import du fichier CSV des utilisateurs
    $usersList = Import-CSV -Path $pathCSV -Delimiter ";" -Encoding UTF8

    #Creation des utilsateurs
    foreach($person in $usersList){
        $name = $person.Nom
        $forename = $person.Prenom
        
        $loginName = NormalizeWord -Word $name
        $loginForename = NormalizeWord -Word $forename

        #Tester si une personne de la même entreprise possède le même login
        do{
            $numLogin = RandomNumber
            $firstLetter = $loginForename[0]
            $login = ("{0}.{1}{2}" -f $loginName,$firstLetter,$numLogin).ToLower()
            $doublon = Get-ADUser -Filter {SamAccountName -eq $login} -SearchBase $path1 -SearchScope Subtree
        }while(-not($doublon -eq $null))
        
        #Génération du mot de passe
        $password = ""
        $password = Create_Password
        
        #Création de l'utilisateur
        $upName = $Name.ToUpper()
        Write-Host "`n----------------------------------------------------------------------" -ForegroundColor DarkCyan
        $addUser = Success_Fail -Text "Creation du compte utilisateur de " -SpecificText "$forename $name" -Action {New-ADUser -Name "$upName $Forename" -GivenName $Forename -Surname $Name -SamAccountName $login -UserPrincipalName "$login@tierslieux86.fr" -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) -Enabled $True -ChangePasswordAtLogon $True -Path $pathOUUsers}
        

        if($addUser){
            # Création du document
            $pathFichier = "$pathDossier\Bienvenue_${forename}_${name}.docx"

            Write-Host "Creation du document des informations de connexion pour l'utilisateur [$forename $name]..." -ForegroundColor DarkCyan
            $WordDocument = New-WordDocument -FilePath $pathFichier
            Add-WordText -WordDocument $WordDocument -Text "Bienvenue, $forename" -HeadingType Heading1 -Alignment Center | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "Prenez connaissance de vos informations de connexion" -HeadingType Heading2 -Alignment Center | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "Bonjour $forename," | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "L'espace de travail partagé de Chasseneuil vous offre un espace où vous pouvez travailler. Pour accéder aux ressources de votre entreprise, nous vous fournissons vos identifiants :" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "Login : $login" -Bold $true | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "Mot de passe provisoire : $password" -Bold $true | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "On vous demandera de changer votre mot de passe lors de votre première connexion. Choisissez-en un robuste ! Voici les critères qu'il devra respecter :" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "- 12 caractères minimum" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "- Mélange de majuscules et de minuscules" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "- Au moins deux chiffres" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "- Au moins deux caractères spéciaux (*!-()$)" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "- Évitez de mettre des dates d'anniversaire, de mariage, des noms de vos proches ou animaux." | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "Bon séjour parmi nous !" | Out-Null
            Add-WordText -WordDocument $WordDocument -Text "L'équipe de Tierslieux86 - Chasseneuil" | Out-Null
            Save-WordDocument $WordDocument
            $password = ""

            [string[]]$IBelongTo = @()

            #Recuperation des categories auxquelles appartient l'utilisateur
            $IBelongTo += $person.Statut
            if($usersList[0].PSObject.Properties.Name -contains "Service"){
                $IBelongTo += $person.Service
            }
            #Creation des noms de groupes
            $tabGroups = Array_GroupName -Name $FirmName -Array $IBelongTo -Scope "Global"

            #Ajout de l'utilisateur aux groupes
            Tierslieux_AddUserToGroup -SAM $login -TabGroups $tabGroups -UserOU $pathOUUsers -PathGG $PathGroup
        }
        $password = ""
    }
}

Export-ModuleMember -Function Array_GroupName, Tierslieux_AddUserToGroup, Tierslieux_AddUsersGenerateDoc