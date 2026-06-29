# PWSAD : scripts d'intégration d'entreprise à l'Espace de Travail Partagé (ETP)
Ces scripts ont été réalisés dans le cadre d'un atelier professionnel du CNED.

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
|       :-- USERS
|       :           => Dossier à créer, qui contiendra les sous-dossiers des entreprises, chacun contenant un document de
|       :             connexion au format .odt nominatif, pour chaque utilisateur
|       :-- CSV_Users
|       :           => Dossier contenant les fichiers .csv des utilisateurs à créer et intégrer
|       :-- IntegrationAGDLP.ps1
|       :           => Intégration des utilisateurs à l'Active Directory
|       :-- IntegrationAGDLP2.ps1
|       :           => Automatisation de l'imbrication AGDLP.

```
_NB IntegrationAGDLP2.ps1 : Au départ, l'idée était de créer un groupe par service et par droit (on crée les groupes GG-NomEntreprise-NomService-Droit et DL-NomEntreprise-NomService-Droit). Les droits sont "L", "LM" et "CT" pour Lecture, Lecture et Modification et Contrôle Total. Ils sont paramétrés via NTFS selon la règle du droit le plus restrictif. Les droits de Partage sont donc réflés sur "Tout le monde". Ce plan a échoué car étrangement instable (plus de détails dans la documentation du projet EvolSysWin). Par manque de temps, les groupes domaines local ont été créés selon le fichier partagé (ex : DL-NomEntreprise-NomFichier-droit). Voir le screenshot de l'exécution de ce script en allant sur le projet EvolSysWin : copiez "Le script va créer des groupes domaine local en fonction du nom de la ressource à partager.", tapez Ctrl+f, et collez. La capture se trouve en dessous de cette phrase._

### Résultats attendus de l'exécution du script

