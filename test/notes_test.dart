import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/core/database/app_database.dart' hide NoteFolder;
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';
import 'package:study_buddy/features/dashboard/domain/dashboard_models.dart';

void main() {
  test('note JSON round-trip preserves type, pages, tags and flags', () {
    final note = NoteItem(
      id: 'note-1',
      title: 'Mathematik Didaktik',
      type: NoteType.long,
      folderId: 'folder-1',
      subjectId: 'math',
      tags: const ['prüfung', 'zusammenfassung'],
      isFavorite: true,
      isPinned: true,
      pages: const [
        NotePage(id: 'page-1', title: 'Einführung', content: 'Lernen'),
        NotePage(
          id: 'page-2',
          title: 'Piaget',
          content: 'Entwicklung',
          sortOrder: 1,
        ),
      ],
    );

    final decoded = NoteItem.decode(note.id, note.encode());
    expect(decoded.type, NoteType.long);
    expect(decoded.folderId, 'folder-1');
    expect(decoded.subjectId, 'math');
    expect(decoded.tags, ['prüfung', 'zusammenfassung']);
    expect(decoded.isFavorite, isTrue);
    expect(decoded.isPinned, isTrue);
    expect(decoded.pages.length, 2);
    expect(decoded.preview, contains('Lernen'));
  });

  test('old note payloads get safe defaults', () {
    final note = NoteItem.fromJson('old-note', const {
      'title': 'Alte Notiz',
      'body': 'Nur Text',
    });

    expect(note.type, NoteType.quick);
    expect(note.body, 'Nur Text');
    expect(note.pages, isEmpty);
    expect(note.tags, isEmpty);
  });

  test('checklist notes are serialized as their own note type', () {
    final note = NoteItem(
      id: 'checklist-1',
      title: 'Material',
      type: NoteType.checklist,
      body: '☐ Kleber\n☐ Schere',
    );

    final decoded = NoteItem.decode(note.id, note.encode());
    expect(decoded.type, NoteType.checklist);
    expect(decoded.body, contains('☐ Kleber'));
  });

  test(
    'local SQLite stores, updates and soft deletes notes and folders',
    () async {
      final database = AppDatabase();
      final repo = DriftStudyBuddyRepository(database);
      addTearDown(repo.dispose);

      final folder = NoteFolder(id: 'folder-local', name: 'Mathematik');
      await repo.addNoteFolder(folder);
      expect(
        (await repo.loadInitialState()).noteFolders.single.name,
        'Mathematik',
      );

      final note = NoteItem(
        id: 'note-local',
        title: 'Kurznotiz',
        body: 'Milch kaufen',
        folderId: folder.id,
        tags: const ['privat'],
      );
      await repo.addNote(note);
      expect((await repo.loadInitialState()).notes.single.folderId, folder.id);

      await repo.updateNote(
        note.copyWith(
          title: 'Einkauf',
          isFavorite: true,
          updatedAt: DateTime(2026, 9, 24),
        ),
      );
      final updated = (await repo.loadInitialState()).notes.single;
      expect(updated.title, 'Einkauf');
      expect(updated.isFavorite, isTrue);

      await repo.deleteNote(note.id);
      await repo.deleteNoteFolder(folder.id);
      expect((await repo.loadInitialState()).notes, isEmpty);
      expect((await repo.loadInitialState()).noteFolders, isEmpty);

      final noteRow = await (database.select(
        database.notes,
      )..where((r) => r.id.equals(note.id))).getSingle();
      expect(noteRow.deletedAt, isNotNull);
      expect(noteRow.needsSync, isTrue);

      final folderRow = await (database.select(
        database.noteFolders,
      )..where((r) => r.id.equals(folder.id))).getSingle();
      expect(folderRow.deletedAt, isNotNull);
      expect(folderRow.needsSync, isTrue);
    },
  );
}
