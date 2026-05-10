# Mon Classeur — Gestionnaire de documents personnel

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

### Visionneuse
- **PDF** : navigation par swipe, indicateur de page
- **Images** : affichage zoomable (pinch-to-zoom)
- **DOCX/DOC** : aperçu non disponible nativement — bouton de partage pour ouvrir avec une app externe

### Partage
- Partager n'importe quel fichier en un tap via WhatsApp, email ou toute autre app présente sur l'appareil (intent Android standard)

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

**Prérequis** : Flutter 3.x, Android SDK, un émulateur ou appareil Android connecté.

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
