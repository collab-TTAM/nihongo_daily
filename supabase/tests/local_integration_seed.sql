-- TEST ONLY: one deterministic active item for disposable local Supabase CI.
-- This file is applied only by scripts/test_supabase_local.py after a local reset.
begin;
insert into public.vocabulary (
  id, jlpt_level, difficulty, content_version, is_active,
  expression, reading, meaning_vi, part_of_speech, usage_context_vi, tags
) values (
  '00000000-0000-4000-8000-000000000001',
  'N5', 0.25, 1, true,
  'テスト', 'てすと', 'kiểm thử', 'noun',
  'Bản ghi tổng hợp chỉ dùng trong kiểm thử Supabase cục bộ.',
  array['test-only']
);
commit;
