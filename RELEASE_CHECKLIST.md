# StudyBuddy Release-Checkliste

Diese Checkliste ist für eine fertige Release-Version gedacht, die du ohne VS/SDK auf den Geräten deiner Freundin installieren kannst.

## 1) Was das App-Icon betrifft

Ja: Das Projekt nutzt das SVG aus [assets/mainicon/icon.svg](assets/mainicon/icon.svg) als zentrales App-Asset im Code.

Das bedeutet:

- innerhalb der Flutter-App wird das SVG als in-App-Icon/Logo verwendet
- das ist aber nicht automatisch der komplette Release-Icon-Satz für Windows-Installer, Android-Launcher, Tablet-Launcher und Store-Icons

Für echte Release-Builds brauchst du zusätzlich:

- Windows Icon(s) für den Installer / exe
- Android Adaptive Icons / Launcher Icons
- ggf. Tablet- und Phone-Sizes getrennt

Kurz gesagt:

- [assets/mainicon/icon.svg](assets/mainicon/icon.svg) = App-Asset / in-app icon
- Release-Icons für Windows + Android = separate Artifacts, die man für den finalen Build erzeugen muss

---

## 2) Für die fertige Distribution brauchst du nur diese 3 Dinge

### A) Build auf deinem Rechner

Du baust die Release-Version auf deinem Entwicklungsrechner.

#### Einmalige Supabase-Konfiguration

Lege lokal die Datei `.config/supabase.local.json` an. Verwende dabei die
Projekt-URL und den **Publishable Key** aus Supabase, niemals den
`service_role`- oder Secret Key:

```json
{
	"SUPABASE_URL": "https://DEIN-PROJEKT.supabase.co",
	"SUPABASE_PUBLISHABLE_KEY": "DEIN-PUBLISHABLE-KEY"
}
```

Die Datei bleibt nur auf deinem Entwicklungsrechner und wird nicht verteilt.
Sie ist in `.gitignore` eingetragen.

#### Windows

```powershell
flutter clean
flutter pub get
flutter build windows --release --dart-define-from-file=.config/supabase.local.json
```

#### Android

```powershell
flutter clean
flutter pub get
flutter build apk --release --dart-define-from-file=.config/supabase.local.json
```

Oder für App Bundle:

```powershell
flutter build appbundle --release --dart-define-from-file=.config/supabase.local.json
```

### B) Die fertige Datei auf die Geräte kopieren

- Windows: .exe / Installer-Datei
- Android: APK oder App Bundle

### C) Installieren auf den Geräten

#### Windows

- Datei ausführen
- Installationsdialog bestätigen
- App starten

#### Android

- APK öffnen
- "Installation erlauben"
- App installieren

Kein VS, kein SDK, kein USB-Debugging, kein Android Studio auf ihren Geräten nötig.

---

## 3) Was auf den Geräten nicht nötig ist

Für deine Freundin nicht nötig:

- Visual Studio
- Flutter SDK
- Android Studio
- USB-Debugging
- ADB
- Entwickleroptionen
- "flutter run"

Ihre Geräte sind Endgeräte, keine Entwicklungsgeräte.

---

## 4) Release-Checkliste vor dem Verteilen

### App- und Build-Checks

- [ ] `flutter pub get` erfolgreich
- [ ] `flutter analyze` ohne Fehler
- [ ] `flutter test` grün
- [ ] Supabase-URL gesetzt
- [ ] Supabase Publishable Key gesetzt
- [ ] App läuft ohne Debug-Konfiguration lokal
- [ ] Release-Build erzeugt

### Daten-/Sync-Checks

- [ ] Supabase-Projekt existiert
- [ ] `study_items`-Migration angewendet
- [ ] RLS aktiv
- [ ] `owner_id = auth.uid()` korrekt
- [ ] App mit demselben Konto angemeldet
- [ ] alle drei Geräte nutzen dieselbe Supabase-Instanz

### Release-Icons

- [ ] `dart run flutter_launcher_icons` ausgeführt
- [ ] Windows- und Android-Launcher-Icons aus [assets/mainicon/icon.svg](assets/mainicon/icon.svg) erzeugt
- [ ] Tablet/Phone-Icongrößen korrekt
- [ ] App-Logo in [assets/mainicon/icon.svg](assets/mainicon/icon.svg) geprüft

### Verteilung

- [ ] Windows-Version als Installer bereit
- [ ] Android-APK / AAB bereit
- [ ] Installationsanleitung notiert
- [ ] Wiederherstellungsplan dokumentiert

---

## 5) Praktischer Ablauf für drei Geräte

### 1. Build auf deinem Rechner

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build windows --release --dart-define-from-file=.config/supabase.local.json
flutter build apk --release --dart-define-from-file=.config/supabase.local.json
```

### 2. Fertige Dateien sammeln

- `build/windows/x64/runner/Release/...` für Windows
- `build/app/outputs/flutter-apk/app-release.apk` für Android

### 3. Geräte verteilen

- Handy: APK installieren
- Tablet: APK installieren
- Laptop: Windows-Release installieren

### 4. Auf allen Geräten anmelden

- gleiche Supabase-URL
- gleicher Publishable Key
- dieselbe User-Kennung / dasselbe Konto

### 5. Erstes Sync durchführen

- App öffnen
- anmelden
- lokal gespeicherte Daten hochladen
- nach erfolgreichem Sync prüfen

---

## 6) No-Go / Risiken vermeiden

- [ ] keine komplette Datenbank löschen
- [ ] keine Supabase-Tabelle zurücksetzen
- [ ] keine App deinstallieren ohne vorherige Prüfung
- [ ] keine verschiedenen Accounts auf demselben Gerät parallel verwenden
- [ ] keine Release-Version ohne gültige Supabase-Konfiguration verteilen

---

## 7) Kurzfassung

Ja: Das SVG aus [assets/mainicon/icon.svg](assets/mainicon/icon.svg) ist das zentrale Design-Asset der App.

Aber für echte Release-Versionen brauchst du zusätzlich einen richtigen Icon-Set für Android + Windows.

Der eigentliche Installationsweg für ihre Geräte ist trotzdem einfach:

- Windows: fertiger Installer ausführen
- Android: APK installieren
- keine VS/SDK/Debug-Erfordernisse auf ihren Geräten

Wenn du willst, mache ich dir als Nächstes noch eine wirklich kompakte „copy-paste“-Checkliste mit den exakten Befehlen für Windows + Android Release. 
