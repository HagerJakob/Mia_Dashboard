# StudyBuddy App Overview

Diese Datei ist als technisches Briefing fuer eine zweite KI oder fuer einen Code-Review gedacht. Sie beschreibt, was die App aktuell kann, wie die wichtigsten Seiten funktionieren und welche Architekturentscheidungen bereits getroffen wurden.

## Kurzbeschreibung

StudyBuddy ist eine persoenliche Study- und Produktivitaets-App fuer Mia. Die App ist fuer Windows Desktop, Android Smartphone und Android Tablet gebaut. Sie nutzt Flutter/Dart, Riverpod, Drift/SQLite fuer lokale Speicherung und Supabase fuer Auth und Synchronisierung.

Das wichtigste Architekturziel ist offline-first:

1. UI schreibt zuerst lokal.
2. Repository speichert in Drift/SQLite.
3. Sync laeuft danach im Hintergrund.
4. Supabase-Fehler duerfen lokale Aenderungen nicht zurueckrollen.
5. Die UI soll ihre Daten primaer aus lokalem Zustand bzw. der lokalen Datenbank beziehen.

## Tech Stack

- Flutter / Dart
- Flutter Desktop fuer Windows
- Flutter Android
- Riverpod fuer State Management
- Drift / SQLite fuer lokale Daten
- Supabase Auth
- Supabase Tabelle `study_items` fuer Sync
- Supabase Realtime ist vorbereitet, aber aktuell nicht als Live-Subscription umgesetzt
- `rrule` fuer wiederkehrende Kalendertermine
- `flutter_svg` fuer das App-Icon
- Material 3 mit eigenem StudyBuddy Design-System

## Projektstruktur

Wichtige Bereiche:

- `lib/main.dart`: startet Bootstrap und `ProviderScope`.
- `lib/app/app.dart`: MaterialApp, deutsche Lokalisierung, App-Lifecycle-Sync.
- `lib/app/bootstrap.dart`: initialisiert Supabase aus `--dart-define`.
- `lib/core/database/`: Drift Datenbank, Tabellen, Migrationen, Plattform-Connection.
- `lib/core/supabase/`: Supabase-Konfiguration und Client.
- `lib/core/sync/`: Sync-Services, SyncCoordinator und Supabase-Abgleich.
- `lib/core/utils/`: responsive Helfer.
- `lib/features/dashboard/`: Haupt-State, Repository, Dashboard-Shell und Dashboard-Inhalte.
- `lib/features/calendar/`: Kalender-Modelle, Services, Controller, Views und Editor.
- `lib/features/tasks/`: Aufgaben-Seite.
- `lib/features/notes/`: Notizen-Seite.
- `lib/features/subjects/`: Faecher-Seite.
- `lib/features/exams/`: Pruefungs-Seite.
- `lib/features/timer/`: Focus-/Timer-Seite.
- `lib/features/statistics/`: Analytics-Service und Statistik-Seite.
- `lib/features/auth/`: Konto- und Sync-Seite.
- `lib/shared/design_system/`: zentrale Farben, Cards, Badges, Empty States, Assets.

## Navigation und Shell

Die Hauptnavigation liegt in `DashboardScreen`.

Desktop:

- Linke Sidebar mit Dashboard, Kalender, Aufgaben, Notizen, Faecher, Pruefungen, Timer und Statistiken.
- Bei mittleren Breiten wird eine `NavigationRail` verwendet.
- Der Hauptbereich wechselt anhand von `StudyBuddyState.selectedIndex`.

Mobile:

- Bottom Navigation mit Home, Kalender, Aufgaben, Lernen und Mehr.
- Unter Mehr liegen Notizen, Faecher, Pruefungen und Statistiken.
- Sekundaere Seiten bekommen oben einen Zurueck-Button zur Mehr-Seite.

## Zentrales State Management

Der zentrale Provider ist `studyBuddyControllerProvider` in `dashboard_controller.dart`.

Er haelt:

- aktuell ausgewaehlte Navigation
- Dashboard-Schedule
- Aufgaben
- Notizen
- Notizordner
- Faecher
- Pruefungen
- Erinnerungen
- Study Sessions
- einfachen Dashboard-Timer-State

Die Daten werden beim Start aus dem Repository geladen. Nach dem Laden wird ein manueller Sync angestossen, danach wird der lokale Zustand erneut aktualisiert.

## Repository und lokale Speicherung

Das Interface `StudyBuddyRepository` definiert alle lokalen CRUD-Operationen fuer:

- Schedule/Kalender
- Aufgaben
- Notizen
- Notizordner
- Faecher
- Pruefungen
- Erinnerungen
- Study Sessions
- Kalender-Kategorien

Implementierungen:

- `InMemoryStudyBuddyRepository`: fuer Web/Vorschau ohne dauerhafte lokale Speicherung.
- `DriftStudyBuddyRepository`: produktive lokale Speicherung auf Windows/Android.

Das Repository ist bewusst die zentrale Stelle fuer Persistenz. UI-Widgets sollen keine Supabase-Schreiblogik enthalten.

## Drift / SQLite Datenmodell

Die lokale Datenbank liegt in `AppDatabase`.

Tabellen:

- `schedule_entries`
- `tasks`
- `notes`
- `note_folders`
- `subjects`
- `exams`
- `reminders`
- `calendar_categories`
- `study_sessions`

Gemeinsame Sync-Felder:

- `created_at`
- `updated_at`
- `deleted_at`
- `needs_sync`

Soft Delete:

- Loeschen setzt `deleted_at` und `needs_sync = true`.
- Aktive Queries filtern `deleted_at IS NULL`.
- Das ist wichtig fuer Multi-Device-Sync, weil geloeschte Datensaetze an Supabase uebertragen werden muessen.

Viele komplexe Modelle werden als JSON in Spalten gespeichert:

- Aufgaben: `task_json`
- Notizen: `note_json`
- Pruefungen: `exam_json`
- Kalendertermine: `event_json`
- Study Sessions: `session_json`

## Supabase Sync

Supabase wird ueber `SupabaseService` initialisiert. Die Werte kommen lokal per `--dart-define`:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Die zentrale Sync-Logik ist `StudySync`.

Sie synchronisiert folgende `kind`-Werte in Supabase `study_items`:

- `schedule`
- `task`
- `note`
- `note_folder`
- `subject`
- `exam`
- `reminder`
- `calendar_category`
- `study_session`

Sync-Ablauf:

1. Wenn kein Supabase-User angemeldet ist, endet Sync sofort.
2. Lokale Rows mit `needs_sync == true` werden zu Supabase hochgeladen.
3. Nach erfolgreichem Upload wird die Row lokal als clean markiert.
4. Danach werden Remote-Rows seitenweise aus Supabase geladen.
5. Remote-Daten werden lokal nur angewendet, wenn lokal keine dirty Version existiert und die Remote-Version neuer ist.
6. Remote angewendete Daten bekommen `needsSync: false`, damit kein Sync-Loop entsteht.

## SyncCoordinator

Der `SyncCoordinator` verhindert parallele Syncs.

Eigenschaften:

- `flush()` startet sofort und wartet auf Abschluss. Wird fuer manuelle Synchronisation genutzt.
- `requestSync()` startet im Hintergrund.
- Wenn waehrend eines laufenden Syncs neue Aenderungen kommen, wird ein Follow-up-Sync vorgemerkt.
- Debounced Sync ist moeglich und wird fuer haeufige Notiz-Updates verwendet.

Dadurch blockieren normale UI-Aktionen Supabase nicht mehr.

## App-Lifecycle-Sync

In `app.dart` gibt es `_LifecycleSync`.

Beim App-Resume wird `studyBuddyControllerProvider.notifier.syncNow()` aufgerufen. Dadurch versucht die App beim Zurueckkehren in den Vordergrund erneut zu synchronisieren.

Ein echter Connectivity-Listener ist aktuell nicht eingebaut. Sync passiert derzeit bei:

- App-Start
- Login
- manueller Synchronisierung
- App-Resume
- lokalen Mutationen

## Seite: Dashboard

Dateien:

- `dashboard_screen.dart`
- `dashboard_content.dart`
- `dashboard_sections.dart`

Zweck:

- Persoenliche Startseite fuer Mia.
- Zeigt eine Uebersicht ueber Lernfortschritt, Aufgaben, naechste Pruefungen, Focus-Timer, Wochenuebersicht, Notizen und Tagesziel.

Daten:

- Nutzt `StudyBuddyState`.
- Aggregiert vorhandene Aufgaben, Pruefungen, Notizen und Study Sessions.

UX:

- Desktop-first Dashboard mit Cards.
- Mobile nutzt dieselben Daten, aber kompaktere Navigation.
- Design basiert auf warmem Off-White, Mauve, Lavender und subtilen Pastellfarben.

## Seite: Kalender

Dateien:

- `calendar_screen.dart`
- `calendar_controller.dart`
- `calendar_views.dart`
- `calendar_editor.dart`
- `academic_period_editor.dart`
- `calendar_models.dart`
- `calendar_services.dart`

Zweck:

- Vollwertiger Studienkalender mit Monat, Woche, Tag und Agenda.
- Unterstuetzt normale Termine, wiederkehrende Termine, Feiertage und akademische Zeitraeume.

Views:

- Monatsansicht: zeigt nur Tage des aktuellen Monats. Vorheriger/naechster Monat bleibt als leere Zelle sichtbar, aber ohne Zahl, Events oder Interaktion.
- Wochenansicht: Timeline mit Terminen.
- Tagesansicht: Timeline und Tagesdetails.
- Agenda: chronologische Liste. Faecher sollen hier nicht als einzelne Standardtermine auftauchen, damit sie nicht ueberfuellt wird.

Terminmodell:

`CalendarEvent` enthaelt:

- Titel
- Kategorie
- Fach-Verknuepfung
- Beschreibung
- Ort
- Online-Link
- Start/Ende
- Ganztag
- Farbe
- Prioritaet
- Recurrence Rule
- Erinnerungen
- Praxis-Metadaten
- Source
- Serien-/Occurrence-Informationen

Wiederholungen:

- Werden mit `rrule` gespeichert.
- Wiederholungen werden nicht als tausende DB-Zeilen materialisiert.
- `RecurrenceService.expand()` expandiert nur fuer den sichtbaren Zeitraum.
- Ausnahmen einzelner Wiederholungen werden ueber `seriesId` und `occurrenceAt` modelliert.

Feiertage:

- `HolidayService` berechnet oesterreichische Feiertage.
- Bewegliche Feiertage werden algorithmisch ueber Ostern berechnet.
- Feiertage sind keine normalen User-Termine und werden nicht als User-Events gespeichert.

Akademische Zeitraeume:

- `AcademicCalendarService` enthaelt nur bestaetigte PH-Salzburg-Daten.
- Schulferien werden bewusst nicht mit Hochschulferien verwechselt.
- Zukuenftige nicht bestaetigte Zeitraeume werden nicht erfunden.

Studienfortschritt:

- `StudyTimeline` berechnet Semester anhand Studienstart WS 2026/27.

## Seite: Aufgaben

Dateien:

- `tasks_screen.dart`
- `dashboard_models.dart`

Zweck:

- Aufgaben erstellen, bearbeiten, loeschen und abhaken.
- Aufgaben koennen Faecher, Prioritaeten, Status, Deadlines, Subtasks, Tags und Wiederholungen haben.

Modell:

`TaskItem` enthaelt:

- Titel
- Beschreibung
- Status
- Prioritaet
- Start- und Faelligkeitsdatum
- Abschlussdatum
- Fach-ID
- Kategorie
- geschaetzte Minuten
- Tags
- Subtasks
- Recurrence Rule
- Erinnerungen
- verknuepfter Kalendertermin

Wichtig:

- Aufgaben werden lokal gespeichert und danach automatisch synchronisiert.
- Soft Delete wird verwendet.
- Aufgaben sollen spaeter in Agenda/Statistik staerker integriert werden.

## Seite: Notizen

Dateien:

- `notes_screen.dart`
- `dashboard_models.dart`

Zweck:

- Notizen organisieren, erstellen, bearbeiten und loeschen.
- Unterstuetzt Ordner.
- Notizen koennen per Drag & Drop in erstellte Ordner verschoben werden.

Notiztypen:

- Kurznotiz
- Langnotiz
- Checkliste

Checklisten:

- Sind ein eigener Notiztyp.
- Punkte haben anklickbare Kreise/Checkboxen.
- Enter erzeugt einen neuen Checklisteneintrag und soll den Fokus im neuen Feld behalten.
- Formatierungsbuttons wie fett/kursiv/liste sind fuer Checklisten bewusst nicht vorgesehen.

Langnotizen:

- Koennen mehrere Seiten besitzen.
- Textformatierung ist teilweise implementiert.

Ordner:

- Ordner koennen erstellt, bearbeitet und geloescht werden.
- Loeschen verschiebt enthaltene Notizen nicht physisch, sondern loest die Ordner-Verknuepfung bzw. entfernt Ordner per Soft Delete.

Sync:

- Notiz-Updates triggern debounced Sync, damit Tippen nicht staendig Supabase aufruft.

## Seite: Faecher

Dateien:

- `subjects_screen.dart`
- `dashboard_models.dart`

Zweck:

- Faecher anlegen, bearbeiten und loeschen.
- Jedes Fach hat eine Farbe.
- Faecher koennen als wiederkehrende Termine in den Kalender eingetragen werden.

Aktueller Fokus:

- Mia kann ihre Studienfaecher selbst eintragen.
- Die App startet leer; keine Dummy-Faecher sollen vorgegeben sein.
- Termine fuer Faecher im ersten Semester sollen zeitlich nur bis zum Ende des ersten Semesters laufen.

Modell:

`SubjectItem` ist aktuell bewusst einfach:

- `id`
- `name`
- `color`

Erweiterte Fach-Terminlogik wird aktuell ueber Kalendertermine bzw. Payloads geloest, nicht ueber eine zweite Fach-Datenbank.

## Seite: Pruefungen

Dateien:

- `exams_screen.dart`
- `dashboard_models.dart`

Zweck:

- Pruefungen erstellen, bearbeiten, loeschen und vorbereiten.
- Pruefungen koennen mit Faechern verknuepft werden.
- Vorbereitung, Kapitel, Fortschritt, Erinnerungen und Status sind vorgesehen.

Modell:

`ExamOverview` enthaelt:

- Titel
- Fach
- Fach-ID
- Pruefungstyp
- Start/Ende
- Ort/Raum/Online-Link
- Pruefer/in
- Beschreibung
- Status
- Prioritaet
- Vorbereitungsstart
- Kapitel/Themen
- Notizen
- Erinnerungen
- Fortschritt
- Ergebnis
- Note
- Punkte erreicht
- Punkte maximal
- bestanden/nicht bestanden

Wichtig fuer spaetere Statistik:

- Bei erledigten Pruefungen koennen Punkte und Note gespeichert werden.
- Statistik kann daraus spaeter Notendurchschnitt, Bestehensquote und Punkteauswertungen bauen.

## Seite: Timer / Focus

Dateien:

- `timer_screen.dart`
- `dashboard_models.dart`

Zweck:

- Focus Sessions erfassen.
- Unterstuetzt Modi wie Focus, Pomodoro, Countdown und Stopwatch.
- Sessions koennen gespeichert, bearbeitet und geloescht werden.

Modell:

`StudySession` enthaelt:

- Fach-ID
- Pruefungs-ID
- Aufgaben-ID
- Modus
- Status
- Start/Ende
- Fokusdauer
- Pausendauer
- geplante Dauer
- Pomodoro-Fokus-/Pausenminuten
- abgeschlossene Pomodoro-Zyklen
- Notiz

Statistik:

- Die Statistik-Seite baut fast alle Lernzeit-Auswertungen aus `StudySession`.

## Seite: Statistiken

Dateien:

- `statistics_screen.dart`
- `analytics_service.dart`

Zweck:

- Lernzeit und Fortschritt sichtbar machen.
- Nutzt lokale Daten, vor allem Study Sessions, Aufgaben und Pruefungen.

Analytics-Service berechnet:

- Lernzeit im Zeitraum
- Vergleich zum vorherigen Zeitraum
- Anzahl Sessions
- durchschnittliche Sessiondauer
- laengste Session
- Pomodoro-Anzahl
- Aufgabenstatistiken
- Pruefungsstatistiken
- Lernstreak
- Lernzeit pro Tag
- Lernzeit pro Fach
- Lernzeit pro Pruefung
- Lernzeit pro Aufgabe
- Tageszeitverteilung
- Wochentagsdurchschnitt
- Heatmap
- kurze Insights

Zeitraeume:

- Woche
- Monat
- Semester
- Jahr
- Custom

## Seite: Konto & Synchronisierung

Datei:

- `account_screen.dart`

Zweck:

- Supabase Login.
- Manuelle Synchronisierung.
- Logout.

Verhalten:

- Wenn Supabase nicht konfiguriert ist, arbeitet die App lokal.
- Nach Login wird sofort synchronisiert.
- Lokale Daten bleiben beim Logout auf dem Geraet.

## Design System

Dateien:

- `study_colors.dart`
- `study_spacing.dart`
- `study_radius.dart`
- `study_card.dart`
- `study_badge.dart`
- `study_empty_state.dart`
- `study_section_header.dart`
- `study_assets.dart`
- `study_svg_asset.dart`

Designrichtung:

- warmes Off-White
- weisse Cards
- Mauve/Dusty Pink als Primaerakzent
- Lavender und Pastellgruen als dezente Akzente
- ruhig, modern, freundlich
- nicht kitschig
- keine starken Material-Standardfarben

Hinweis:

- `StudyBadge` ist bewusst begrenzt, damit Badges in engen Bereichen wie `ListTile.trailing` oder mobilen Layouts nicht zu Render-Fehlern fuehren.

## Responsive Verhalten

Breakpoints und Helfer liegen in:

- `app_breakpoints.dart`
- `responsive_layout.dart`

Prinzip:

- Desktop: Sidebar und mehrspaltige Layouts.
- Tablet: NavigationRail bzw. angepasste Breiten.
- Smartphone: Bottom Navigation und gestapelte Inhalte.

Wichtig:

- Keine horizontalen Overflows auf Mobile.
- Keine Desktop-Ansichten einfach zusammenquetschen.

## Tests

Vorhandene Testbereiche:

- Analytics
- Kalender-Domain und Kalender-Widgets
- ESC/Dialog-Lifecycle
- Aufgaben-Persistenz
- Notizen-Persistenz
- Pruefungen-Persistenz
- Timer-/StudySession-Persistenz
- Responsive Shell
- SyncCoordinator

Wichtige Befehle:

```bash
flutter pub get
flutter analyze
flutter test
flutter build windows
flutter build apk --debug
```

## Bekannte technische Besonderheiten

### Offline-first

Die App darf nie voraussetzen, dass Supabase erreichbar ist. Jede Mutation muss lokal funktionieren.

### Supabase Sync

Aktuell ist Sync Pull/Push ueber `study_items`. Es gibt noch keinen echten permanenten Connectivity-Listener und keine aktive Supabase-Realtime-Subscription.

### Konfliktstrategie

Lokal dirty gewinnt gegen Remote. Ansonsten wird grob Last-Write-Wins ueber `updated_at` verwendet.

### Wiederkehrende Termine

RRULE wird gespeichert und nur fuer sichtbare Zeitraeume expandiert. Ausnahmen werden separat ueber Serienbezug modelliert.

### Akademische Daten

Nur bestaetigte PH-Salzburg-Zeitraeume sollen hart bzw. lokal vorkonfiguriert werden. Schulferien sind eine eigene optionale Quelle und duerfen nicht automatisch als Hochschulferien gelten.

## Punkte fuer Review / moegliche Verbesserungen

- Umlaute in einigen Quelltext-Strings pruefen. Manche Dateien enthalten sichtbar falsch encodierte Texte wie `FÃ¤cher`; das sollte sauber auf UTF-8 korrigiert werden.
- Sync-Konflikte koennten langfristig detaillierter geloest werden, z. B. feldbasiert oder mit Conflict UI.
- Connectivity-Listener koennte ergaenzt werden, damit Sync direkt nach Wiederverbindung laeuft.
- Supabase Realtime koennte fuer Multi-Device-Live-Updates genutzt werden.
- Repository koennte langfristig feature-spezifischer aufgeteilt werden, solange die zentrale Sync-Strategie erhalten bleibt.
- Mehr Widget-Tests fuer Dialoge und enge Mobile-Layouts waeren sinnvoll.
- Dark Mode ist vorbereitet, aber noch nicht vollstaendig umgesetzt.
- Notizen-Editor koennte staerker modularisiert werden, weil dort viele Spezialfaelle zusammenkommen.
- Kalender-Agenda sollte final klar definieren, welche Quellen angezeigt werden: Aufgaben und Pruefungen ja, normale Fach-Serientermine eher nein.
- App-Icon/Assets sollten fuer Android/Windows final in allen benoetigten Aufloesungen geprueft werden.

## Wichtige Regeln fuer Weiterentwicklung

- Keine Business-Logik direkt in Widgets verschieben.
- UI soll aus lokalem State / lokaler DB arbeiten.
- Keine direkte Supabase-Schreiblogik aus Widgets.
- Keine physischen Deletes fuer sync-relevante Tabellen.
- Keine Dummy-Daten in produktive Startzustaende einfuehren.
- Keine zusaetzlichen akademischen Zukunftsdaten erfinden.
- Dialoge muessen unter Windows sauber per ESC, X und Abbrechen schliessen.
- Nach groesseren Aenderungen immer `flutter analyze`, `flutter test` und mindestens einen Plattform-Build ausfuehren.
