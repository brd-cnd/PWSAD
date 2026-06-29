. C:\Users\Administrateur\PWSAD\CSTES\constsPathsOU.ps1
. C:\Users\Administrateur\PWSAD\CSTES\constsPathsAGDLP.ps1

function Array_GroupName{
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
    param(
        [Parameter(Mandatory=$true)][string]$Text
    )

    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder

    foreach ($char in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }
    return $builder.ToString()
}

function NormalizeWord{
    param(
        [Parameter(Mandatory=$true)][string]$Word
    )
    $Word = DeleteSpaces -Word $Word
    $Word = RemoveDiacritics -Text $Word
    return $Word
}

function RandomNumber{
    [string]$script:NUMBER = ""
    [string]$local:CHIFFRE = "0123456789"
    $NUMBER = $CHIFFRE[(Get-Random -minimum 0 -Maximum 9)]+$CHIFFRE[(Get-Random -minimum 0 -Maximum 9)]
    return $NUMBER
}

function Create_Password{
    [string]$script:PASS = ""
    [string]$local:MAJU = "AZERTYUIOPQSDFGHJKLMWXCVBN"
    [string]$local:MINU = "azertyuiopqsdfghjklmwxcvbn"
    [string]$local:NOMBRE = "0123456789"
    [string]$local:SPECIAL = "*$!-()"
    $PASS = $MINU[(Get-Random -Minimum 0 -Maximum 25)]+$SPECIAL[(Get-Random -Minimum 0 -Maximum 5)]+$MAJU[(Get-Random -Minimum 0 -Maximum 25)]+$MINU[(Get-Random -Minimum 0 -Maximum 25)]+$NOMBRE[(Get-Random -Minimum 0 -Maximum 9)]+$NOMBRE[(Get-Random -Minimum 0 -Maximum 9)]+$MAJU[(Get-Random -Minimum 0 -Maximum 25)]+$SPECIAL[(Get-Random -Minimum 0 -Maximum 5)]+$MINU[(Get-Random -Minimum 0 -Maximum 25)]+$MAJU[(Get-Random -Minimum 0 -Maximum 25)]+$MINU[(Get-Random -Minimum 0 -Maximum 25)]+$NOMBRE[(Get-Random -Minimum 0 -Maximum 9)]
    return $PASS
}

function Tierslieux_AddUserToGroup{
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
    }
}

Export-ModuleMember -Function Array_GroupName, Tierslieux_AddUserToGroup, Tierslieux_AddUsersGenerateDoc