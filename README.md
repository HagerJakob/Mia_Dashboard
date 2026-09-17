# StudyBuddy

Flutter-App fuer Windows und Android. Die App startet mit leeren Daten und
speichert Eintraege lokal in Drift/SQLite. Die Web-Vorschau verwendet nur
Arbeitsspeicher und verliert Eintraege beim Neuladen.

## Supabase einrichten

1. Ein Supabase-Projekt erstellen. In **Authentication > Providers** E-Mail/
   Passwort aktivieren. In **Authentication > Users** das Konto fuer Mia
   anlegen. Die App bietet absichtlich keine oeffentliche Registrierung.
2. Die Datei `supabase/migrations/202609170001_study_items.sql` im Supabase
   SQL Editor ausfuehren. Sie erstellt `study_items` mit Row Level Security:
   angemeldete Nutzer sehen und aendern nur ihre eigenen Daten.
3. Projekt-URL und **Publishable Key** unter **Project Settings > API** kopieren.
   Niemals den `service_role`- oder Secret Key in die App eintragen.
4. Fuer die lokale Windows-Entwicklung die Datei
   `.config/supabase.local.json` mit `SUPABASE_URL` und
   `SUPABASE_PUBLISHABLE_KEY` befuellen. Diese Datei ist in `.gitignore` und
   darf nicht per `git add -f` eingecheckt werden. In VS Code den Ordner
   `C:\Mia_Dashboard` oeffnen, **StudyBuddy (Windows)** als Startkonfiguration
   waehlen und **F5** druecken. Die Werte werden dabei per
   `--dart-define-from-file` an Flutter uebergeben.

   Alternativ im Terminal:

   ```powershell
   flutter run -d windows --dart-define-from-file=.config/supabase.local.json
   ```

   Fuer Android `-d android` verwenden. Ohne die beiden Defines bleibt die App
   rein lokal nutzbar. In **Konto & Synchronisierung** mit dem zuvor angelegten
   Konto anmelden. Danach werden lokale Daten hochgeladen und Cloud-Daten
   heruntergeladen. Jede weitere Aenderung startet einen Abgleich. Bei
   Verbindungsproblemen bleiben Aenderungen lokal vorgemerkt; **Jetzt
   synchronisieren** wiederholt den Abgleich.

## Pruefen

```powershell
flutter pub get
flutter analyze
flutter test
```

Windows benoetigt Visual Studio mit **Desktop development with C++** und
aktivierten Windows Developer Mode fuer Plugin-Symlinks.
