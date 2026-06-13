# Olden Era Wiki (Flutter)

Unofficial wiki companion for *Heroes of Might and Magic: Olden Era*.
Flutter rewrite of the original SwiftUI app (`../olden_era_wiki`), using
Cupertino-style UI on both iOS and Android. The app is fully free — no
in-app purchases.

## Data

- `assets/db/wiki.sqlite` — read-only game database (~34MB), extracted from
  game files by `../olden_era_wiki/extract_wiki_data.py`. It is copied to the
  application support directory on first launch (SQLite cannot open files
  inside the asset bundle) and opened read-only via `sqlite3` +
  `sqlite3_flutter_libs` (bundled SQLite build with FTS5 on both platforms).
- **When replacing wiki.sqlite**, bump `kDbAssetVersion` in
  `lib/data/database.dart` so devices refresh their on-device copy.
- `assets/icons.json` — stat/resource/faction icon key → image path mapping.
- `assets/images/raw/{sprite,texture}/` — ~1,916 PNGs referenced by relative
  paths stored in the database (`Image.asset('assets/$path')`).

## Structure

```
lib/
  main.dart            # bootstrap: DB copy/open, icons.json, prefs
  app.dart             # CupertinoApp + theme + font-size text scaler
  routes.dart          # CupertinoPageRoute push helpers
  theme/               # colors, factions, rarities
  settings/            # AppSettings (theme + font size, SharedPreferences)
  data/
    database.dart      # WikiDatabase singleton (copy-on-first-launch)
    models/            # one file per entity
    queries/           # raw-SQL query extensions, incl. FTS5 globalSearch
  search/              # SearchState (debounce, overlay restore), results UI
  widgets/             # AppScaffold, LocalImage, shared detail widgets
  screens/             # home, settings, 10 entity list+detail screens
```

## Development

```
flutter pub get
flutter run            # iOS simulator or Android emulator
flutter test           # pure-logic ports (highlight parser, sorting, grouping)
```

App icons are generated from `assets/app_icon.png` via
`dart run flutter_launcher_icons`.
