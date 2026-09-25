# StudyBuddy: Geräte-Setup, Sync und Updates ohne Datenverlust

Diese Anleitung beschreibt, wie du die vorhandene StudyBuddy-App auf Laptop, Tablet und Handy einer Person installierst, welche Voraussetzungen auf den Geräten nötig sind und wie Updates ohne Datenverlust erfolgen.

## 1) Kurz gesagt: So geht es ohne SDK/Debug-Voraussetzungen auf dem Gerät

Wenn du die App deiner Freundin einfach auf Handy, Tablet und Laptop installieren willst, brauchst du auf ihren Geräten keine VS-Installation, kein SDK, kein Android Studio und kein USB-Debugging.

Du brauchst nur:

- auf deinem Entwicklungs-Computer: Flutter SDK + passende Build-Tools für die Plattform
- auf ihren Geräten: nur die fertige App-Datei und ein kurzer Installationsschritt

Für Android ist der einfache Weg:

- Release-APK bauen
- Datei per WhatsApp, E-Mail oder USB auf das Handy/Tablet kopieren
- "Unbekannte Apps" / "Installieren unbekannter Apps" aktivieren
- APK installieren

Für Windows:

- Release-Installer (.exe oder .msix) bauen
- Installer auf den Laptop kopieren und ausführen
- kein VS, kein SDK und kein Debug-Setup nötig

Dadurch sind deren Geräte am Ende nur Nutzergeräte, nicht Entwicklergeräte.

## 2) Grundsätzliches

Die App ist aktuell eine Flutter-App mit:

- lokaler Speicherung in Drift / SQLite
- Supabase-Authentifizierung und Sync
- Offline-First-Verhalten
- Account-/Geräte-Bindung zur Vermeidung von falscher Konto-Zuordnung

Die Daten sind deshalb in zwei Schichten gedacht:

1. lokal auf dem Gerät in der SQLite-Datenbank
2. remote im Supabase-Projekt mit `study_items`

Wenn die App auf mehreren Geräten dieselbe Supabase-Umgebung nutzt und dieselbe Person angemeldet ist, werden die Daten nach einem Sync sauber zusammengeführt.

> Wichtig: Die App ist für eine persönliche Nutzung konzipiert, nicht für mehrere Nutzer auf dem selben Gerät oder für eine fremde Konto-Mischung.

---

## 2) Voraussetzungen pro Gerät

### Windows-Laptop

Empfohlen:

- Windows 10 oder 11
- Flutter SDK installiert
- Visual Studio 2022 mit "Desktop development with C++"
- Android Studio nur nötig, wenn du auch Android-Builds prüfen willst
- Optional: Android-Emulator

Für lokale Entwicklung / Testing:

```powershell
flutter --version
flutter doctor
```

Wenn `flutter doctor` Fehler zeigt, zuerst die fehlenden Components ergänzen.

### Android Smartphone / Tablet

Empfohlen:

- Android 8+ (praktisch: aktuelleres Android ist besser)
- USB-Debugging nur für lokale Entwicklung nötig
- alternative Release-Version via APK/AAB oder Play Store-Distribution

Für den normalen Betrieb reicht in der Praxis:

- installierte APK oder veröffentlichte App-Version
- aktivierte Internetverbindung beim ersten Sync

Ein Gerät braucht keine spezielle App-Version, aber die App muss mit derselben Supabase-Konfiguration gebaut sein.

### Wichtig für alle Geräte

Alle Geräte müssen dieselben Werte nutzen:

- dieselbe Supabase-URL
- derselbe Publishable Key
- dieselbe Person eingeloggt

Ohne diese Konfiguration bleibt die App lokal nutzbar, aber ohne echte Synchronisierung.

---

## 3) Wie die App auf die Geräte kommt

### Option A: lokale Entwicklung / Testbetrieb

Für ein anderes Gerät im selben Entwicklungs-Setup:

1. Das Repository auf dem Gerät klonen
2. `.config/supabase.local.json` mit denselben Werten befüllen
3. App starten

Beispiel Windows:

```powershell
flutter run -d windows --dart-define-from-file=.config/supabase.local.json
```

Beispiel Android-Gerät:

```powershell
flutter devices
flutter run -d <device-id> --dart-define-from-file=.config/supabase.local.json
```

### Option B: Release/Betrieb

Für den echten Mehrgerätezinsatz solltest du die App als Release-Version bauen:

- Windows: installer/portable build
- Android: signed APK oder AAB

Dann auf das jeweilige Gerät installieren.

> Der Code in diesem Projekt erwartet, dass die Supabase-Konfiguration beim App-Start vorhanden ist. Wenn sie fehlt, funktioniert die App weiter lokal, aber nicht syncfähig.

---

## 4) Was für die Synchronisierung nötig ist

Die App verwendet aktuell:

- lokale Drift-Datenbank
- Supabase `study_items` Tabelle
- beim Login/Sync wird mit dem gleichen Supabase-User gearbeitet

Damit mehrere Geräte zuverlässig gleiche Daten sehen:

1. auf allen Geräten dieselbe Supabase-Instanz verwenden
2. dieselbe Person mit demselben Konto anmelden
3. App nicht zwischendurch mit anderem Konto anmelden
4. Gerät nicht neu installieren, ohne vorher die Datenlage zu prüfen

Die App hat eine feste Geräte-Account-Bindung eingebaut, damit ein Gerät nicht versehentlich Daten eines anderen Accounts übernimmt.

---

## 5) Upgrade und neue Features ohne Datenverlust

### Grundsatz

Die App ist so gebaut, dass ein Update die vorhandenen lokalen Daten nicht löschen soll. Die wichtigste Regel ist:

- keine Neuinstallation ohne Notfall-Backup
- keine Tabelle manuell löschen
- keine lokale Datenbank manuell resetten
- keine Supabase-Tabelle komplett zurücksetzen

### Lokal auf dem Gerät

Die lokale Datenbank liegt im normalen App-Datenbereich. Bei einem normalen Update bleibt sie normalerweise erhalten, solange:

- die App nicht deinstalliert wird
- der App-Datenordner nicht gelöscht wird
- die App nicht mit "Daten löschen" neu installiert wird

Bei Flutter/Drift ist das üblicherweise die lokale SQLite-Datei innerhalb des App-Speichers.

### Remote in Supabase

Der Sync läuft über `study_items` und `owner_id` + `kind` + `id`.

Wichtige Regeln:

- bestehende Daten nicht löschen
- neue Features nur ergänzend einbauen
- bei Schema-Anpassung keine alte Tabelle ersetzen
- Migrationen in Supabase nur als echte Update-Migrationen ausführen

### Wenn ein neues Feature ein neues Datenfeld braucht

Beispiel:

- neue Spalte / neues JSON-Feld
- neues Model / neue enum-Werte

Dann gilt:

1. bestehende Daten beibehalten
2. DB-Migration hinzugefügt (Drift / local schema)
3. Supabase-SQL-Migration nur ergänzen, nicht löschen
4. App-Update validieren, bevor breit verteilt wird

In diesem Projekt gibt es bereits Drift-Migrationslogik in [lib/core/database/app_database.dart](lib/core/database/app_database.dart). Dort wird `schemaVersion` hochgezählt und Migrationen sauber ergänzt.

---

## 6) Empfohlener Ablauf für Updates

### Safe Release-Prozess

1. Code in der App ändern
2. lokale Tests ausführen
3. wenn neue Datenfelder nötig sind: Drift-Migration und Supabase-Migration ergänzen
4. App auf einer Test-Umgebung prüfen
5. nur dann auf Laptop/Tablet/Handy verbreiten
6. mit dem gleichen Supabase-Konto anmelden
7. Sync ausführen

### Bei bereits vorhandenen Nutzerdaten

- neue App-Version installieren
- App starten
- beim Resume / Login wird Sync automatisch ausgelöst
- lokale Daten bleiben vorhanden
- Supabase-Daten werden mitgezogen
- keine Daten werden gelöscht, wenn der Update-Pfad sauber ist

---

## 7) Was man auf keinen Fall tun sollte

Nicht tun:

- App deinstallieren und neu installieren, ohne vorher Backup zu prüfen
- Supabase-Tabelle `study_items` komplett löschen
- Datenbankdatei manuell überschreiben
- verschiedene Geräte mit verschiedenen Supabase-Accounts parallel nutzen
- App mit anderem Konto anmelden, obwohl das Gerät noch an ein anderes Konto gebunden ist

---

## 8) Praktische Empfehlung für Mia

Für den realen Mehrgerätezinsatz ist die einfachste robuste Lösung:

- 1 Supabase-Projekt
- 1 Konto für Mia
- alle Geräte mit derselben App-Version und derselben Supabase-Konfiguration
- Updates nur per sauberer Release-Route
- lokale Daten nicht löschen
- bei Schemaänderungen sorgfältig migrieren

Das entspricht der aktuellen Architektur und vermeidet unnötige Komplexität.

---

## 9) Kurzfassung

Ja, die Geräte brauchen Voraussetzungen:

- Windows-Laptop: Flutter + VS C++
- Android-Geräte: Android-Version passend zum Build + installierbare App-Version
- alle Geräte müssen dieselbe Supabase-Instanz und dasselbe Konto nutzen

Updates funktionieren ohne Datenverlust, wenn:

- kein kompletter Datenreset durchgeführt wird
- lokale SQLite-Daten nicht gelöscht werden
- Drift- und Supabase-Migrationen sauber ergänzt werden
- die App mit demselben Supabase-Projekt weiterläuft

Wenn du willst, kann ich dir im nächsten Schritt noch eine konkrete, simple "Deploy-Checklist" für den Laptop, das Tablet und das Handy in einem einzigen kurzen Ablauf erstellen.
