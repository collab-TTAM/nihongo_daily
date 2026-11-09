import { BoundaryError } from "./contracts.ts";
import type { PostgresResult } from "./postgres_connection.ts";

export interface QuizReportV2Answer {
  readonly item_id: string;
  readonly content_version: number;
  readonly selected_id: string;
  readonly choices: readonly string[];
  readonly choice_content_versions: readonly number[];
}

export interface QuizReportV2Request {
  readonly client_event_id: string;
  readonly quiz_type: "vocabulary_reading" | "grammar_meaning";
  readonly practice_kind: null | "primary" | "correction";
  readonly jlpt_level: "N5" | "N4";
  readonly completed_at: string;
  readonly answers: readonly QuizReportV2Answer[];
}

export type QuizReportContentV2Query = (
  sql: string,
  values?: string[],
) => Promise<PostgresResult>;

interface ContentRow {
  readonly id: string;
  readonly sourceOrdinal: number;
  readonly contentVersion: number;
  readonly heading: string;
  readonly secondary: string;
}

const vocabularySql =
  "SELECT id::text AS id, source_ordinal, content_version, " +
  "expression AS heading, reading FROM public.vocabulary " +
  "WHERE jlpt_level = $1::public.jlpt_level AND is_active = true " +
  "ORDER BY source_ordinal ASC NULLS LAST, id LIMIT 5001";
const grammarSql =
  "SELECT id::text AS id, source_ordinal, content_version, " +
  "title AS heading, meaning_vi FROM public.grammar " +
  "WHERE jlpt_level = $1::public.jlpt_level AND is_active = true " +
  "ORDER BY source_ordinal ASC NULLS LAST, id LIMIT 5001";

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const kanji = /[\u3400-\u9fff]/;
const maxContentItems = 5000;
const internal = () => new BoundaryError("INTERNAL_ERROR");
const invalid = () => new BoundaryError("VALIDATION_FAILURE");
const unavailable = () => new BoundaryError("NETWORK_UNAVAILABLE");

function readRows(
  result: PostgresResult,
  secondaryField: "reading" | "meaning_vi",
): ContentRow[] {
  const expected = [
    "content_version",
    "heading",
    "id",
    "source_ordinal",
    secondaryField,
  ]
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
  const ordinals = new Set<number>();
  let previousOrdinal = -1;
  return result.rows.map((row) => {
    if (Object.keys(row).sort().join("\u0000") !== expected) {
      throw internal();
    }
    const id = row.id;
    const ordinal = row.source_ordinal;
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
      typeof ordinal !== "number" ||
      !Number.isSafeInteger(ordinal) ||
      ordinal < 0 ||
      ordinal > 2147483647 ||
      ordinals.has(ordinal) ||
      ordinal <= previousOrdinal ||
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
    ordinals.add(ordinal);
    previousOrdinal = ordinal;
    return {
      id,
      sourceOrdinal: ordinal,
      contentVersion: version,
      heading,
      secondary,
    };
  });
}

function countHeadings(rows: readonly ContentRow[]): Map<string, number> {
  const result = new Map<string, number>();
  for (const row of rows) {
    const heading = row.heading.trim();
    result.set(heading, (result.get(heading) ?? 0) + 1);
  }
  return result;
}

/**
 * Reconstructs the same first-occurrence pool and target slot as the Dart quiz
 * builders. Source order is trusted database metadata, never learner input.
 */
function canonicalChoices(
  rows: readonly ContentRow[],
  targetIndex: number,
): ContentRow[] {
  const target = rows[targetIndex];
  if (!target) throw invalid();
  const labels = new Map<string, ContentRow>();
  for (const row of rows) {
    const label = row.secondary.trim();
    if (!labels.has(label)) labels.set(label, row);
  }
  const pool = [...labels.values()];
  const choices: ContentRow[] = [];
  for (let step = 0; step < pool.length && choices.length < 3; step++) {
    const candidate = pool[(targetIndex + step) % pool.length]!;
    if (candidate.secondary.trim() !== target.secondary.trim()) {
      choices.push(candidate);
    }
  }
  if (choices.length !== 3) throw invalid();
  choices.splice(targetIndex % 4, 0, target);
  return choices;
}

/**
 * Validates exact current-source choice order and all displayed versions.
 * Must run only after replay miss inside the same verified-owner transaction.
 * This module is not a route, RPC, or default app save implementation.
 */
export async function validateCurrentQuizReportContentV2(
  query: QuizReportContentV2Query,
  request: QuizReportV2Request,
  signal: AbortSignal,
): Promise<void> {
  if (signal.aborted) throw unavailable();
  if (
    !request ||
    !Array.isArray(request.answers) ||
    request.answers.length < 1 ||
    request.answers.length > 10 ||
    (request.quiz_type !== "vocabulary_reading" &&
      request.quiz_type !== "grammar_meaning") ||
    (request.jlpt_level !== "N5" && request.jlpt_level !== "N4")
  ) {
    throw invalid();
  }
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
  const headingCounts = countHeadings(rows);
  const eligible = rows.filter(
    (row) =>
      headingCounts.get(row.heading.trim()) === 1 &&
      (!vocabulary || kanji.test(row.heading)),
  );
  const byId = new Map(rows.map((row) => [row.id, row]));
  const seenTargets = new Set<string>();

  for (const answer of request.answers) {
    if (
      !answer ||
      seenTargets.has(answer.item_id) ||
      !Number.isSafeInteger(answer.content_version) ||
      answer.content_version < 1 ||
      answer.content_version > 2147483647 ||
      !Array.isArray(answer.choices) ||
      answer.choices.length !== 4 ||
      new Set(answer.choices).size !== 4 ||
      !Array.isArray(answer.choice_content_versions) ||
      answer.choice_content_versions.length !== 4 ||
      !answer.choices.includes(answer.item_id) ||
      !answer.choices.includes(answer.selected_id)
    ) {
      throw invalid();
    }
    seenTargets.add(answer.item_id);
    const targetIndex = eligible.findIndex((row) => row.id === answer.item_id);
    const target = eligible[targetIndex];
    if (
      !target ||
      target.contentVersion !== answer.content_version
    ) {
      throw invalid();
    }
    const expectedChoices = canonicalChoices(eligible, targetIndex);
    if (
      expectedChoices.some(
        (choice, index) => answer.choices[index] !== choice.id,
      )
    ) {
      throw invalid();
    }
    for (let index = 0; index < expectedChoices.length; index++) {
      const choice = byId.get(expectedChoices[index]!.id);
      const capturedVersion = answer.choice_content_versions[index];
      if (
        !choice ||
        !Number.isSafeInteger(capturedVersion) ||
        capturedVersion < 1 ||
        capturedVersion > 2147483647 ||
        capturedVersion !== choice.contentVersion
      ) {
        throw invalid();
      }
    }
  }
}
