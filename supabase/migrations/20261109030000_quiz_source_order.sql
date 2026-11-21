-- Add immutable source order for deterministic quiz choice reconstruction.
-- Existing rows remain NULL until the trusted content importer supplies canonical order.
begin;

alter table public.vocabulary
  add column source_ordinal integer,
  add constraint vocabulary_source_ordinal_nonnegative
    check (source_ordinal is null or source_ordinal >= 0),
  add constraint vocabulary_active_requires_source_ordinal
    check (not is_active or source_ordinal is not null) not valid;

create unique index vocabulary_level_source_ordinal_uq
  on public.vocabulary(jlpt_level, source_ordinal)
  where source_ordinal is not null;

alter table public.grammar
  add column source_ordinal integer,
  add constraint grammar_source_ordinal_nonnegative
    check (source_ordinal is null or source_ordinal >= 0),
  add constraint grammar_active_requires_source_ordinal
    check (not is_active or source_ordinal is not null) not valid;

create unique index grammar_level_source_ordinal_uq
  on public.grammar(jlpt_level, source_ordinal)
  where source_ordinal is not null;

comment on column public.vocabulary.source_ordinal is
  'Canonical zero-based order within the original vocabulary export for this JLPT level; never derive from UUID order.';
comment on column public.grammar.source_ordinal is
  'Canonical zero-based order within the original grammar export for this JLPT level; never derive from UUID order.';

commit;
