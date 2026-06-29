# PWSAD : scripts d'intégration d'entreprise à l'Espace de Travail Partagé (ETP)
Ces scripts ont été réalisés dans le cadre d'un atelier professionnel du CNED.

## Présentation
### Contexte du devoir
Tierslieux86 est une entreprise qui met à disposition des entreprises des espaces de travail pour leurs employés. Ces scripts proposent d'intégrer une entreprise cliente à l'Active Directory de Tierslieux86.

### Présentation structurelle
L'ensemble du dossier doit être déplacé dans le répertoire de l'administrateur : C:\Users\Administrateur. L'arborescence est la suivante :

|-- CSTES _dossier contenant les constantes communes aux différents scripts_<br>
|&nbsp;&nbsp;|-- ConstsPathsAGDLP.ps1 _paths des dossiers utilisés pour la création des comptes utilisateurs_

|     |-- ConstsPathsModules.ps1 _paths redirigeant vers les modules_

|     |-- ConstsPathsOU.ps1 _paths des unités d'organisation de l'arborescence Active Directory de l'entreprise Tierslieux86_

|-- INFRASTRUCTURE

|     |-- AborescencePrimaire.ps1 _script de création de l'arbodescence primaire (i.e : unités d'organisation proches de la racine - niveaux 1 à 2)_

|     |-- CreationUnitesEntreprise.ps1 _script de création des unités d'organisation propres à l'entreprise cliente_

|-- MODULES

|     |-- MdlAffichages.psm1 _fonctions d'affichage de messages de début et de fin du programme, fonction de vérification des droits administrateurs pour l'utilisateur exécutant le script_

|-- USERS



### Résultats attendus de l'exécution du script

