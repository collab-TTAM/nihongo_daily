-- TEST ONLY: additive source-order constraints; no hosted/learner identity proof.
begin;

create schema quiz_source_order_test;
create function quiz_source_order_test.ok(value boolean, label text)
returns void language plpgsql as $$
begin
  if value is distinct from true then
    raise exception 'FAIL quiz source order: %', label;
  end if;
  raise notice 'PASS quiz source order: %', label;
end $$;

create function quiz_source_order_test.fails(statement text, expected_state text)
returns boolean language plpgsql as $$
begin
  execute statement;
  return false;
exception when others then
  return SQLSTATE = expected_state;
end $$;

select quiz_source_order_test.ok(
  (select count(*) = 2
   from information_schema.columns
   where table_schema = 'public'
     and table_name in ('vocabulary', 'grammar')
     and column_name = 'source_ordinal'
     and data_type = 'integer'),
  'source ordinal integer columns exist'
);

select quiz_source_order_test.ok(
  to_regclass('public.vocabulary_level_source_ordinal_uq') is not null
  and to_regclass('public.grammar_level_source_ordinal_uq') is not null,
  'source ordinal unique indexes exist'
);

insert into public.vocabulary (
  id, jlpt_level, difficulty, content_version, is_active,
  expression, reading, meaning_vi, part_of_speech, usage_context_vi
) values (
  'a4000000-0000-4000-8000-000000000006', 'N5', 0.5, 1, false,
  '旧項目', 'きゅうこうもく', 'Mục cũ', 'noun', 'Nội dung chưa kích hoạt'
);

select quiz_source_order_test.ok(
  (select source_ordinal is null and not is_active
   from public.vocabulary
   where id = 'a4000000-0000-4000-8000-000000000006'),
  'inactive legacy rows may remain without source ordinal'
);

insert into public.vocabulary (
  id, jlpt_level, difficulty, content_version, is_active,
  expression, reading, meaning_vi, part_of_speech, usage_context_vi, source_ordinal
) values (
  'a4000000-0000-4000-8000-000000000001', 'N5', 0.5, 1, true,
  '日本語', 'にほんご', 'Tiếng Nhật', 'noun', 'Học tiếng Nhật', 2147483647
);

select quiz_source_order_test.ok(
  quiz_source_order_test.fails(
    $sql$insert into public.vocabulary (
      id, jlpt_level, difficulty, content_version, is_active,
      expression, reading, meaning_vi, part_of_speech, usage_context_vi, source_ordinal
    ) values (
      'a4000000-0000-4000-8000-000000000002', 'N5', 0.5, 1, true,
      '漢字', 'かんじ', 'Hán tự', 'noun', 'Học Hán tự', 2147483647
    )$sql$,
    '23505'
  ),
  'vocabulary source ordinal is unique per level'
);

insert into public.vocabulary (
  id, jlpt_level, difficulty, content_version, is_active,
  expression, reading, meaning_vi, part_of_speech, usage_context_vi, source_ordinal
) values (
  'a4000000-0000-4000-8000-000000000003', 'N4', 0.5, 1, true,
  '漢字', 'かんじ', 'Hán tự', 'noun', 'Học Hán tự', 2147483647
);

select quiz_source_order_test.ok(
  quiz_source_order_test.fails(
    $sql$insert into public.vocabulary (
      id, jlpt_level, difficulty, content_version, is_active,
      expression, reading, meaning_vi, part_of_speech, usage_context_vi, source_ordinal
    ) values (
      'a4000000-0000-4000-8000-000000000004', 'N5', 0.5, 1, true,
      '順番', 'じゅんばん', 'Thứ tự', 'noun', 'Theo thứ tự', -1
    )$sql$,
    '23514'
  ),
  'vocabulary source ordinal is nonnegative'
);

select quiz_source_order_test.ok(
  quiz_source_order_test.fails(
    $sql$insert into public.vocabulary (
      id, jlpt_level, difficulty, content_version, is_active,
      expression, reading, meaning_vi, part_of_speech, usage_context_vi
    ) values (
      'a4000000-0000-4000-8000-000000000005', 'N5', 0.5, 1, true,
      '順番', 'じゅんばん', 'Thứ tự', 'noun', 'Theo thứ tự'
    )$sql$,
    '23514'
  ),
  'new active vocabulary requires source ordinal'
);

create table quiz_source_order_test.grammar_ordinal_baseline as
select coalesce(max(source_ordinal), -1) as max_ordinal
from public.grammar
where jlpt_level = 'N5';

insert into public.grammar (
  id, jlpt_level, difficulty, content_version, is_active,
  title, pattern, meaning_vi, explanation_vi, source_ordinal
) values (
  'a4100000-0000-4000-8000-000000000001', 'N5', 0.5, 1, true,
  '理由', 'Nので', 'Vì', 'Dùng để nêu lý do.',
  (select max_ordinal + 1
   from quiz_source_order_test.grammar_ordinal_baseline)
);

select quiz_source_order_test.ok(
  (select g.source_ordinal = b.max_ordinal + 1
   from public.grammar g
   cross join quiz_source_order_test.grammar_ordinal_baseline b
   where g.id = 'a4100000-0000-4000-8000-000000000001'),
  'grammar fixture allocates the next available source ordinal'
);

select quiz_source_order_test.ok(
  quiz_source_order_test.fails(
    $sql$insert into public.grammar (
      id, jlpt_level, difficulty, content_version, is_active,
      title, pattern, meaning_vi, explanation_vi, source_ordinal
    ) values (
      'a4100000-0000-4000-8000-000000000002', 'N5', 0.5, 1, true,
      '原因', 'Nから', 'Vì', 'Dùng để nêu lý do.',
      (select max_ordinal + 1
       from quiz_source_order_test.grammar_ordinal_baseline)
    )$sql$,
    '23505'
  ),
  'grammar source ordinal is unique per level'
);

select quiz_source_order_test.ok(
  quiz_source_order_test.fails(
    $sql$insert into public.grammar (
      id, jlpt_level, difficulty, content_version, is_active,
      title, pattern, meaning_vi, explanation_vi, source_ordinal
    ) values (
      'a4100000-0000-4000-8000-000000000003', 'N5', 0.5, 1, true,
      '順番', 'Nに沿って', 'Theo', 'Dùng để chỉ thứ tự.', -1
    )$sql$,
    '23514'
  ),
  'grammar source ordinal is nonnegative'
);

select quiz_source_order_test.ok(
  quiz_source_order_test.fails(
    $sql$insert into public.grammar (
      id, jlpt_level, difficulty, content_version, is_active,
      title, pattern, meaning_vi, explanation_vi
    ) values (
      'a4100000-0000-4000-8000-000000000004', 'N5', 0.5, 1, true,
      '順番', 'Nに沿って', 'Theo', 'Dùng để chỉ thứ tự.'
    )$sql$,
    '23514'
  ),
  'new active grammar requires source ordinal'
);

rollback;
