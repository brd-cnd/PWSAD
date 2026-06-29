function TESTADMIN {
	<#
	fonction TESTADMIN
	
	DESCRIPTION
	Vérification des droits administrateurs.
	Récupération de l'utilisateur courant, cast en WindowsPrincipal et vérification de l'appartenance au groupe des administrateurs.

	VARIABLES
	$CURRENTUSR (bool) : contient vrai si l'utilisateur courant appartient au groupe des administrateurs, et faux sinon

	TYPE DE RETOUR
	bool

	NOTES PERSONNELLES (cette fonction a été trouvée sur un forum et vérifiée sur ChatGPT et Claude AI)

	Lire dans l'ordre :
	1. [Security.Principal.WindowsIdentity] :
			Syntaxe qui permet d'appeler la classe WindowsIdentity (les points sont comme les slashs ("/") des paths : ce sont les séparateurs d'une arborescence.
			WindowsIdentity se trouve dans Principal, lui-même dans Security). (en Linux : Security/Principal/WindowsIdentity)
	2. [Security.Principal.WindowsIdentity]::GetCurrent() :
			les double-points ("::") indiquent que GetCurrent() est une méthode statique.
			Comme indiqué sur la documentation officielle (https://learn.microsoft.com/fr-fr/dotnet/api/system.security.principal.windowsidentity?view=net-10.0),
			appeler la classe [WindowsIdentity] avec la méthode GetCurrent() permet de créer un objet qui représente l'utilisateur actuel.
	3. [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent() :
			On caste [Security.Principal.WindowsIdentity]::GetCurrent()
			Comme indiqué dans la documentation officielle (https://learn.microsoft.com/fr-fr/dotnet/api/system.security.principal.windowsprincipal?view=net-10.0),
			"la classe WindowsPrincipal est principalement utilisée pour vérifier le rôle d’un utilisateur Windows."
	4. IsInRole() :
			Méthode de WindowsPrincipal. Permet de vérifier si le principal actuel (i.e : l'utilisateur actuel) appartient à un groupe d'utilisateurs.
			Le groupe d'utilisateurs à vérifier peut être spécifié dans différents formats : String, WindowsBuiltInRole, SecurityIdentifier...
			(https://learn.microsoft.com/fr-fr/dotnet/api/system.security.principal.windowsprincipal?view=net-10.0)
	5. IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
			Comme indiqué ci-dessus, étant donné que le groupe utilisateur peut être représenté sous différents types, on caste la chaîne de caractères "Administrator"
			en un objet WindowsBuiltInRole
	6. [Security.Principal.WindowsBuiltInRole]"Adminstrator"
			WindowsBuiltInRole est une énumération : c'est une classe qui contient des valeurs fixes, qui sont les valeurs autorisées. Cela permet de restreindre la 
			saisie.
	#>
	$CURRENTUSR = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
	if (-not($CURRENTUSR)){
		Write-Host "Vous devez disposer des droits administrateurs pour lancer le script." -ForegroundColor DarkRed
		return $false
	}
	else{
		return $true
	}
}

function Write-Description{
	<#
	fonction Write-Description

	DESCRIPTION
	Affiche un message de début de programme.

	PARAMETRES
	$NeedAdminRights (bool) : prend la valeur $true si l'exécution du script nécessite les droits administrateurs, et $false sinon
	$Description (string) : titre et/ou description courte du programme

	TYPE DE RETOUR
	Void (simple affichage)
	#>

	param(
		[Parameter(Mandatory=$true)][bool]$NeedAdminRights,
		[Parameter(Mandatory=$true)]$Description
	)
	Write-Host "`n______________________________________________________________________________________________________" -ForegroundColor DarkRed
	Write-Host "`nETP TIERSLIEUX86 - SITE DE CHASSENEUIL" -ForegroundColor DarkCyan
	Write-Host "____________________________________________________________________________________________________" -ForegroundColor DarkCyan
	if ($NeedAdminRights){
		Write-Host "`nVous devez disposer des droits Administrateur pour lancer ce script" -ForegroundColor Cyan
		Write-Host "..................................................................." -ForegroundColor Cyan
	}
	Write-Host "`n$Description`n" -ForegroundColor Yellow
}

function DISPLAY_END{
	<#

	fonction DISPLAY_END

	DESCRIPTION
	Affiche un message de fin du programme

	TYPE DE RETOUR
	Void (simple affichage)

	#>
	Write-Host "`n_______________________________________FIN DU PROGRAMME_____________________________________________" -ForegroundColor DarkRed
    Write-Host "`n`n`nAppuyer sur [Entree] pour quitter le programme" -ForegroundColor DarkRed -NoNewLine
    Read-Host
    Write-Host "`n`n"
}

Export-ModuleMember -Function TESTADMIN, Write-Description, DISPLAY_END