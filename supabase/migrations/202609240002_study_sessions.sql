alter table public.study_items drop constraint if exists study_items_kind_check;
alter table public.study_items add constraint study_items_kind_check
  check (kind in (
    'schedule',
    'task',
    'note',
    'note_folder',
    'subject',
    'exam',
    'reminder',
    'calendar_category',
    'study_session'
  ));
