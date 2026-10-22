import { BoundaryError, Contracts, UUID } from "./contracts.ts";
import type { Mutation, Requests, Responses } from "./contracts.ts";
import type {
  ConversationStore,
  ConversationClaim,
  ReceiptKey,
  ReceiptLookup,
  PreparedContext,
} from "./ports.ts";
import { createOwnedPostgresFactory } from "./postgres_connection.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "./postgres_connection.ts";
const lookupSql =
  "SELECT private.ai_receipt_lookup($1::uuid,$2::text,$3::jsonb) AS result";
const acquireSql =
  "SELECT private.ai_conversation_reserve($1::uuid,$2::text,$3::jsonb) AS result";
const completeSql =
  "SELECT private.ai_conversation_complete($1::uuid,$2::text,$3::jsonb,$4::uuid,$5::jsonb) AS result";
const failure = () => new BoundaryError("NETWORK_UNAVAILABLE");
const bytes = (text: string) => new TextEncoder().encode(text).byteLength;
function serialized(value: unknown, limit: number): string {
  const text = JSON.stringify(value);
  if (!text || bytes(text) > limit) throw failure();
  return text;
}
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw failure();
  return value as Record<string, unknown>;
}
function canonicalUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    UUID.test(value) &&
    value === value.toLowerCase()
  );
}
function freeze<T>(value: T): T {
  if (value !== null && typeof value === "object") {
    Object.freeze(value);
    for (const child of Object.values(value)) freeze(child);
  }
  return value;
}
function context(
  value: unknown,
  op: Mutation,
  request: Requests[Mutation],
): PreparedContext {
  serialized(value, 65536);
  const o = object(value),
    finish = op === "finish_conversation";
  if (
    Object.keys(o).length !== (finish ? 4 : 6) ||
    !canonicalUuid(o.sessionId) ||
    typeof o.instruction !== "string" ||
    bytes(o.instruction) < 1 ||
    bytes(o.instruction) > 10000 ||
    !Array.isArray(o.transcript) ||
    o.transcript.length > 99 ||
    !Array.isArray(o.allowedRefs) ||
    o.allowedRefs.length > 1000 ||
    (!finish &&
      (!canonicalUuid(o.messageId) ||
        !Number.isSafeInteger(o.sequenceNo) ||
        (o.sequenceNo as number) < 0)) ||
    (finish && ("messageId" in o || "sequenceNo" in o))
  )
    throw failure();
  if (
    op !== "start_conversation" &&
    o.sessionId !==
      (request as Requests["conversation_turn"]).session_id.toLowerCase()
  )
    throw failure();
  if (
    op === "start_conversation"
      ? o.transcript.length !== 0 || o.sequenceNo !== 0
      : o.transcript.length === 0 || o.transcript.length % 2 !== 1
  )
    throw failure();
  for (const [index, value] of o.transcript.entries()) {
    const message = object(value);
    if (
      Object.keys(message).length !== 2 ||
      message.role !== (index % 2 === 0 ? "assistant" : "user") ||
      typeof message.text_ja !== "string" ||
      [...message.text_ja].length < 1 ||
      [...message.text_ja].length > 5000
    )
      throw failure();
  }
  if (
    op === "conversation_turn" &&
    (o.transcript.length > 97 || o.sequenceNo !== o.transcript.length + 1)
  )
    throw failure();
  const refs = new Set<string>();
  for (const value of o.allowedRefs) {
    const ref = object(value);
    if (
      Object.keys(ref).length !== 2 ||
      !["GRAMMAR", "VOCABULARY"].includes(ref.item_type as string) ||
      !canonicalUuid(ref.item_id)
    )
      throw failure();
    const key = `${ref.item_type}/${ref.item_id}`;
    if (refs.has(key)) throw failure();
    refs.add(key);
  }
  return freeze(structuredClone(o)) as unknown as PreparedContext;
}
function row(r: PostgresResult): unknown {
  if (
    r.command !== "SELECT" ||
    r.rowCount !== 1 ||
    r.rows.length !== 1 ||
    Object.keys(r.rows[0]!).length !== 1 ||
    !("result" in r.rows[0]!)
  )
    throw failure();
  return r.rows[0]!.result;
}
function helperError(error: unknown): BoundaryError {
  if (error && typeof error === "object") {
    const e = error as { code?: unknown; message?: unknown };
    for (const [code, message] of [
      ["22023", "VALIDATION_FAILURE"],
      ["42501", "FORBIDDEN"],
      ["P0002", "NOT_FOUND"],
      ["P0001", "SYNC_CONFLICT"],
    ] as const)
      if (e.code === code && e.message === message)
        return new BoundaryError(message);
  }
  return failure();
}
function same(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (
    !a ||
    !b ||
    typeof a !== "object" ||
    typeof b !== "object" ||
    Array.isArray(a) !== Array.isArray(b)
  )
    return false;
  const x = Object.keys(a),
    y = Object.keys(b);
  return (
    x.length === y.length &&
    x.every(
      (k) =>
        Object.hasOwn(b, k) &&
        same(
          (a as Record<string, unknown>)[k],
          (b as Record<string, unknown>)[k],
        ),
    )
  );
}
/** Explicit coherent lane; fresh owned transactions, no split-port shim or retry. */
export class PostgresConversationStore implements ConversationStore {
  private readonly contracts: Contracts;
  private readonly factory: () => PostgresConnection;
  private readonly timeoutMs: number;
  constructor(
    contracts: Contracts,
    factory: () => PostgresConnection,
    timeoutMs = 5000,
  ) {
    this.contracts = contracts;
    this.factory = factory;
    this.timeoutMs = timeoutMs;
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000)
      throw new Error("Invalid conversation timeout");
  }
  private input(
    key: ReceiptKey,
    request: Requests[Mutation],
  ): { key: ReceiptKey; request: Requests[Mutation]; values: string[] } {
    if (
      !canonicalUuid(key.userId) ||
      !canonicalUuid(key.eventId) ||
      ![
        "start_conversation",
        "conversation_turn",
        "finish_conversation",
      ].includes(key.operation)
    )
      throw new BoundaryError("VALIDATION_FAILURE");
    const snapshot = this.contracts.request(
      key.operation,
      structuredClone(request),
    );
    if (snapshot.client_event_id.toLowerCase() !== key.eventId)
      throw new BoundaryError("SYNC_CONFLICT");
    return {
      key: { ...key },
      request: snapshot,
      values: [key.userId, key.operation, serialized(snapshot, 32768)],
    };
  }
  private lookupResult(value: unknown, op: Mutation): ReceiptLookup {
    serialized(value, 1048704);
    const o = object(value);
    if (
      (o.kind === "pending" || o.kind === "missing") &&
      Object.keys(o).length === 1
    )
      return freeze({ kind: o.kind });
    if (
      o.kind === "completed" &&
      Object.keys(o).length === 2 &&
      "response" in o
    ) {
      serialized(o.response, 1048576);
      return freeze({
        kind: "completed",
        response: structuredClone(this.contracts.response(op, o.response)),
      });
    }
    throw failure();
  }
  async lookup(
    key: ReceiptKey,
    request: Requests[Mutation],
    signal: AbortSignal,
  ): Promise<ReceiptLookup> {
    const input = this.input(key, request);
    return this.transaction(lookupSql, input.values, signal, true, (r) =>
      this.lookupResult(row(r), input.key.operation),
    );
  }
  async acquire(
    key: ReceiptKey,
    request: Requests[Mutation],
    signal: AbortSignal,
  ): Promise<ConversationClaim> {
    const input = this.input(key, request);
    return this.transaction(acquireSql, input.values, signal, false, (r) => {
      const o = object(row(r));
      if (o.kind === "acquired") {
        if (Object.keys(o).length !== 3 || !canonicalUuid(o.token))
          throw failure();
        return freeze({
          kind: "acquired",
          token: o.token,
          context: context(o.context, input.key.operation, input.request),
        });
      }
      const found = this.lookupResult(o, input.key.operation);
      if (found.kind === "missing") throw failure();
      return found;
    });
  }
  async complete(
    key: ReceiptKey,
    request: Requests[Mutation],
    token: string,
    response: Responses[Mutation],
    captured: PreparedContext,
    signal: AbortSignal,
  ): Promise<void> {
    const input = this.input(key, request);
    if (!canonicalUuid(token)) throw new BoundaryError("FORBIDDEN");
    const ctx = context(
      structuredClone(captured),
      input.key.operation,
      input.request,
    );
    const valid = freeze(
      structuredClone(
        this.contracts.response(input.key.operation, structuredClone(response)),
      ),
    );
    const o = valid as unknown as Record<string, unknown>;
    if (input.key.operation !== "finish_conversation") {
      const message =
        o.assistant_message as Responses["conversation_turn"]["assistant_message"];
      if (
        message.id !== ctx.messageId ||
        message.sequence_no !== ctx.sequenceNo ||
        message.audio_ref !== null ||
        (input.key.operation === "start_conversation" &&
          o.session_id !== ctx.sessionId)
      )
        throw new BoundaryError("PROVIDER_UNAVAILABLE");
    }
    const refs: { item_type: string; item_id: string }[] = [];
    for (const field of ["live_feedback", "errors"])
      for (const correction of (o[field] ?? []) as { item_refs: typeof refs }[])
        refs.push(...correction.item_refs);
    refs.push(...((o.srs_recommendations ?? []) as typeof refs));
    if (
      refs.some(
        (ref) =>
          !ctx.allowedRefs.some(
            (a) => a.item_type === ref.item_type && a.item_id === ref.item_id,
          ),
      )
    )
      throw new BoundaryError("PROVIDER_UNAVAILABLE");
    input.values.push(token, serialized(valid, 1048576));
    await this.transaction(completeSql, input.values, signal, false, (r) => {
      const returned = this.contracts.response(input.key.operation, row(r));
      serialized(returned, 1048576);
      if (!same(returned, valid)) throw failure();
    });
  }
  private async transaction<T>(
    sql: string,
    values: string[],
    parent: AbortSignal,
    readOnly: boolean,
    decode: (r: PostgresResult) => T,
  ): Promise<T> {
    const controller = new AbortController();
    let connection: PostgresConnection | undefined;
    let closed = false;
    const stop = () => {
      controller.abort();
      if (connection && !closed) {
        closed = true;
        try {
          connection.close();
        } catch {
          /* Never log credentials or SQL text. */
        }
      }
    };
    const deadline = performance.now() + this.timeoutMs;
    const alive = () => {
      if (performance.now() >= deadline) stop();
      if (controller.signal.aborted) throw failure();
    };
    const wait = async <R>(work: Promise<R>): Promise<R> => {
      let abort: (() => void) | undefined;
      try {
        if (controller.signal.aborted) {
          void work.catch(() => {});
          throw failure();
        }
        const value = await new Promise<R>((resolve, reject) => {
          abort = () => reject(failure());
          controller.signal.addEventListener("abort", abort, { once: true });
          void work.then(resolve, reject);
        });
        alive();
        return value;
      } finally {
        if (abort) controller.signal.removeEventListener("abort", abort);
      }
    };
    const timer = setTimeout(stop, this.timeoutMs);
    parent.addEventListener("abort", stop, { once: true });
    try {
      if (parent.aborted) stop();
      alive();
      connection = this.factory();
      alive();
      await wait(connection.connect());
      for (const [text, command] of [
        [
          `BEGIN ISOLATION LEVEL READ COMMITTED${readOnly ? " READ ONLY" : ""}`,
          "BEGIN",
        ],
        ["SET LOCAL ROLE service_role", "SET"],
        ["SET LOCAL lock_timeout = '1000ms'", "SET"],
        ["SET LOCAL statement_timeout = '2000ms'", "SET"],
        ["SET LOCAL idle_in_transaction_session_timeout = '3000ms'", "SET"],
      ]) {
        alive();
        const r = await wait(connection.query(text!));
        if (r.command !== command) throw failure();
      }
      alive();
      let result: PostgresResult;
      try {
        result = await wait(connection.query(sql, values));
      } catch (error) {
        alive();
        throw helperError(error);
      }
      const value = decode(result);
      alive();
      const committed = await wait(connection.query("COMMIT"));
      if (committed.command !== "COMMIT") throw failure();
      alive();
      return value;
    } catch (error) {
      if (error instanceof BoundaryError) throw error;
      throw failure();
    } finally {
      clearTimeout(timer);
      parent.removeEventListener("abort", stop);
      stop();
    }
  }
}
export function createPostgresConversationStore(
  contracts: Contracts,
  databaseUrl: string,
): PostgresConversationStore {
  return new PostgresConversationStore(
    contracts,
    createOwnedPostgresFactory(databaseUrl, "nihongo-ai-conversation"),
  );
}
