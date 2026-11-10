// TEST ONLY native PostgreSQL transaction/owner proof with synthetic Auth identities.
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { Client } from "pg";
import { BoundaryError } from "../src/contracts.ts";
import type { AuthVerifier } from "../src/ports.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";
import {
  submitVerifiedQuizReportV2,
  type QuizReportV2CurrentContentValidator,
} from "../src/quiz_report_v2_host.ts";
import {
  validateCurrentQuizReportContentV2,
  type QuizReportContentV2Query,
} from "../src/quiz_report_content_v2.ts";
import type {
  QuizReportV2Request,
  QuizReportV2Response,
} from "../src/quiz_report_v2.ts";

const databaseUrl = process.env.TEST_DATABASE_URL;
if (
  databaseUrl !== "postgresql://postgres:postgres@localhost:5432/nihongo_test"
) {
  throw new Error(
    "Native v2 quiz host requires the fixed disposable CI database",
  );
}
const root = new URL("../../../contracts/quiz/v2/", import.meta.url);
const schema = JSON.parse(readFileSync(new URL("schema.json", root), "utf8"));
const fixtures = JSON.parse(
  readFileSync(new URL("fixtures.json", root), "utf8"),
) as Array<{
  request: QuizReportV2Request;
  response: QuizReportV2Response;
}>;

type MutableAnswer = {
  item_id: string;
  content_version: number;
  selected_id: string;
  choices: string[];
  choice_content_versions: number[];
};
type MutableRequest = Omit<QuizReportV2Request, "answers"> & {
  answers: MutableAnswer[];
};
type SourceRow = {
  id: string;
  source_ordinal: number;
  content_version: number;
  heading: string;
  secondary: string;
};

function client() {
  const connection = new Client({
    connectionString: databaseUrl,
    ssl: false,
    application_name: "nd-quiz-report-v2-native",
    connectionTimeoutMillis: 2000,
    query_timeout: 3000,
    pipeline: false,
  });
  connection.on("error", () => {});
  return connection;
}

function nativeConnectionFactory(): PostgresConnection {
  const owned = client();
  return {
    connect: async () => {
      await owned.connect();
    },
    query: async (text, values) => {
      const result = await owned.query(text, values);
      return {
        command: result.command,
        rowCount: result.rowCount,
        rows: result.rows as Record<string, unknown>[],
      };
    },
    close: () => {
      void owned.end().catch(() => {});
    },
  };
}

function tableFor(request: QuizReportV2Request): string {
  return request.quiz_type === "vocabulary_reading"
    ? "public.vocabulary"
    : "public.grammar";
}

async function seedAndCanonicalize(
  connection: Client,
  fixture: (typeof fixtures)[number],
): Promise<MutableRequest> {
  const mutable = structuredClone(fixture.request) as MutableRequest;
  const originalIds = [
    ...new Set(mutable.answers.flatMap((answer) => answer.choices)),
  ];
  const replacements = new Map(
    originalIds.map((id) => [id, randomUUID()] as const),
  );
  const originallyCorrect =
    mutable.answers[0]!.selected_id === mutable.answers[0]!.item_id;
  const request: MutableRequest = {
    ...mutable,
    client_event_id: randomUUID(),
    answers: mutable.answers.map((answer) => ({
      ...answer,
      item_id: replacements.get(answer.item_id)!,
      selected_id: replacements.get(answer.selected_id)!,
      choices: answer.choices.map((id) => replacements.get(id)!),
      choice_content_versions: [...answer.choice_content_versions],
    })),
  };
  const table = tableFor(request);
  const ordinalResult = await connection.query(
    "SELECT COALESCE(MAX(source_ordinal), -1)::integer AS max_ordinal FROM " +
      table +
      " WHERE jlpt_level=$1::public.jlpt_level",
    [request.jlpt_level],
  );
  let ordinal = Number(ordinalResult.rows[0]?.max_ordinal) + 1;
  if (!Number.isSafeInteger(ordinal) || ordinal < 0) {
    throw new Error("Native v2 fixture source ordinal unavailable");
  }
  for (const id of request.answers[0]!.choices) {
    if (ordinal > 2147483647) {
      throw new Error("Native v2 fixture source ordinal exhausted");
    }
    if (request.quiz_type === "vocabulary_reading") {
      await connection.query(
        "INSERT INTO public.vocabulary(id,jlpt_level,difficulty,content_version,is_active,expression,reading,meaning_vi,part_of_speech,usage_context_vi,source_ordinal) VALUES($1::uuid,$2::public.jlpt_level,0.2,1,true,$3,$4,'nghĩa','noun','native v2 quiz TEST ONLY',$5)",
        [
          id,
          request.jlpt_level,
          "語" + id.slice(0, 8),
          "ご" + id.slice(0, 8),
          ordinal,
        ],
      );
    } else {
      await connection.query(
        "INSERT INTO public.grammar(id,jlpt_level,difficulty,content_version,is_active,title,pattern,meaning_vi,explanation_vi,source_ordinal) VALUES($1::uuid,$2::public.jlpt_level,0.2,1,true,$3,$4,$5,'native v2 quiz TEST ONLY',$6)",
        [
          id,
          request.jlpt_level,
          "文法" + id.slice(0, 8),
          "N" + id.slice(0, 8),
          "Nghĩa " + id.slice(0, 8),
          ordinal,
        ],
      );
    }
    ordinal++;
  }

  const vocabulary = request.quiz_type === "vocabulary_reading";
  const query =
    "SELECT id::text AS id, source_ordinal, content_version, " +
    (vocabulary
      ? "expression AS heading, reading AS secondary "
      : "title AS heading, meaning_vi AS secondary ") +
    "FROM " +
    table +
    " WHERE jlpt_level=$1::public.jlpt_level AND is_active = true " +
    "ORDER BY source_ordinal ASC NULLS LAST, id LIMIT 5001";
  const persisted = await connection.query(query, [request.jlpt_level]);
  const rows = persisted.rows as SourceRow[];
  const headingCounts = new Map<string, number>();
  for (const row of rows) {
    const heading = row.heading.trim();
    headingCounts.set(heading, (headingCounts.get(heading) ?? 0) + 1);
  }
  const eligible = rows.filter(
    (row) =>
      headingCounts.get(row.heading.trim()) === 1 &&
      (!vocabulary || /[\u3400-\u9fff]/.test(row.heading)),
  );
  const answer = request.answers[0]!;
  const targetIndex = eligible.findIndex((row) => row.id === answer.item_id);
  const target = eligible[targetIndex];
  if (!target || targetIndex < 0) {
    throw new Error("Native v2 target was not eligible");
  }
  const labels = new Map<string, SourceRow>();
  for (const row of eligible) {
    const label = row.secondary.trim();
    if (!labels.has(label)) labels.set(label, row);
  }
  const pool = [...labels.values()];
  const choices: SourceRow[] = [];
  for (let step = 0; step < pool.length && choices.length < 3; step++) {
    const candidate = pool[(targetIndex + step) % pool.length]!;
    if (candidate.secondary.trim() !== target.secondary.trim()) {
      choices.push(candidate);
    }
  }
  if (choices.length !== 3) {
    throw new Error(
      "Native v2 source did not provide three distinct distractors",
    );
  }
  choices.splice(targetIndex % 4, 0, target);
  answer.choices = choices.map((row) => row.id);
  answer.choice_content_versions = choices.map((row) => row.content_version);
  answer.content_version = target.content_version;
  answer.selected_id = originallyCorrect
    ? target.id
    : choices.find((row) => row.id !== target.id)!.id;
  return request;
}

async function setActive(
  connection: Client,
  request: QuizReportV2Request,
  itemId: string,
  active: boolean,
) {
  await connection.query(
    "UPDATE " + tableFor(request) + " SET is_active=$2 WHERE id=$1::uuid",
    [itemId, active],
  );
}

async function receiptCount(
  connection: Client,
  ownerId: string,
  eventId: string,
) {
  const result = await connection.query(
    "SELECT count(*)::integer AS count FROM private.quiz_report_receipts WHERE user_id=$1::uuid AND client_event_id=$2::uuid",
    [ownerId, eventId],
  );
  return result.rows[0]?.count;
}

test(
  "native verified-owner nd-quiz-report-2 host enforces replay-first source validation and A/B isolation",
  { timeout: 30000 },
  async () => {
    const admin = client();
    await admin.connect();
    try {
      const ownerA = randomUUID();
      const ownerB = randomUUID();
      await admin.query("INSERT INTO auth.users(id) VALUES($1::uuid)", [
        ownerA,
      ]);
      await admin.query("INSERT INTO auth.users(id) VALUES($1::uuid)", [
        ownerB,
      ]);

      const tokens = new Map([
        ["verified-A", ownerA],
        ["verified-B", ownerB],
      ]);
      let verifiedOwner = "";
      let opened = 0;
      let validations = 0;
      const auth: AuthVerifier = {
        verify: async (bearer, signal) => {
          if (signal.aborted) {
            throw new BoundaryError("NETWORK_UNAVAILABLE");
          }
          const id = tokens.get(bearer) ?? null;
          verifiedOwner = id ?? "";
          return id ? { id } : null;
        },
      };
      const validateCurrentContent: QuizReportV2CurrentContentValidator =
        async (
          query: QuizReportContentV2Query,
          request: QuizReportV2Request,
          signal: AbortSignal,
        ) => {
          validations++;
          const identity = await query("SELECT auth.uid()::text AS owner");
          assert.equal(identity.command, "SELECT");
          assert.equal(identity.rows[0]?.owner, verifiedOwner);
          await validateCurrentQuizReportContentV2(query, request, signal);
        };
      const dependencies = {
        auth,
        connections: () => {
          opened++;
          return nativeConnectionFactory();
        },
        validateCurrentContent,
      };

      for (const [index, fixture] of fixtures.entries()) {
        const request = await seedAndCanonicalize(admin, fixture);
        const raw = new TextEncoder().encode(JSON.stringify(request));
        const expected: QuizReportV2Response = {
          ...fixture.response,
          client_event_id: request.client_event_id,
        };

        if (index === 0) {
          const [first, duplicate] = await Promise.all([
            submitVerifiedQuizReportV2(schema, raw, "verified-A", dependencies),
            submitVerifiedQuizReportV2(schema, raw, "verified-A", dependencies),
          ]);
          assert.deepEqual(first, expected);
          assert.deepEqual(duplicate, expected);
        } else {
          assert.deepEqual(
            await submitVerifiedQuizReportV2(
              schema,
              raw,
              "verified-A",
              dependencies,
            ),
            expected,
          );
        }
        assert.equal(
          await receiptCount(admin, ownerA, request.client_event_id),
          1,
        );
        assert.equal(
          await receiptCount(admin, ownerB, request.client_event_id),
          0,
        );

        const answer = request.answers[0]!;
        const distractor = answer.choices.find((id) => id !== answer.item_id)!;
        await setActive(admin, request, distractor, false);
        const beforeReplay = validations;
        assert.deepEqual(
          await submitVerifiedQuizReportV2(
            schema,
            raw,
            "verified-A",
            dependencies,
          ),
          expected,
        );
        assert.equal(validations, beforeReplay);

        const changed = structuredClone(request) as MutableRequest;
        const changedAnswer = changed.answers[0]!;
        const changedIndex = changedAnswer.choices.findIndex(
          (id) => id !== changedAnswer.item_id,
        );
        changedAnswer.choice_content_versions[changedIndex]! += 1;
        await assert.rejects(
          submitVerifiedQuizReportV2(
            schema,
            new TextEncoder().encode(JSON.stringify(changed)),
            "verified-A",
            dependencies,
          ),
          (error: unknown) =>
            error instanceof BoundaryError && error.code === "SYNC_CONFLICT",
        );
        assert.equal(validations, beforeReplay);

        await setActive(admin, request, distractor, true);
        assert.deepEqual(
          await submitVerifiedQuizReportV2(
            schema,
            raw,
            "verified-B",
            dependencies,
          ),
          expected,
        );
        assert.equal(
          await receiptCount(admin, ownerA, request.client_event_id),
          1,
        );
        assert.equal(
          await receiptCount(admin, ownerB, request.client_event_id),
          1,
        );

        const stale = structuredClone(request) as MutableRequest;
        stale.client_event_id = randomUUID();
        const staleAnswer = stale.answers[0]!;
        const staleIndex = staleAnswer.choices.findIndex(
          (id) => id !== staleAnswer.item_id,
        );
        staleAnswer.choice_content_versions[staleIndex]! += 1;
        const staleEvent = stale.client_event_id;
        await assert.rejects(
          submitVerifiedQuizReportV2(
            schema,
            new TextEncoder().encode(JSON.stringify(stale)),
            "verified-A",
            dependencies,
          ),
          (error: unknown) =>
            error instanceof BoundaryError &&
            error.code === "VALIDATION_FAILURE",
        );
        assert.equal(await receiptCount(admin, ownerA, staleEvent), 0);
      }

      const beforeUnauthorized = opened;
      await assert.rejects(
        submitVerifiedQuizReportV2(
          schema,
          new TextEncoder().encode(JSON.stringify(fixtures[0]!.request)),
          "invalid-token",
          dependencies,
        ),
        (error: unknown) =>
          error instanceof BoundaryError && error.code === "UNAUTHORIZED",
      );
      assert.equal(opened, beforeUnauthorized);
      console.log(
        "PASS: native verified-owner nd-quiz-report-2 host; source order/versions, duplicate replay, rollback, A/B isolation (TEST ONLY synthetic Auth)",
      );
    } finally {
      await admin.end();
    }
  },
);
