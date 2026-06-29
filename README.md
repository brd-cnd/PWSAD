# PWSAD : scripts d'intégration d'entreprise à l'Espace de Travail Partagé (ETP)
Ces scripts ont été réalisés dans le cadre d'un atelier professionnel du CNED. Il m'a permis, en tant qu'étudiante en réseaux, de travailler les structures algorithmiques de base (boucles de vérification, conditions,...). En ce sens, il n'est pas optimisé : ce n'était pas le but, même s'il existe des fonctions natives qui permettent d'aller plus vite. Pour apprendre, je n'ai donc pas utilisé l'IA, sauf pour la fonction de normalisation des caractères et pour la vérification des droits administrateurs de l'utilisateur courant.<br>
En raison des contraintes de temps, je n'ai pas pu faire tout ce que je voulais (par exemple, je souhaitais que l'adminstrateur saisisse son mot de passe).<br>
Comme mentionné plus bas, certaines autres contraintes m'ont poussée à choisir des solutions parfois peu optimisées.<br>
N'hésitez pas à me joindre si vous constatez une erreur, via l'adresse disponible sur le portfolio Greenbeans.

## TLDR : résultats attendus de l'exécution du script
Rendez-vous sur https://brd-cnd.github.io/greenbeans/pro-evolsyswin ("Résultats de la mission 1" et "Résultats de la mission 3") pour voir comment le script est censé se dérouler.

## Présentation
### Contexte du devoir
Tierslieux86 est une entreprise qui met à disposition des entreprises des espaces de travail pour leurs employés. Ces scripts proposent d'intégrer une entreprise cliente à l'Active Directory de Tierslieux86.

### Présentation structurelle
L'ensemble du dossier doit être déplacé dans le répertoire de l'administrateur : C:\Users\Administrateur. L'arborescence est la suivante :<br>
```text
|-- CSTES _dossier contenant les constantes communes aux différents scripts
|       :-- ConstsPathsAGDLP.ps1
|       :           => paths des dossiers utilisés pour la création des comptes utilisateurs
|       :-- ConstsPathsModules.ps1
|       :           => paths redirigeant vers les modules
|       :-- ConstsPathsOU.ps1
|       :           => paths des unités d'organisation de l'arborescence Active Directory de l'entreprise Tierslieux86
|-- INFRASTRUCTURE
|       :-- AborescencePrimaire.ps1
|       :           => script de création de l'arbodescence primaire
|       :              (i.e : unités d'organisation proches de la racine - niveaux 1 à 2)
|       :-- CreationUnitesEntreprise.ps1
|       :           => script de création des unités d'organisation propres à l'entreprise cliente
|-- MODULES
|       :-- MdlAffichages.psm1
|       :           => fonctions d'affichage de messages de début et de fin du programme, fonction de vérification des
|       :              droits administrateurs pour l'utilisateur exécutant le script
|       :-- MdlCreations.psm1
|       :           => fonctions de créations d'objet (comptes utilisateurs), de formatage des données
|       :              (normalisation des caractères), d'affectation des utilisateurs aux groupes et d'implémentation
|       :              des règlesde nommage (pour les groupes domaine local ou globaux, par exemple)
|       :-- MdlVerifications
|       :           => fonctions dédiées la gestion des erreurs : vérification de l'existence de paths ou d'objets
|       :              avant que ces derniers ne soient créés, contrôle de saisie, affichage de la réussite ou de
|       :              l'échec d'une opération
|-- USERS<br>
|       :-- LOGINS
|       :           => Dossier à créer, qui contiendra les sous-dossiers des entreprises, chacun contenant un document de
|       :             connexion au format .odt nominatif, pour chaque utilisateur
|       :-- CSV_Users
|       :           => Dossier contenant les fichiers .csv des utilisateurs à créer et intégrer
|       :-- IntegrationAGDLP.ps1
|       :           => Intégration des utilisateurs à l'Active Directory
|       :-- IntegrationAGDLP2.ps1
|       :           => Automatisation de l'imbrication AGDLP.

```
_NB IntegrationAGDLP2.ps1 : Au départ, l'idée était de créer un groupe par service et par droit (on crée les groupes GG-NomEntreprise-NomService-Droit et DL-NomEntreprise-NomService-Droit). Les droits sont "L", "LM" et "CT" pour Lecture, Lecture et Modification et Contrôle Total. Ils sont paramétrés via NTFS selon la règle du droit le plus restrictif. Les droits de Partage sont donc réglés sur "Tout le monde". Ce plan a échoué car étrangement instable (plus de détails dans la documentation du projet EvolSysWin). Par manque de temps, les groupes domaines local ont été créés selon le fichier partagé (ex : DL-NomEntreprise-NomFichier-droit). Voir le screenshot de l'exécution de ce script en allant sur le projet EvolSysWin : copiez la phrase qui suit, "Le script va créer des groupes domaine local en fonction du nom de la ressource à partager.", tapez Ctrl+f, et collez. La capture se trouve en dessous de cette phrase._

## Tester ce script

### Environnement
Le système d'exploitation recommandé est Windows Server 2022, car c'est sous celui-ci que ce script a été écrit et testé.<br>
Préparatifs :<br>
- Avoir créé un domaine Active Directory nommé tierslieux86.fr ;<br>
- Modifier la police d'exécution des scripts, si cela pose problème (un tuto d'IT-Connect ici : https://www.it-connect.fr/autoriser-lexecution-de-scripts-powershell/. Dans le cadre de ce lab, j'ai fait : Set-ExecutionPolicy Unrestricted -Scope CurrentUser) ;<br>
- Importer le module PSWriteWord (documentation officielle ici : https://www.powershellgallery.com/packages/PSWriteWord/1.0.1. Personnellement, je l'ai téléchargé sur mon ordinateur puis transféré sur la VM car le réseau était lent. J'ai ensuite installé et importé le module. Le script IntegrationAGDLP.ps1 va recharger ce module.) ;<br>
- Déplacer l'ensemble du dossier dans le répertoire de l'administrateur : C:\Users\Administrateur ;<br>
- Créer dans le dossier USERS le répertoire LOGINS qui contiendra les documents de connexion.

### Exécution du script
Avant toute chose, vous avez deux choix :<br>
- Soit vous utilisez les fichiers .csv déjà présents dans le dossier PWSAD pour l'intégration des utilisateurs. Il s'agit des entreprises "ValorElec", "Esporting" et "3DPrint86". Si vous choisissez d'intégrer l'une de ces trois entreprises, saisissez l'un de ces trois noms (en respectant la casse) ;<br>
- Soit vous voulez intégrer une nouvelle entreprise. Il faut préparer en amont le fichier .csv qui doit contenir le nom, prénom, statut ("Employés" ou "Responsables") et service. Pour le nom et prénom, les lettres communes en français ("ç", tirets pour les noms composés, etc.) ne devraient pas poser de problème. Pour les services, rien n'est moins sûr : évitez les caractères accentués. De manière générale, les caractères spéciaux ne sont pas les bienvenus (*,$,£,...). Le nom de ce fichier .csv devra suivre la syntaxe suivante : nomDeVotreEntreprise-Users.csv. Il devra être placé dans USERS > CSV_Users

Puis, exécutez dans l'ordre :<br>
- ArborescencePrimaire.ps1<br>
- CreationUnitesEntreprise.ps1<br>
- IntegrationAGDLP.ps1<br>
- IntegrationAGDLP2.ps1<br>
