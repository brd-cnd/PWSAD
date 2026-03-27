function TESTADMIN {
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
	Write-Host "`n_______________________________________FIN DU PROGRAMME_____________________________________________" -ForegroundColor DarkRed
    Write-Host "`n`n`nAppuyer sur [Entree] pour quitter le programme" -ForegroundColor DarkRed -NoNewLine
    Read-Host
    Write-Host "`n`n"
}

Export-ModuleMember -Function TESTADMIN, Write-Description, display_end