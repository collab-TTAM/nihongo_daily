-- Additive owner-scoped keyset index for immutable nd-quiz-report-2 history pages.
-- Matches WHERE user_id = auth.uid(), the descending cursor tuple and page order.
begin;
create index quiz_report_receipts_history_page_idx
  on private.quiz_report_receipts
  (user_id, received_at desc, client_event_id desc);
comment on index private.quiz_report_receipts_history_page_idx is
  'Supports owner-bound nd-quiz-report-2 descending keyset history pages.';
commit;
