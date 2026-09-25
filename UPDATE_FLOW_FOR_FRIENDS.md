# Update-Flow für Handy, Tablet und Laptop ohne Datenverlust

Diese Anleitung beschreibt den sicheren Weg, neue Versionen der StudyBuddy-App zu verteilen, ohne die bisherigen Daten zu verlieren.

## 1) Grundprinzip

Die App ist so gebaut, dass Daten lokal in SQLite/Drift und remote in Supabase gespeichert werden. Ein normales App-Update darf die Datenbank nicht löschen.

Datenverlust entsteht nur dann, wenn man etwas der folgenden Dinge macht:

- App komplett deinstallieren
- App-Daten löschen
- lokale SQLite-Datei manuell entfernen
- Supabase-Tabelle zurücksetzen
- anderes Konto auf einem Gerät anmelden

Wenn du das vermeidest, bleiben die Daten erhalten.

---

## 2) Was immer gleich bleiben muss

Bei jedem Update müssen dieselben Dinge unverändert bleiben:

- dieselbe Supabase-URL
- derselbe Publishable Key
- dasselbe StudyBuddy-Konto
- dieselbe App-Umgebung

Wenn du bei einem Update das Konto änderst oder die Supabase-Instanz wechselst, kann es zu einer falschen Zuordnung oder zu Datenverlust kommen.

---

## 3) Sicherer Update-Workflow

### Schritt 1: neue App-Version bauen

Auf deinem Rechner:

#### Windows

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

#### Android

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Oder alternativ App Bundle:

```powershell
flutter build appbundle --release
```

### Schritt 2: neue Version testen

Bevor du sie weitergibst:

- App starten
- anmelden
- mit Supabase prüfen, ob Sync funktioniert
- kurz eine Testdaten-Änderung machen
- prüfen, ob sie nach dem Sync sichtbar bleibt

### Schritt 3: neue Version auf die Geräte installieren

#### Handy / Tablet

- APK-Datei senden
- auf Gerät öffnen
- Installieren erlauben

#### Laptop

- Installer / .exe-Datei ausführen
- App installieren

### Schritt 4: mit demselben Konto anmelden

Auf jedem Gerät muss dieselbe Person eingeloggt sein.

Wenn die App beim Start bereits angemeldet ist, einfach öffnen. Falls nicht, erneut einloggen.

### Schritt 5: Sync ausführen

- App öffnen
- Login
- relevante Daten prüfen
- optional manuell synchronisieren

---

## 4) Was passiert bei einem Update wirklich?

Im aktuellen Code wird die App lokal in Drift/SQLite gespeichert und remote in Supabase synchronisiert.

Wenn du nur die neue App-Version installierst:

- alte lokale Daten bleiben auf dem Gerät
- App-Update überschreibt nicht automatisch die Datenbank
- beim nächsten App-Start/Resume versucht die App erneut den Sync
- Supabase liefert den aktuellen Stand

Dadurch bleibt die Datenbasis konsistent.

---

## 5) Was du unter keinen Umständen tun solltest

Nicht tun:

- App deinstallieren und neu installieren
- lokale SQLite-Datei manuell löschen
- App-Datenordner löschen
- Supabase-Tabelle zurücksetzen
- verschiedene Accounts auf demselben Gerät parallel nutzen
- nach dem Update ein anderes Konto anmelden

Wenn du das machst, kann die App dieselben Daten nicht sauber zuordnen.

---

## 6) Praktischer Ablauf für deine Freundin

### Für Handy/Tablet

1. neue APK senden
2. auf Gerät öffnen
3. installieren
4. App öffnen
5. mit dem gleichen Konto anmelden
6. Sync warten
7. Daten prüfen

### Für Laptop

1. neuen Installer geben
2. installieren
3. App öffnen
4. mit demselben Konto anmelden
5. Daten prüfen

---

## 7) Sicherheitsregel für Updates

Die zuverlässige Regel lautet:

- Update = neue App-Version ersetzen
- kein Reset der lokalen Daten
- nur derselbe Supabase-Account
- gleiche App-Umgebung

Damit bleiben bisherige Daten erhalten.

---

## 8) Kurzfassung

Wenn du eine neue Version verteilt, ohne die App zu deinstallieren oder die Datenbank zu löschen, dann bleiben die bisherigen Daten erhalten.

Der einzige wichtige Punkt ist: immer mit demselben Supabase-Konto und derselben Supabase-Instanz weiterarbeiten.

Wenn du möchtest, kann ich dir noch eine ganz kompakte Version davon als “one-page release checklist” schreiben, die du einfach im Projekt liegen lassen kannst. 
