# ARCA — Gestionnaire de documents personnel

Application Android (Flutter) de gestion de documents personnels en local. L'équivalent numérique d'un classeur physique : zéro cloud, zéro compte, zéro connexion internet requise. Tout reste sur l'appareil.

---

## Fonctionnalités

### Dossiers
- Créer, renommer et supprimer des dossiers depuis l'accueil
- Créer des sous-dossiers à l'intérieur d'un dossier (profondeur illimitée)
- Chaque dossier peut avoir un nom et une description optionnelle

### Documents
- Importer des fichiers depuis le stockage de l'appareil : `PDF`, `DOCX`, `DOC`, `PNG`, `JPG`, `JPEG`
- Import multi-fichiers en un seul geste
- Renommer ou supprimer un fichier (la suppression retire aussi le fichier du disque)
- Les fichiers importés sont copiés dans le répertoire privé de l'app (pas de dépendance au fichier source)

### Scanner de documents
- Photographier une ou plusieurs pages depuis l’accueil ou n’importe quel dossier
- Aperçu des pages avec zoom, suppression, reprise d’une photo et changement d’ordre
- Recadrage manuel à quatre coins et rotation à 90°
- Génération locale d’un PDF A4 contenant toutes les pages dans l’ordre choisi
- Nommer le PDF et choisir sa destination dans toute l’arborescence
- Créer un dossier ou sous-dossier pendant le choix de destination
- Dossier de départ présélectionné lorsque le scan est lancé depuis un dossier
- Confirmation avant abandon, conservation des pages après un échec d’enregistrement
- Gestion du refus de permission caméra et de la reprise après mise en arrière-plan

Le scanner utilise des images, sans reconnaissance de texte (OCR). Le recadrage est manuel.
Les traitements d’images et la génération PDF s’exécutent hors du thread d’interface.
Les fichiers temporaires du scan sont nettoyés après l’import ; une seule copie définitive est conservée.

### Visionneuse
- **PDF** : navigation par swipe, indicateur de page
- **Images** : affichage zoomable (pinch-to-zoom)
- **DOCX/DOC** : aperçu non disponible nativement — bouton de partage pour ouvrir avec une app externe

### Partage
- Partager n'importe quel fichier en un tap via WhatsApp, email ou toute autre app présente sur l'appareil (intent Android standard)

### Export d’un dossier en ZIP
- Menu du dossier → **Exporter en ZIP**, depuis l’accueil, une carte de sous-dossier ou le menu du dossier ouvert.
- L’archive contient le dossier sélectionné, ses documents et toute son arborescence, y compris les dossiers vides.
- Les noms affichés dans ARCA sont conservés avec les extensions des fichiers. Les caractères incompatibles sont remplacés, les noms très longs raccourcis et les doublons suffixés pour éviter les écrasements à l’extraction.
- La création s’exécute en arrière-plan, puis ouvre le partage Android. Choisir une application destinataire pour partager ou conserver le ZIP ; les destinations proposées dépendent des applications installées.
- Un fichier manquant ou illisible fait échouer l’export, sans partager d’archive partielle.
- Les exports temporaires sont conservés pour les applications destinataires, puis nettoyés lors d’un nouvel export après sept jours. Le système peut également libérer le cache.
- Cet export contient les fichiers et leur classement, sans la base SQLite, les étiquettes ni les descriptions. Il ne constitue pas une sauvegarde restaurable de toute l’application.

### Étiquettes (tags)
- Créer des étiquettes personnalisées avec couleur automatique
- Attacher plusieurs étiquettes à un dossier ou un fichier
- Appui long sur une étiquette dans le panneau de gestion pour la supprimer globalement
- Les étiquettes sont visibles directement sur les cartes (dossiers et fichiers)

### Filtrage par étiquette
- Écran dédié accessible depuis l'AppBar (icône `🏷`)
- Sélection multi-étiquettes : les résultats affichent uniquement les items qui ont **toutes** les étiquettes sélectionnées (intersection)
- Résultats séparés en deux sections : Dossiers et Fichiers
- Navigation directe depuis un résultat vers le dossier ou la visionneuse

### Recherche globale
- Recherche simultanée dans les dossiers ET les fichiers
- Résultats en deux sections distinctes avec navigation directe
- Accessible depuis l'icône loupe dans l'AppBar

---

## Stack technique

| Composant | Technologie |
|---|---|
| Framework | Flutter 3.x (Dart) |
| UI | Material Design 3 |
| Base de données locale | SQLite via `sqflite` |
| Stockage fichiers | Répertoire privé de l'app (`path_provider`) |
| Import | `file_picker` |
| Partage | `share_plus` |
| Visionneuse PDF | `flutter_pdfview` |
| Capture photo | `camera` (audio désactivé) |
| Images et génération PDF | `image`, `pdf` |
| Permissions Android | `permission_handler` |

---

## Architecture

Le projet suit une organisation **feature-first** avec une couche `core` partagée.

```
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── database/
│   │   └── database_helper.dart   # Singleton SQLite, schéma, migrations
│   ├── models/
│   │   ├── folder.dart            # Modèle Folder + sérialisation
│   │   ├── document.dart          # Modèle Document + enum DocumentType
│   │   └── tag.dart               # Modèle Tag + TagBinding
│   └── services/
│       ├── folder_service.dart    # CRUD dossiers, recherche, filtre par tag
│       ├── document_service.dart  # Import, suppression, renommage, filtre par tag
│       └── tag_service.dart       # Création, liaison, déliaison, suppression
│
├── features/
│   ├── home/
│   │   ├── screens/home_screen.dart      # Liste des dossiers racine + recherche globale
│   │   └── widgets/folder_card.dart      # Carte dossier avec menu contextuel
│   ├── folder/
│   │   ├── screens/
│   │   │   ├── folder_detail_screen.dart # Contenu d'un dossier (sous-dossiers + fichiers)
│   │   │   └── subfolder_screen.dart     # Contenu d'un sous-dossier
│   │   └── widgets/document_card.dart    # Carte fichier avec menu contextuel
│   ├── document/
│   │   └── screens/document_viewer_screen.dart  # Visionneuse PDF/image + gestion tags
│   └── tags/
│       └── screens/tag_filter_screen.dart        # Filtrage multi-étiquettes
│
└── shared/
    ├── theme/app_theme.dart        # Thème MD3 clair/sombre
    └── widgets/
        ├── tag_chip.dart           # Chip coloré pour afficher un tag
        ├── tag_sheet.dart          # Bottom sheet réutilisable (forFolder / forDocument)
        └── doc_type_icon.dart      # Icône selon le type de fichier
```

### Schéma de base de données

```sql
folders       (id, name, description, parent_id→folders, created_at)
documents     (id, name, file_path, type, folder_id→folders, file_size_bytes, imported_at)
tags          (id, label, color_value)
tag_bindings  (tag_id→tags, folder_id→folders, document_id→documents)
```

Les suppressions en cascade sont activées (`PRAGMA foreign_keys = ON`) : supprimer un dossier supprime ses sous-dossiers, ses documents et leurs liaisons de tags.

---

## Lancer le projet

**Prérequis** : Flutter avec Dart 3.11.3 ou compatible, Android SDK, un émulateur ou appareil Android 7.0 (API 24) minimum connecté.

```bash
# Cloner le dépôt
git clone <url-du-repo>
cd doc_manager

# Installer les dépendances
flutter pub get

# Lancer sur Android
flutter run
```

---

## Ce qui n'est pas dans la v1 (par choix)

- Pas de cloud, pas de synchronisation
- Pas de compte utilisateur
- Pas d'authentification locale (PIN, biométrie)
- Pas de chiffrement des fichiers

Ces fonctionnalités sont envisageables en v2 sans changer l'architecture.

---

## Roadmap v2 (idées)

- [ ] Miniatures d'images dans les cartes de fichiers
- [ ] Tri des dossiers/fichiers (nom, date, taille)
- [ ] Verrouillage de l'app par code PIN ou biométrie
- [ ] Export/backup de la base vers un ZIP
- [ ] Support des fichiers XLSX et TXT


## Vérifier le scanner

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Les tests couvrent le recadrage, la rotation, les PDF à une ou plusieurs pages,
l’import en base dans un dossier profond, les échecs d’import, les actions d’aperçu,
la caméra simulée (capture, reprise, permissions, cycle de vie) et le classement depuis l’interface.

À vérifier également sur un téléphone Android :
1. Refuser puis autoriser la caméra depuis les paramètres.
2. Photographier plusieurs feuilles, passer l’app en arrière-plan puis revenir.
3. Recadrer, tourner, réordonner et reprendre une page ; vérifier sa lisibilité.
4. Nommer le PDF, créer un sous-dossier de destination et enregistrer.
5. Ouvrir le PDF dans ce dossier, vérifier le nombre et l’ordre des pages, puis le partager.

### Signature Android release

Copier `android/key.properties.example` vers `android/key.properties`, puis
renseigner les identifiants du keystore. Le chemin `storeFile` est relatif à
`android/app` (ou absolu). Le fichier de propriétés et les keystores sont exclus
de Git. Conserver ces fichiers en lieu sûr : ils sont nécessaires aux mises à jour
signées. Sans cette configuration, la signature release échoue ; le développement
en debug reste disponible.
