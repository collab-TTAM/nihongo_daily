import { BoundaryError } from "./contracts.ts";
import type { PostgresResult } from "./postgres_connection.ts";
import type { QuizReportRequest } from "./quiz_report.ts";

export type QuizReportContentQuery = (
  sql: string,
  values?: string[],
) => Promise<PostgresResult>;

const vocabularySql =
  "SELECT id::text AS id, content_version, expression AS heading, reading " +
  "FROM public.vocabulary WHERE jlpt_level = $1::public.jlpt_level " +
  "AND is_active = true ORDER BY id LIMIT 5001";
const grammarSql =
  "SELECT id::text AS id, content_version, title AS heading, meaning_vi " +
  "FROM public.grammar WHERE jlpt_level = $1::public.jlpt_level " +
  "AND is_active = true ORDER BY id LIMIT 5001";

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const kanji = /[\u3400-\u9fff]/;
const maxContentItems = 5000;
const internal = () => new BoundaryError("INTERNAL_ERROR");
const invalid = () => new BoundaryError("VALIDATION_FAILURE");
const unavailable = () => new BoundaryError("NETWORK_UNAVAILABLE");

interface ContentRow {
  readonly id: string;
  readonly contentVersion: number;
  readonly heading: string;
  readonly secondary: string;
}

function readRows(
  result: PostgresResult,
  secondaryField: "reading" | "meaning_vi",
): ContentRow[] {
  const expected = ["content_version", "heading", "id", secondaryField]
    .sort()
    .join("\u0000");
  if (
    result.command !== "SELECT" ||
    result.rowCount !== result.rows.length ||
    result.rows.length > maxContentItems
  ) {
    throw internal();
  }
  const ids = new Set<string>();
  return result.rows.map((row) => {
    if (Object.keys(row).sort().join("\u0000") !== expected) {
      throw internal();
    }
    const id = row.id;
    const version = row.content_version;
    const heading = row.heading;
    const secondary = row[secondaryField];
    const maxHeading = secondaryField === "reading" ? 128 : 256;
    const maxSecondary = secondaryField === "reading" ? 128 : 2048;
    if (
      typeof id !== "string" ||
      !uuid.test(id) ||
      id !== id.toLowerCase() ||
      ids.has(id) ||
      typeof version !== "number" ||
      !Number.isSafeInteger(version) ||
      version < 1 ||
      version > 2147483647 ||
      typeof heading !== "string" ||
      heading.trim().length === 0 ||
      heading.length > maxHeading ||
      typeof secondary !== "string" ||
      secondary.trim().length === 0 ||
      secondary.length > maxSecondary
    ) {
      throw internal();
    }
    ids.add(id);
    return {
      id,
      contentVersion: version,
      heading,
      secondary,
    };
  });
}

function counts(
  rows: readonly ContentRow[],
  select: (row: ContentRow) => string,
) {
  const result = new Map<string, number>();
  for (const row of rows) {
    const value = select(row).trim();
    result.set(value, (result.get(value) ?? 0) + 1);
  }
  return result;
}

function eligibleIds(
  rows: readonly ContentRow[],
  secondaryField: "reading" | "meaning_vi",
): Set<string> {
  const headingCounts = counts(rows, (row) => row.heading);
  const headingEligible = rows.filter(
    (row) =>
      headingCounts.get(row.heading.trim()) === 1 &&
      (secondaryField !== "reading" || kanji.test(row.heading)),
  );
  const secondaryCounts = counts(headingEligible, (row) => row.secondary);
  // The source quiz keeps the first duplicate label. Without a persisted source
  // ordinal the server cannot identify that first row, so ambiguous labels are
  // conservatively excluded instead of guessing which item the learner saw.
  return new Set(
    headingEligible
      .filter((row) => secondaryCounts.get(row.secondary.trim()) === 1)
      .map((row) => row.id),
  );
}

/**
 * Validates that every reported target and displayed choice is still an active,
 * eligible item in the same canonical level and that the target version is
 * current. This is a membership/eligibility boundary, not proof of the exact
 * source order or distractor slot: the curriculum tables have no source ordinal.
 */
export async function validateCurrentQuizReportContent(
  query: QuizReportContentQuery,
  request: QuizReportRequest,
  signal: AbortSignal,
): Promise<void> {
  if (signal.aborted) throw unavailable();
  const vocabulary = request.quiz_type === "vocabulary_reading";
  const sql = vocabulary ? vocabularySql : grammarSql;
  const secondaryField = vocabulary ? "reading" : "meaning_vi";
  let result: PostgresResult;
  try {
    result = await query(sql, [request.jlpt_level]);
  } catch {
    throw signal.aborted ? unavailable() : internal();
  }
  if (signal.aborted) throw unavailable();
  const rows = readRows(result, secondaryField);
  const byId = new Map(rows.map((row) => [row.id, row]));
  const eligible = eligibleIds(rows, secondaryField);
  const seenTargets = new Set<string>();
  for (const answer of request.answers) {
    if (
      seenTargets.has(answer.item_id) ||
      answer.choices.length !== 4 ||
      new Set(answer.choices).size !== 4 ||
      !answer.choices.includes(answer.item_id) ||
      !answer.choices.includes(answer.selected_id)
    ) {
      throw invalid();
    }
    seenTargets.add(answer.item_id);
    const target = byId.get(answer.item_id);
    if (
      !target ||
      target.contentVersion !== answer.content_version ||
      !eligible.has(target.id)
    ) {
      throw invalid();
    }
    const labels = new Set<string>();
    for (const choiceId of answer.choices) {
      const choice = byId.get(choiceId);
      if (!choice || !eligible.has(choiceId)) throw invalid();
      const label = choice.secondary.trim();
      if (labels.has(label)) throw invalid();
      labels.add(label);
    }
  }
}
