import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/design_system/study_badge.dart';
import '../../../shared/design_system/study_card.dart';
import '../../../shared/design_system/study_empty_state.dart';
import '../../../shared/design_system/study_radius.dart';
import '../../../theme/app_colors.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

enum _NoteScope {
  all,
  favorites,
  recent,
  quick,
  checklist,
  long,
  uncategorized,
}

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  _NoteScope _scope = _NoteScope.all;
  String? _folderId;
  String? _selectedNoteId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBuddyControllerProvider);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final medium = MediaQuery.sizeOf(context).width < 1040;
    final selected = _selectedNote(state);

    if (compact) {
      return Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FloatingActionButton(
          tooltip: 'Neue Notiz',
          onPressed: () => _createNote(NoteType.quick),
          child: const Icon(Icons.add_rounded),
        ),
        body: SafeArea(
          child: selected == null
              ? _NotesListPane(
                  state: state,
                  notes: _visibleNotes(state),
                  search: _search,
                  scope: _scope,
                  folderId: _folderId,
                  onScope: (scope) => setState(() {
                    _scope = scope;
                    _folderId = null;
                  }),
                  onFolder: (id) => setState(() {
                    _folderId = id;
                    _scope = _NoteScope.all;
                  }),
                  onNewFolder: _openFolderEditor,
                  onEditFolder: _openFolderEditor,
                  onDeleteFolder: _deleteFolder,
                  onCreateType: _createNote,
                  onMoveNoteToFolder: _moveNoteToFolder,
                  onNewNote: _createNote,
                  onOpen: (note) => setState(() => _selectedNoteId = note.id),
                  onChanged: () => setState(() {}),
                )
              : _EditorPane(
                  note: selected,
                  state: state,
                  onBack: () => setState(() => _selectedNoteId = null),
                  onDelete: () => _deleteNote(selected),
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: _FolderPane(
                state: state,
                scope: _scope,
                folderId: _folderId,
                onScope: (scope) => setState(() {
                  _scope = scope;
                  _folderId = null;
                }),
                onFolder: (id) => setState(() {
                  _folderId = id;
                  _scope = _NoteScope.all;
                }),
                onNewFolder: _openFolderEditor,
                onEditFolder: _openFolderEditor,
                onDeleteFolder: _deleteFolder,
                onCreateType: _createNote,
                onMoveNoteToFolder: _moveNoteToFolder,
              ),
            ),
            SizedBox(
              width: medium ? 300 : 340,
              child: _NoteListOnly(
                state: state,
                notes: _visibleNotes(state),
                search: _search,
                selectedNoteId: _selectedNoteId,
                onNewNote: _createNote,
                onOpen: (note) => setState(() => _selectedNoteId = note.id),
                onChanged: () => setState(() {}),
              ),
            ),
            Expanded(
              child: selected == null
                  ? const Center(
                      child: StudyCard(
                        child: StudyEmptyState(
                          icon: Icons.edit_note_rounded,
                          message:
                              'Wähle eine Notiz aus oder erstelle eine neue.',
                        ),
                      ),
                    )
                  : _EditorPane(
                      note: selected,
                      state: state,
                      onDelete: () => _deleteNote(selected),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  NoteItem? _selectedNote(StudyBuddyState state) {
    if (_selectedNoteId == null) return null;
    return state.notes.where((note) => note.id == _selectedNoteId).firstOrNull;
  }

  List<NoteItem> _visibleNotes(StudyBuddyState state) {
    final query = _search.text.trim().toLowerCase();
    final notes = state.notes.where((note) {
      if (_folderId != null && note.folderId != _folderId) return false;
      if (!_inScope(note, _scope)) return false;
      if (query.isEmpty) return true;
      return [
        note.title,
        note.body,
        note.preview,
        ...note.tags,
      ].any((text) => text.toLowerCase().contains(query));
    }).toList();
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return (b.updatedAt ?? b.createdAt ?? DateTime(0)).compareTo(
        a.updatedAt ?? a.createdAt ?? DateTime(0),
      );
    });
    return notes;
  }

  bool _inScope(NoteItem note, _NoteScope scope) => switch (scope) {
    _NoteScope.all => true,
    _NoteScope.favorites => note.isFavorite,
    _NoteScope.recent => true,
    _NoteScope.quick => note.type == NoteType.quick,
    _NoteScope.checklist => note.type == NoteType.checklist,
    _NoteScope.long => note.type == NoteType.long,
    _NoteScope.uncategorized => note.folderId == null,
  };

  Future<void> _createNote(NoteType type) async {
    final now = DateTime.now();
    final note = NoteItem(
      id: now.microsecondsSinceEpoch.toString(),
      title: switch (type) {
        NoteType.quick => 'Neue Kurznotiz',
        NoteType.long => 'Neue Langnotiz',
        NoteType.checklist => 'Neue Checkliste',
      },
      body: type == NoteType.checklist ? '☐ ' : '',
      type: type,
      folderId: _folderId,
      pages: type == NoteType.long
          ? [
              NotePage(
                id: '${now.microsecondsSinceEpoch}-page',
                title: 'Seite 1',
                content: '',
                createdAt: now,
                updatedAt: now,
              ),
            ]
          : const [],
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(studyBuddyControllerProvider.notifier).saveNote(note);
    setState(() => _selectedNoteId = note.id);
  }

  Future<void> _deleteNote(NoteItem note) async {
    await ref.read(studyBuddyControllerProvider.notifier).deleteNote(note.id);
    if (!mounted) return;
    setState(() => _selectedNoteId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notiz gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () =>
              ref.read(studyBuddyControllerProvider.notifier).saveNote(note),
        ),
      ),
    );
  }

  Future<void> _moveNoteToFolder(String noteId, NoteFolder folder) async {
    final note = ref
        .read(studyBuddyControllerProvider)
        .notes
        .where((item) => item.id == noteId)
        .firstOrNull;
    if (note == null || note.folderId == folder.id) return;
    await ref
        .read(studyBuddyControllerProvider.notifier)
        .saveNote(
          note.copyWith(folderId: folder.id, updatedAt: DateTime.now()),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notiz nach „${folder.name}“ verschoben')),
    );
  }

  Future<void> _openFolderEditor([NoteFolder? folder]) async {
    final result = await showDialog<NoteFolder>(
      context: context,
      builder: (_) => _FolderEditor(folder: folder),
    );
    if (result == null || !mounted) return;
    final saved = await ref
        .read(studyBuddyControllerProvider.notifier)
        .saveNoteFolder(result);
    if (saved == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diese Ordnerstruktur wäre zyklisch.')),
      );
    }
  }

  Future<void> _deleteFolder(NoteFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${folder.name} löschen?'),
        content: const Text(
          'Enthaltene Notizen werden nicht gelöscht, sondern nach „Ohne Ordner“ verschoben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(studyBuddyControllerProvider.notifier)
        .deleteNoteFolder(folder.id);
    if (mounted && _folderId == folder.id) {
      setState(() => _folderId = null);
    }
  }
}

class _NotesListPane extends StatelessWidget {
  const _NotesListPane({
    required this.state,
    required this.notes,
    required this.search,
    required this.scope,
    required this.folderId,
    required this.onScope,
    required this.onFolder,
    required this.onNewFolder,
    required this.onEditFolder,
    required this.onDeleteFolder,
    required this.onCreateType,
    required this.onMoveNoteToFolder,
    required this.onNewNote,
    required this.onOpen,
    required this.onChanged,
  });

  final StudyBuddyState state;
  final List<NoteItem> notes;
  final TextEditingController search;
  final _NoteScope scope;
  final String? folderId;
  final ValueChanged<_NoteScope> onScope;
  final ValueChanged<String?> onFolder;
  final VoidCallback onNewFolder;
  final ValueChanged<NoteFolder> onEditFolder;
  final ValueChanged<NoteFolder> onDeleteFolder;
  final ValueChanged<NoteType> onCreateType;
  final void Function(String noteId, NoteFolder folder) onMoveNoteToFolder;
  final ValueChanged<NoteType> onNewNote;
  final ValueChanged<NoteItem> onOpen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Notizen',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          IconButton(
            tooltip: 'Neuer Ordner',
            onPressed: onNewFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _FolderPane(
        state: state,
        scope: scope,
        folderId: folderId,
        onScope: onScope,
        onFolder: onFolder,
        onNewFolder: onNewFolder,
        onEditFolder: onEditFolder,
        onDeleteFolder: onDeleteFolder,
        onCreateType: onCreateType,
        onMoveNoteToFolder: onMoveNoteToFolder,
        embedded: true,
      ),
      const SizedBox(height: 12),
      _NoteListOnly(
        state: state,
        notes: notes,
        search: search,
        onNewNote: onNewNote,
        onOpen: onOpen,
        onChanged: onChanged,
      ),
    ],
  );
}

class _FolderPane extends StatelessWidget {
  const _FolderPane({
    required this.state,
    required this.scope,
    required this.folderId,
    required this.onScope,
    required this.onFolder,
    required this.onNewFolder,
    required this.onEditFolder,
    required this.onDeleteFolder,
    required this.onCreateType,
    required this.onMoveNoteToFolder,
    this.embedded = false,
  });

  final StudyBuddyState state;
  final _NoteScope scope;
  final String? folderId;
  final ValueChanged<_NoteScope> onScope;
  final ValueChanged<String?> onFolder;
  final VoidCallback onNewFolder;
  final ValueChanged<NoteFolder> onEditFolder;
  final ValueChanged<NoteFolder> onDeleteFolder;
  final ValueChanged<NoteType> onCreateType;
  final void Function(String noteId, NoteFolder folder) onMoveNoteToFolder;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.fromLTRB(embedded ? 0 : 16, 18, embedded ? 0 : 8, 18),
      children: [
        if (!embedded)
          Text('Ordner', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final item in _NoteScope.values)
          _NavTile(
            label: _scopeLabel(item),
            icon: _scopeIcon(item),
            selected: folderId == null && scope == item,
            onTap: () => onScope(item),
            onDoubleTap: _noteTypeForScope(item) == null
                ? null
                : () => onCreateType(_noteTypeForScope(item)!),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ordner',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Neuer Ordner',
              onPressed: onNewFolder,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        for (final folder in state.noteFolders.where(
          (f) => f.parentFolderId == null,
        ))
          _FolderTreeTile(
            folder: folder,
            folders: state.noteFolders,
            depth: 0,
            selectedId: folderId,
            onFolder: onFolder,
            onEdit: onEditFolder,
            onDelete: onDeleteFolder,
            onMoveNoteToFolder: onMoveNoteToFolder,
          ),
      ],
    );
    if (embedded) return content;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: content,
    );
  }
}

class _FolderTreeTile extends StatelessWidget {
  const _FolderTreeTile({
    required this.folder,
    required this.folders,
    required this.depth,
    required this.selectedId,
    required this.onFolder,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveNoteToFolder,
  });

  final NoteFolder folder;
  final List<NoteFolder> folders;
  final int depth;
  final String? selectedId;
  final ValueChanged<String?> onFolder;
  final ValueChanged<NoteFolder> onEdit;
  final ValueChanged<NoteFolder> onDelete;
  final void Function(String noteId, NoteFolder folder) onMoveNoteToFolder;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: EdgeInsets.only(left: depth * 14),
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) =>
              onMoveNoteToFolder(details.data, folder),
          builder: (context, candidates, _) => _NavTile(
            label: folder.name,
            icon: Icons.folder_outlined,
            selected: selectedId == folder.id || candidates.isNotEmpty,
            onTap: () => onFolder(folder.id),
            trailing: PopupMenuButton<String>(
              tooltip: 'Ordneroptionen',
              onSelected: (value) {
                if (value == 'edit') onEdit(folder);
                if (value == 'delete') onDelete(folder);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                PopupMenuItem(value: 'delete', child: Text('Löschen')),
              ],
              child: const Icon(Icons.more_horiz_rounded, size: 18),
            ),
          ),
        ),
      ),
      for (final child in folders.where(
        (item) => item.parentFolderId == folder.id,
      ))
        _FolderTreeTile(
          folder: child,
          folders: folders,
          depth: depth + 1,
          selectedId: selectedId,
          onFolder: onFolder,
          onEdit: onEdit,
          onDelete: onDelete,
          onMoveNoteToFolder: onMoveNoteToFolder,
        ),
    ],
  );
}

class _NoteListOnly extends StatelessWidget {
  const _NoteListOnly({
    required this.state,
    required this.notes,
    required this.search,
    required this.onNewNote,
    required this.onOpen,
    required this.onChanged,
    this.selectedNoteId,
  });

  final StudyBuddyState state;
  final List<NoteItem> notes;
  final TextEditingController search;
  final ValueChanged<NoteType> onNewNote;
  final ValueChanged<NoteItem> onOpen;
  final VoidCallback onChanged;
  final String? selectedNoteId;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: search,
                decoration: const InputDecoration(
                  hintText: 'Suchen...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<NoteType>(
              tooltip: 'Neue Notiz',
              onSelected: onNewNote,
              itemBuilder: (context) => const [
                PopupMenuItem(value: NoteType.quick, child: Text('Kurznotiz')),
                PopupMenuItem(value: NoteType.long, child: Text('Langnotiz')),
                PopupMenuItem(
                  value: NoteType.checklist,
                  child: Text('Checkliste'),
                ),
              ],
              child: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (notes.isEmpty)
          const StudyCard(
            child: StudyEmptyState(
              icon: Icons.edit_note_rounded,
              message: 'Noch keine Notizen in dieser Ansicht.',
            ),
          )
        else
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NoteTile(
                note: note,
                state: state,
                selected: selectedNoteId == note.id,
                onTap: () => onOpen(note),
              ),
            ),
      ],
    ),
  );
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final NoteItem note;
  final StudyBuddyState state;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subject = note.subjectId == null
        ? null
        : state.subjects.where((item) => item.id == note.subjectId).firstOrNull;
    final tile = Material(
      color: selected ? AppColors.blush : AppColors.surface,
      borderRadius: StudyRadius.medium,
      child: InkWell(
        onTap: onTap,
        borderRadius: StudyRadius.medium,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Ohne Titel' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (note.isPinned)
                    const Icon(Icons.push_pin_outlined, size: 16),
                  if (note.isFavorite) const Icon(Icons.star_rounded, size: 16),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  StudyBadge(label: _noteTypeLabel(note.type)),
                  if (subject != null)
                    StudyBadge(label: subject.name, color: subject.color),
                ],
              ),
              if (note.preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.mutedInk),
                ),
              ],
              const SizedBox(height: 5),
              Text(
                note.updatedAt == null
                    ? 'Neu'
                    : DateFormat('dd.MM.yyyy HH:mm').format(note.updatedAt!),
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    return Draggable<String>(
      data: note.id,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 260,
          child: StudyCard(
            padding: const EdgeInsets.all(12),
            child: Text(
              note.title.isEmpty ? 'Ohne Titel' : note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: .42, child: tile),
      child: tile,
    );
  }
}

class _EditorPane extends ConsumerStatefulWidget {
  const _EditorPane({
    required this.note,
    required this.state,
    required this.onDelete,
    this.onBack,
  });

  final NoteItem note;
  final StudyBuddyState state;
  final VoidCallback onDelete;
  final VoidCallback? onBack;

  @override
  ConsumerState<_EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends ConsumerState<_EditorPane> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;
  final _pageControllers = <String, TextEditingController>{};
  final _undoStack = <String>[];
  final _redoStack = <String>[];
  String _lastSnapshot = '';
  bool _applyingListContinuation = false;
  Timer? _debounce;
  var _saveStatus = 'Gespeichert';
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note.title);
    _body = _FormattedNoteController(text: widget.note.body);
    _tags = TextEditingController(text: widget.note.tags.join(', '));
  }

  @override
  void didUpdateWidget(covariant _EditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _title.text = widget.note.title;
      _body.text = widget.note.body;
      _tags.text = widget.note.tags.join(', ');
      _pageIndex = 0;
      _undoStack.clear();
      _redoStack.clear();
      _lastSnapshot = '';
      for (final controller in _pageControllers.values) {
        controller.dispose();
      }
      _pageControllers.clear();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    for (final controller in _pageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final pages = note.type == NoteType.long
        ? (note.pages.isEmpty
              ? [
                  NotePage(
                    id: '${note.id}-page',
                    title: 'Seite 1',
                    content: '',
                    createdAt: DateTime.now(),
                  ),
                ]
              : note.pages)
        : const <NotePage>[];
    final page = pages.isEmpty
        ? null
        : pages[_pageIndex.clamp(0, pages.length - 1)];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  tooltip: 'Zurück',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: TextField(
                  controller: _title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    hintText: 'Titel',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => _scheduleSave(),
                ),
              ),
              Text(
                _saveStatus,
                style: const TextStyle(color: AppColors.mutedInk),
              ),
              IconButton(
                tooltip: note.isFavorite ? 'Favorit entfernen' : 'Favorit',
                onPressed: () => _saveNow(
                  note.copyWith(
                    isFavorite: !note.isFavorite,
                    updatedAt: DateTime.now(),
                  ),
                ),
                icon: Icon(
                  note.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                ),
              ),
              IconButton(
                tooltip: note.isPinned ? 'Lösen' : 'Anheften',
                onPressed: () => _saveNow(
                  note.copyWith(
                    isPinned: !note.isPinned,
                    updatedAt: DateTime.now(),
                  ),
                ),
                icon: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Löschen',
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
        _EditorToolbar(
          note: note,
          canFormatText: note.type != NoteType.checklist,
          onUndo: _undo,
          onRedo: _redo,
          onBold: () => _wrapSelection('**'),
          onItalic: () => _wrapSelection('_'),
          onBulletList: () => _prefixSelection('• '),
        ),
        Expanded(
          child: note.type == NoteType.quick
              ? _QuickEditor(
                  body: _body,
                  tags: _tags,
                  onBodyChanged: _onTextChanged,
                  onMetaChanged: _scheduleSave,
                )
              : note.type == NoteType.checklist
              ? _ChecklistEditor(
                  body: _body,
                  tags: _tags,
                  onBodyChanged: _onTextChanged,
                  onMetaChanged: _scheduleSave,
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 190,
                      child: _PagesPane(
                        pages: pages,
                        selectedIndex: _pageIndex,
                        onSelect: (index) => setState(() => _pageIndex = index),
                        onAdd: () => _addPage(pages),
                        onDuplicate: page == null
                            ? null
                            : () => _duplicatePage(page, pages),
                        onDelete: page == null
                            ? null
                            : () => _deletePage(page, pages),
                      ),
                    ),
                    Expanded(
                      child: page == null
                          ? const SizedBox.shrink()
                          : _DocumentPage(
                              page: page,
                              controller: _controllerFor(page),
                              onChanged: _onTextChanged,
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  TextEditingController _controllerFor(NotePage page) => _pageControllers
      .putIfAbsent(page.id, () => _FormattedNoteController(text: page.content));

  TextEditingController get _activeContentController {
    final note = widget.note;
    if (note.type == NoteType.quick) return _body;
    final pages = note.pages;
    if (pages.isEmpty) return _body;
    final page = pages[_pageIndex.clamp(0, pages.length - 1)];
    return _controllerFor(page);
  }

  void _onTextChanged() {
    if (!_applyingListContinuation && _continueListAfterEnter()) return;
    _removeEmptyInlineMarkers();
    final snapshot = _activeContentController.text;
    if (_lastSnapshot.isEmpty) {
      _lastSnapshot = snapshot;
    } else if (_undoStack.isEmpty || _undoStack.last != _lastSnapshot) {
      _undoStack.add(_lastSnapshot);
      if (_undoStack.length > 60) _undoStack.removeAt(0);
      _lastSnapshot = snapshot;
      _redoStack.clear();
    }
    _scheduleSave();
  }

  void _removeEmptyInlineMarkers() {
    final controller = _activeContentController;
    final original = controller.text;
    final cleaned = _cleanInlineMarkers(original);
    if (cleaned == original) return;
    final removed = original.length - cleaned.length;
    final offset = (controller.selection.baseOffset - removed).clamp(
      0,
      cleaned.length,
    );
    controller.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  bool _continueListAfterEnter() {
    final controller = _activeContentController;
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isCollapsed || selection.baseOffset <= 0) return false;
    final cursor = selection.baseOffset;
    if (value.text[cursor - 1] != '\n') return false;
    final previousLineEnd = cursor - 1;
    final searchFrom = previousLineEnd <= 0 ? 0 : previousLineEnd - 1;
    final previousLineStart = value.text.lastIndexOf('\n', searchFrom) + 1;
    final previousLine = value.text.substring(
      previousLineStart,
      previousLineEnd,
    );
    final prefix = previousLine.startsWith('• ')
        ? '• '
        : previousLine.startsWith('☐ ')
        ? '☐ '
        : null;
    if (prefix == null) return false;
    if (previousLine.trim() == prefix.trim()) {
      final text = value.text.replaceRange(previousLineStart, cursor, '');
      _applyingListContinuation = true;
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: previousLineStart),
      );
      _applyingListContinuation = false;
      _scheduleSave();
      return true;
    }
    final text = value.text.replaceRange(cursor, cursor, prefix);
    _applyingListContinuation = true;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
    _applyingListContinuation = false;
    _scheduleSave();
    return true;
  }

  void _scheduleSave() {
    _debounce?.cancel();
    setState(() => _saveStatus = 'Speichern...');
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _saveNow(_currentNote());
    });
  }

  Future<void> _saveNow(NoteItem note) async {
    await ref.read(studyBuddyControllerProvider.notifier).saveNote(note);
    if (mounted) setState(() => _saveStatus = 'Lokal gespeichert');
  }

  void _rememberEdit(TextEditingController controller) {
    _undoStack.add(controller.text);
    if (_undoStack.length > 60) _undoStack.removeAt(0);
    _redoStack.clear();
    _lastSnapshot = controller.text;
  }

  void _undo() {
    final controller = _activeContentController;
    if (_undoStack.isEmpty) return;
    _redoStack.add(controller.text);
    final previous = _undoStack.removeLast();
    controller.value = TextEditingValue(
      text: previous,
      selection: TextSelection.collapsed(offset: previous.length),
    );
    _lastSnapshot = previous;
    _scheduleSave();
  }

  void _redo() {
    final controller = _activeContentController;
    if (_redoStack.isEmpty) return;
    _undoStack.add(controller.text);
    final next = _redoStack.removeLast();
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _lastSnapshot = next;
    _scheduleSave();
  }

  void _wrapSelection(String marker) {
    final controller = _activeContentController;
    _rememberEdit(controller);
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final selected = value.text.substring(start, end);
    final replacement = '$marker$selected$marker';
    final text = value.text.replaceRange(start, end, replacement);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: start + marker.length,
        extentOffset: start + marker.length + selected.length,
      ),
    );
    _lastSnapshot = text;
    _scheduleSave();
  }

  void _prefixSelection(String prefix) {
    final controller = _activeContentController;
    _rememberEdit(controller);
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final searchFrom = start <= 0 ? 0 : start - 1;
    final lineStart = value.text.lastIndexOf('\n', searchFrom) + 1;
    final selected = value.text.substring(lineStart, end);
    final replacement = selected
        .split('\n')
        .map((line) => line.startsWith(prefix) ? line : '$prefix$line')
        .join('\n');
    final text = value.text.replaceRange(lineStart, end, replacement);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: lineStart + replacement.length,
      ),
    );
    _lastSnapshot = text;
    _scheduleSave();
  }

  NoteItem _currentNote() {
    final note = widget.note;
    final pages = [
      for (final page in note.pages)
        page.copyWith(
          content: _cleanInlineMarkers(
            _pageControllers[page.id]?.text ?? page.content,
          ),
          updatedAt: DateTime.now(),
        ),
    ];
    return note.copyWith(
      title: _title.text.trim(),
      body: _cleanInlineMarkers(_body.text),
      tags: _tags.text
          .split(',')
          .map((tag) => tag.trim().replaceFirst(RegExp(r'^#'), ''))
          .where((tag) => tag.isNotEmpty)
          .toList(),
      pages: pages,
      updatedAt: DateTime.now(),
    );
  }

  void _addPage(List<NotePage> pages) {
    final now = DateTime.now();
    final updated = _currentNote().copyWith(
      pages: [
        ...pages,
        NotePage(
          id: now.microsecondsSinceEpoch.toString(),
          title: 'Seite ${pages.length + 1}',
          content: '',
          sortOrder: pages.length,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      updatedAt: now,
    );
    _saveNow(updated);
    setState(() => _pageIndex = pages.length);
  }

  void _duplicatePage(NotePage page, List<NotePage> pages) {
    final now = DateTime.now();
    final updated = _currentNote().copyWith(
      pages: [
        ...pages,
        NotePage(
          id: now.microsecondsSinceEpoch.toString(),
          title: '${page.title} Kopie',
          content: _pageControllers[page.id]?.text ?? page.content,
          sortOrder: pages.length,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      updatedAt: now,
    );
    _saveNow(updated);
  }

  void _deletePage(NotePage page, List<NotePage> pages) {
    if (pages.length <= 1) return;
    final remaining = [
      for (final item in pages)
        if (item.id != page.id) item,
    ];
    _saveNow(
      _currentNote().copyWith(pages: remaining, updatedAt: DateTime.now()),
    );
    setState(() => _pageIndex = 0);
  }
}

class _FormattedNoteController extends TextEditingController {
  _FormattedNoteController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(style: style, children: _spans(text, style));
  }

  List<TextSpan> _spans(String value, TextStyle? baseStyle) {
    final spans = <TextSpan>[];
    var index = 0;
    final pattern = RegExp(r'(\*\*[^*]*\*\*|_[^_\n]*_)');
    for (final match in pattern.allMatches(value)) {
      if (match.start > index) {
        spans.add(TextSpan(text: value.substring(index, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: (baseStyle ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: (baseStyle ?? const TextStyle()).copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }
      index = match.end;
    }
    if (index < value.length) {
      spans.add(TextSpan(text: value.substring(index)));
    }
    return spans;
  }
}

String _cleanInlineMarkers(String value) {
  var result = value;
  String previous;
  do {
    previous = result;
    result = result
        .replaceAll('****', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'\*\*\s+\*\*'), '')
        .replaceAll(RegExp(r'_\s+_'), '');
  } while (result != previous);
  return result;
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.note,
    required this.canFormatText,
    required this.onUndo,
    required this.onRedo,
    required this.onBold,
    required this.onItalic,
    required this.onBulletList,
  });

  final NoteItem note;
  final bool canFormatText;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onBulletList;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: const BoxDecoration(
      border: Border.symmetric(horizontal: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        _ToolbarButton(
          icon: Icons.undo_rounded,
          tooltip: 'Undo',
          onTap: onUndo,
        ),
        _ToolbarButton(
          icon: Icons.redo_rounded,
          tooltip: 'Redo',
          onTap: onRedo,
        ),
        if (canFormatText) ...[
          const SizedBox(width: 10),
          const StudyBadge(label: 'Text'),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.format_bold_rounded,
            tooltip: 'Fett',
            onTap: onBold,
          ),
          _ToolbarButton(
            icon: Icons.format_italic_rounded,
            tooltip: 'Kursiv',
            onTap: onItalic,
          ),
          _ToolbarButton(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: 'Liste',
            onTap: onBulletList,
          ),
        ],
        const Spacer(),
        StudyBadge(label: _noteTypeLabel(note.type)),
      ],
    ),
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 18),
  );
}

class _QuickEditor extends StatelessWidget {
  const _QuickEditor({
    required this.body,
    required this.tags,
    required this.onBodyChanged,
    required this.onMetaChanged,
  });

  final TextEditingController body;
  final TextEditingController tags;
  final VoidCallback onBodyChanged;
  final VoidCallback onMetaChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      TextField(
        controller: body,
        maxLines: 12,
        minLines: 8,
        decoration: const InputDecoration(hintText: 'Schneller Gedanke...'),
        onChanged: (_) => onBodyChanged(),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: tags,
        decoration: const InputDecoration(
          labelText: 'Tags',
          hintText: 'prüfung, idee, wichtig',
        ),
        onChanged: (_) => onMetaChanged(),
      ),
    ],
  );
}

class _ChecklistEditor extends StatefulWidget {
  const _ChecklistEditor({
    required this.body,
    required this.tags,
    required this.onBodyChanged,
    required this.onMetaChanged,
  });

  final TextEditingController body;
  final TextEditingController tags;
  final VoidCallback onBodyChanged;
  final VoidCallback onMetaChanged;

  @override
  State<_ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<_ChecklistEditor> {
  final _focusNodes = <int, FocusNode>{};
  int? _pendingFocusIndex;

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  List<_ChecklistLine> get _items {
    final raw = widget.body.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (raw.isEmpty) return const [_ChecklistLine(false, '')];
    return [
      for (final line in raw)
        _ChecklistLine(
          line.trimLeft().startsWith('☑'),
          line.replaceFirst(RegExp(r'^\s*[☐☑]\s*'), ''),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    _trimFocusNodes(items.length);
    _focusPendingRow();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        StudyCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _ChecklistRow(
                  key: ValueKey('check-$i'),
                  item: items[i],
                  focusNode: _focusNodes.putIfAbsent(i, FocusNode.new),
                  onToggle: () =>
                      _update(i, _ChecklistLine(!items[i].done, items[i].text)),
                  onChanged: (text) => _update(
                    i,
                    _ChecklistLine(items[i].done, text),
                    rebuild: false,
                  ),
                  onSubmitted: () => _insertAfter(i),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _insertAfter(items.length - 1),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Punkt hinzufügen'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: widget.tags,
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'einkauf, material, erledigen',
          ),
          onChanged: (_) => widget.onMetaChanged(),
        ),
      ],
    );
  }

  void _insertAfter(int index) {
    final items = [..._items];
    final insertAt = (index + 1).clamp(0, items.length);
    items.insert(insertAt, const _ChecklistLine(false, ''));
    _pendingFocusIndex = insertAt;
    _write(items);
  }

  void _update(int index, _ChecklistLine item, {bool rebuild = true}) {
    final items = [..._items];
    items[index] = item;
    _write(items, rebuild: rebuild);
  }

  void _write(List<_ChecklistLine> items, {bool rebuild = true}) {
    widget.body.text = items
        .map((item) => '${item.done ? '☑' : '☐'} ${item.text}')
        .join('\n');
    widget.body.selection = TextSelection.collapsed(
      offset: widget.body.text.length,
    );
    if (rebuild) setState(() {});
    widget.onBodyChanged();
  }

  void _focusPendingRow() {
    final index = _pendingFocusIndex;
    if (index == null) return;
    _pendingFocusIndex = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNodes[index]?.requestFocus();
    });
  }

  void _trimFocusNodes(int length) {
    final stale = _focusNodes.keys.where((index) => index >= length).toList();
    for (final index in stale) {
      _focusNodes.remove(index)?.dispose();
    }
  }
}

class _ChecklistLine {
  const _ChecklistLine(this.done, this.text);
  final bool done;
  final String text;
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.focusNode,
    required this.onToggle,
    required this.onChanged,
    required this.onSubmitted,
    super.key,
  });

  final _ChecklistLine item;
  final FocusNode focusNode;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        IconButton(
          tooltip: item.done ? 'Als offen markieren' : 'Erledigen',
          onPressed: onToggle,
          icon: Icon(
            item.done ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: item.done ? AppColors.sage : AppColors.mutedInk,
          ),
        ),
        Expanded(
          child: TextFormField(
            focusNode: focusNode,
            initialValue: item.text,
            decoration: const InputDecoration(
              hintText: 'Checklist-Punkt',
              border: InputBorder.none,
            ),
            textInputAction: TextInputAction.next,
            style: TextStyle(
              decoration: item.done ? TextDecoration.lineThrough : null,
              color: item.done ? AppColors.mutedInk : AppColors.ink,
            ),
            onChanged: onChanged,
            onFieldSubmitted: (_) => onSubmitted(),
          ),
        ),
      ],
    ),
  );
}

class _PagesPane extends StatelessWidget {
  const _PagesPane({
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
    this.onDuplicate,
    this.onDelete,
  });

  final List<NotePage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Seiten',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Seite hinzufügen',
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        for (var i = 0; i < pages.length; i++)
          _NavTile(
            label: pages[i].title.isEmpty ? 'Seite ${i + 1}' : pages[i].title,
            icon: Icons.description_outlined,
            selected: selectedIndex == i,
            onTap: () => onSelect(i),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onDuplicate,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Duplizieren'),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Löschen'),
        ),
      ],
    ),
  );
}

class _DocumentPage extends StatelessWidget {
  const _DocumentPage({
    required this.page,
    required this.controller,
    required this.onChanged,
  });

  final NotePage page;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.background,
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 34),
      children: [
        Center(
          child: Container(
            width: 720,
            constraints: const BoxConstraints(minHeight: 920),
            padding: const EdgeInsets.all(46),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: StudyRadius.medium,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              minLines: 28,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: page.title.isEmpty ? 'Schreiben...' : page.title,
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 16, height: 1.55),
              onChanged: (_) => onChanged(),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FolderEditor extends ConsumerStatefulWidget {
  const _FolderEditor({this.folder});
  final NoteFolder? folder;

  @override
  ConsumerState<_FolderEditor> createState() => _FolderEditorState();
}

class _FolderEditorState extends ConsumerState<_FolderEditor> {
  final _name = TextEditingController();
  String? _parentId;
  String? _subjectId;

  @override
  void initState() {
    super.initState();
    final folder = widget.folder;
    if (folder != null) {
      _name.text = folder.name;
      _parentId = folder.parentFolderId;
      _subjectId = folder.subjectId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBuddyControllerProvider);
    return AlertDialog(
      title: Text(widget.folder == null ? 'Neuer Ordner' : 'Ordner bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _parentId,
            decoration: const InputDecoration(labelText: 'Überordner'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Kein Überordner'),
              ),
              for (final folder in state.noteFolders)
                if (folder.id != widget.folder?.id)
                  DropdownMenuItem(value: folder.id, child: Text(folder.name)),
            ],
            onChanged: (value) => setState(() => _parentId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _subjectId,
            decoration: const InputDecoration(labelText: 'Fach'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Kein Fach')),
              for (final subject in state.subjects)
                DropdownMenuItem(value: subject.id, child: Text(subject.name)),
            ],
            onChanged: (value) => setState(() => _subjectId = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final now = DateTime.now();
            final old = widget.folder;
            Navigator.pop(
              context,
              (old ??
                      NoteFolder(
                        id: now.microsecondsSinceEpoch.toString(),
                        name: '',
                        createdAt: now,
                      ))
                  .copyWith(
                    name: _name.text.trim().isEmpty
                        ? 'Neuer Ordner'
                        : _name.text.trim(),
                    parentFolderId: _parentId,
                    subjectId: _subjectId,
                    updatedAt: now,
                  ),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.onDoubleTap,
    this.trailing,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Material(
        color: selected ? AppColors.blush : AppColors.surface,
        borderRadius: StudyRadius.medium,
        child: ListTile(
          dense: true,
          leading: Icon(icon, size: 18),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    ),
  );
}

String _scopeLabel(_NoteScope scope) => switch (scope) {
  _NoteScope.all => 'Alle Notizen',
  _NoteScope.favorites => 'Favoriten',
  _NoteScope.recent => 'Zuletzt',
  _NoteScope.quick => 'Kurznotizen',
  _NoteScope.checklist => 'Checklisten',
  _NoteScope.long => 'Langnotizen',
  _NoteScope.uncategorized => 'Ohne Ordner',
};

String _noteTypeLabel(NoteType type) => switch (type) {
  NoteType.quick => 'Kurznotiz',
  NoteType.long => 'Langnotiz',
  NoteType.checklist => 'Checkliste',
};

NoteType? _noteTypeForScope(_NoteScope scope) => switch (scope) {
  _NoteScope.quick => NoteType.quick,
  _NoteScope.checklist => NoteType.checklist,
  _NoteScope.long => NoteType.long,
  _ => null,
};

IconData _scopeIcon(_NoteScope scope) => switch (scope) {
  _NoteScope.all => Icons.notes_rounded,
  _NoteScope.favorites => Icons.star_border_rounded,
  _NoteScope.recent => Icons.history_rounded,
  _NoteScope.quick => Icons.sticky_note_2_outlined,
  _NoteScope.checklist => Icons.checklist_rounded,
  _NoteScope.long => Icons.article_outlined,
  _NoteScope.uncategorized => Icons.folder_off_outlined,
};
