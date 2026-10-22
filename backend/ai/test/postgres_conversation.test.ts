// TEST ONLY protocol replies/ports/faults. No hosted identity or durable SQL proof.
import { test } from "node:test";
import assert from "node:assert/strict";
import { getEventListeners } from "node:events";
import { setImmediate } from "node:timers/promises";
import {
  PostgresConversationStore,
  createPostgresConversationStore,
} from "../src/postgres_conversation.ts";
import type {
  PostgresConnection,
  PostgresResult,
} from "../src/postgres_connection.ts";
import { BoundaryError } from "../src/contracts.ts";
import type { Mutation, Requests, Responses } from "../src/contracts.ts";
import type { PreparedContext, ReceiptKey } from "../src/ports.ts";
import { AiService } from "../src/service.ts";
import { contracts, fixtures, setup, userA, userB } from "./support.ts";
const token = "f1000000-0000-4000-8000-000000000001";
const signal = () => new AbortController().signal;
const request = <O extends Mutation>(op: O): Requests[O] =>
  contracts.request(op, structuredClone(fixtures[`${op}_request`]));
const response = <O extends Mutation>(op: O): Responses[O] => {
  const value = structuredClone(fixtures[`${op}_response`]);
  // Frozen generic fixture permits sequence0; an actual atomic turn follows
  // assistant0/user1 and therefore reserves assistant2. Preserve canonical file.
  if (op === "conversation_turn") {
    const r = value as Responses["conversation_turn"];
    return contracts.response(op, {
      ...r,
      assistant_message: { ...r.assistant_message, sequence_no: 2 },
    });
  }
  return contracts.response(op, value);
};
function key(op: Mutation, owner = userA): ReceiptKey {
  return {
    userId: owner,
    operation: op,
    eventId: request(op).client_event_id.toLowerCase(),
  };
}
function context(op: Mutation): PreparedContext {
  const r = response(op);
  return {
    instruction: "N5; fixed server context",
    transcript:
      op === "start_conversation"
        ? []
        : [{ role: "assistant", text_ja: "こんにちは" }],
    allowedRefs: [],
    sessionId:
      op === "start_conversation"
        ? (r as Responses["start_conversation"]).session_id
        : (request(op) as Requests["conversation_turn"]).session_id,
    ...(op === "finish_conversation"
      ? {}
      : {
          messageId: (r as Responses["conversation_turn"]).assistant_message.id,
          sequenceNo: (r as Responses["conversation_turn"]).assistant_message
            .sequence_no,
        }),
  };
}
function reply(text: string, values?: string[]): PostgresResult {
  let value: unknown;
  if (text.includes("ai_receipt_lookup")) value = { kind: "missing" };
  if (text.includes("ai_conversation_reserve"))
    value = {
      kind: "acquired",
      token,
      context: context(values![1] as Mutation),
    };
  if (text.includes("ai_conversation_complete"))
    value = JSON.parse(values![4]!);
  return {
    command: text.startsWith("SELECT") ? "SELECT" : text.split(" ")[0]!,
    rowCount: value ? 1 : null,
    rows: value ? [{ result: value }] : [],
  };
}
function fixture() {
  let opened = 0,
    closed = 0;
  const calls: { text: string; values?: string[]; connection: number }[] = [];
  let connect = async () => {};
  let query = async (
    text: string,
    values?: string[],
  ): Promise<PostgresResult> => reply(text, values);
  const factory = (): PostgresConnection => {
    const id = ++opened;
    return {
      connect: () => connect(),
      query: async (text, values) => {
        calls.push({ text, values, connection: id });
        return query(text, values);
      },
      close: () => {
        closed++;
      },
    };
  };
  return {
    calls,
    factory,
    opened: () => opened,
    closed: () => closed,
    setQuery: (fn: typeof query) => {
      query = fn;
    },
    setConnect: (fn: typeof connect) => {
      connect = fn;
    },
    repo: (timeout = 5000) =>
      new PostgresConversationStore(contracts, factory, timeout),
  };
}
async function failure(work: Promise<unknown>, code = "NETWORK_UNAVAILABLE") {
  await assert.rejects(work, (e: unknown) => {
    assert.ok(e instanceof BoundaryError);
    assert.equal(e.code, code);
    assert.equal(e.message, code);
    assert.ok(!JSON.stringify(e).includes("PRIVATE"));
    return true;
  });
}
async function barrier(ready: () => boolean) {
  const deadline = performance.now() + 1000;
  while (!ready() && performance.now() < deadline) await setImmediate();
  assert.ok(
    ready(),
    "Fixture conversation barrier did not arrive within its bound",
  );
}
function service(f: ReturnType<typeof fixture>, timeout = 15000) {
  const s = setup();
  s.deps.conversations = f.repo();
  s.deps.context = {
    prepare: async () => {
      assert.fail("Split prepare used");
    },
    validateResult: async () => {
      assert.fail("Split validate used");
    },
  };
  for (const method of ["lookup", "claim", "complete", "reconcile"] as const)
    s.store[method] = async () => {
      assert.fail("Legacy receipt fallback used");
    };
  s.deps.provider.generate = async (input) => {
    s.calls.push(input);
    return JSON.stringify(response(input.operation as Mutation));
  };
  return {
    ...s,
    run: (op: Mutation = "start_conversation", parent?: AbortSignal) =>
      new AiService(contracts, s.deps, timeout).execute(
        op,
        "valid-A",
        JSON.stringify(request(op)),
        parent,
      ),
  };
}
test("atomic conversation all three operations use captured parameters and fresh bounded owned transactions", async () => {
  for (const op of [
    "start_conversation",
    "conversation_turn",
    "finish_conversation",
  ] as const) {
    const f = fixture(),
      repo = f.repo(),
      parent = new AbortController();
    assert.deepEqual(await repo.lookup(key(op), request(op), parent.signal), {
      kind: "missing",
    });
    const claim = await repo.acquire(key(op), request(op), parent.signal);
    assert.equal(claim.kind, "acquired");
    if (claim.kind !== "acquired") assert.fail();
    await repo.complete(
      key(op),
      request(op),
      claim.token,
      response(op),
      claim.context,
      parent.signal,
    );
    assert.deepEqual(
      f.calls.slice(0, 5).map((c) => c.text),
      [
        "BEGIN ISOLATION LEVEL READ COMMITTED READ ONLY",
        "SET LOCAL ROLE service_role",
        "SET LOCAL lock_timeout = '1000ms'",
        "SET LOCAL statement_timeout = '2000ms'",
        "SET LOCAL idle_in_transaction_session_timeout = '3000ms'",
      ],
    );
    assert.equal(f.calls[7]?.text, "BEGIN ISOLATION LEVEL READ COMMITTED");
    assert.equal(f.calls[14]?.text, "BEGIN ISOLATION LEVEL READ COMMITTED");
    assert.deepEqual(f.calls[5]?.values, [
      userA,
      op,
      JSON.stringify(request(op)),
    ]);
    assert.deepEqual(f.calls[19]?.values, [
      userA,
      op,
      JSON.stringify(request(op)),
      token,
      JSON.stringify(response(op)),
    ]);
    assert.equal(f.calls[20]?.text, "COMMIT");
    assert.equal(f.opened(), 3);
    assert.equal(f.closed(), 3);
    assert.ok(
      Object.isFrozen(claim) &&
        Object.isFrozen(claim.context) &&
        Object.isFrozen(claim.context.transcript),
    );
    assert.equal(getEventListeners(parent.signal, "abort").length, 0);
    assert.equal(parent.signal.aborted, false);
  }
});
test("acquired replies strictly validate canonical capability and bounded contiguous context", async () => {
  const good = context("start_conversation");
  for (const value of [
    null,
    {},
    { kind: "acquired" },
    { kind: "acquired", token: "PRIVATE", context: good },
    ...[
      null,
      { ...good, extra: 1 },
      { ...good, sessionId: "bad" },
      { ...good, messageId: "bad" },
      { ...good, sequenceNo: 1 },
      { ...good, transcript: [{ role: "user", text_ja: "文" }] },
      { ...good, instruction: "文".repeat(4000) },
      { ...good, allowedRefs: [{ item_type: "KANJI", item_id: userA }] },
      {
        ...good,
        allowedRefs: [{ item_type: "GRAMMAR", item_id: userA, extra: 1 }],
      },
      {
        ...good,
        allowedRefs: Array(2).fill({ item_type: "GRAMMAR", item_id: userA }),
      },
    ].map((context) => ({ kind: "acquired", token, context })),
  ]) {
    const f = fixture();
    f.setQuery(async (text, values) =>
      text.startsWith("SELECT")
        ? { command: "SELECT", rowCount: 1, rows: [{ result: value }] }
        : reply(text, values),
    );
    await failure(
      f
        .repo()
        .acquire(
          key("start_conversation"),
          request("start_conversation"),
          signal(),
        ),
    );
    assert.equal(
      f.calls.some((c) => c.text === "COMMIT"),
      false,
    );
    assert.equal(f.closed(), 1);
  }
});
test("turn and finish projections reject wrong parent, transcript roles, slots and fabricated finish message", async () => {
  for (const op of ["conversation_turn", "finish_conversation"] as const)
    for (const change of [
      { sessionId: userB },
      { transcript: [] },
      { transcript: [{ role: "user", text_ja: "文" }] },
      { transcript: [{ role: "assistant", text_ja: "" }] },
      op === "conversation_turn" ? { sequenceNo: 4 } : { messageId: userA },
    ]) {
      const f = fixture();
      f.setQuery(async (text, values) =>
        text.startsWith("SELECT")
          ? {
              command: "SELECT",
              rowCount: 1,
              rows: [
                {
                  result: {
                    kind: "acquired",
                    token,
                    context: { ...context(op), ...change },
                  },
                },
              ],
            }
          : reply(text, values),
      );
      await failure(f.repo().acquire(key(op), request(op), signal()));
      assert.equal(
        f.calls.some((c) => c.text === "COMMIT"),
        false,
      );
    }
});
test("lookup and losing acquire expose only exact capability-free pending or schema-checked original completion", async () => {
  for (const kind of ["pending", "completed"] as const) {
    const f = fixture(),
      op = "start_conversation";
    const value =
      kind === "pending" ? { kind } : { kind, response: response(op) };
    f.setQuery(async (text, values) =>
      text.startsWith("SELECT")
        ? { command: "SELECT", rowCount: 1, rows: [{ result: value }] }
        : reply(text, values),
    );
    for (const method of ["lookup", "acquire"] as const)
      assert.deepEqual(
        await f.repo()[method](key(op), request(op), signal()),
        value,
      );
  }
  for (const value of [
    { kind: "pending", token },
    { kind: "completed", response: {} },
    {
      kind: "completed",
      response: response("start_conversation"),
      context: {},
    },
    { kind: "acquired", token, context: context("start_conversation") },
  ]) {
    const f = fixture();
    f.setQuery(async (text, values) =>
      text.startsWith("SELECT")
        ? { command: "SELECT", rowCount: 1, rows: [{ result: value }] }
        : reply(text, values),
    );
    await assert.rejects(
      f
        .repo()
        .lookup(
          key("start_conversation"),
          request("start_conversation"),
          signal(),
        ),
    );
    assert.equal(
      f.calls.some((c) => c.text === "COMMIT"),
      false,
    );
  }
});
test("key owner operation event and frozen wire request are validated before opening any connection", async () => {
  for (const [k, req, code] of [
    [
      { ...key("start_conversation"), userId: "forged" },
      request("start_conversation"),
      "VALIDATION_FAILURE",
    ],
    [
      { ...key("start_conversation"), eventId: userB },
      request("start_conversation"),
      "SYNC_CONFLICT",
    ],
    [
      key("start_conversation"),
      {
        ...request("start_conversation"),
        user_id: userB,
      } as unknown as Requests["start_conversation"],
      "VALIDATION_FAILURE",
    ],
  ] as const) {
    const f = fixture();
    await failure(f.repo().acquire(k, req, signal()), code);
    assert.equal(f.opened(), 0);
  }
});
test("completion rejects model identity audio refs and malformed output before SQL", async () => {
  const op = "start_conversation";
  for (const change of [
    { id: userB },
    { audio_ref: "model-url" },
    { sequence_no: 2 },
    { role: "user" },
    { text_ja: "" },
  ]) {
    const f = fixture(),
      r = response(op);
    Object.assign(r.assistant_message, change);
    await failure(
      f.repo().complete(key(op), request(op), token, r, context(op), signal()),
      "PROVIDER_UNAVAILABLE",
    );
    assert.equal(f.opened(), 0);
  }
  const f = fixture();
  await failure(
    f
      .repo()
      .complete(
        key(op),
        request(op),
        "wrong",
        response(op),
        context(op),
        signal(),
      ),
    "FORBIDDEN",
  );
  assert.equal(f.opened(), 0);
});
test("completion compares returned original semantically and rejects differing result before COMMIT", async () => {
  const f = fixture();
  f.setQuery(async (text, values) =>
    text.includes("ai_conversation_complete")
      ? {
          command: "SELECT",
          rowCount: 1,
          rows: [
            {
              result: { ...response("start_conversation"), session_id: userB },
            },
          ],
        }
      : reply(text, values),
  );
  await failure(
    f
      .repo()
      .complete(
        key("start_conversation"),
        request("start_conversation"),
        token,
        response("start_conversation"),
        context("start_conversation"),
        signal(),
      ),
  );
  assert.equal(
    f.calls.some((c) => c.text === "COMMIT"),
    false,
  );
});
test("all setup, SELECT cardinality and COMMIT command failures close without retry", async () => {
  for (const phase of [0, 1, 2, 3, 4, 5, 6]) {
    const f = fixture();
    let index = 0;
    f.setQuery(async (text, values) =>
      index++ === phase
        ? { command: "PRIVATE", rowCount: 0, rows: [] }
        : reply(text, values),
    );
    await failure(
      f
        .repo()
        .acquire(
          key("start_conversation"),
          request("start_conversation"),
          signal(),
        ),
    );
    assert.equal(f.closed(), 1);
    assert.equal(f.opened(), 1);
  }
  for (const r of [
    { command: "SELECT", rowCount: 2, rows: [{ result: { kind: "pending" } }] },
    {
      command: "SELECT",
      rowCount: 1,
      rows: [{ result: { kind: "pending" }, extra: 1 }],
    },
    { command: "SELECT", rowCount: 1, rows: [] },
  ]) {
    const f = fixture();
    f.setQuery(async (text, values) =>
      text.startsWith("SELECT") ? r : reply(text, values),
    );
    await failure(
      f
        .repo()
        .lookup(
          key("start_conversation"),
          request("start_conversation"),
          signal(),
        ),
    );
  }
});
test("only exact controlled helper SQLSTATE and message pairs cross the safe error boundary", async () => {
  for (const [code, message, expected] of [
    ["22023", "VALIDATION_FAILURE", "VALIDATION_FAILURE"],
    ["42501", "FORBIDDEN", "FORBIDDEN"],
    ["P0002", "NOT_FOUND", "NOT_FOUND"],
    ["P0001", "SYNC_CONFLICT", "SYNC_CONFLICT"],
    ["P0001", "PRIVATE password", "NETWORK_UNAVAILABLE"],
    ["40001", "PRIVATE", "NETWORK_UNAVAILABLE"],
  ]) {
    const f = fixture();
    f.setQuery(async (text, values) => {
      if (text.startsWith("SELECT")) throw { code, message };
      return reply(text, values);
    });
    await failure(
      f
        .repo()
        .acquire(
          key("start_conversation"),
          request("start_conversation"),
          signal(),
        ),
      expected,
    );
    assert.equal(f.closed(), 1);
  }
});
test("service uses atomic lane for all mutations without split context or legacy receipt calls", async () => {
  for (const op of [
    "start_conversation",
    "conversation_turn",
    "finish_conversation",
  ] as const) {
    const f = fixture(),
      s = service(f);
    assert.deepEqual(await s.run(op), { ok: true, response: response(op) });
    assert.equal(s.calls.length, 1);
    assert.equal(
      s.calls[0]?.idempotencyKey,
      `${userA}/${op}/${request(op).client_event_id}`,
    );
    assert.equal(f.closed(), 3);
  }
});
test("provider waits for confirmed acquisition COMMIT and final success waits for completion COMMIT", async () => {
  for (const target of [2, 3]) {
    const f = fixture(),
      s = service(f);
    let commits = 0;
    let unblock!: (r: PostgresResult) => void;
    f.setQuery(async (text, values) =>
      text === "COMMIT" && ++commits === target
        ? new Promise((resolve) => {
            unblock = resolve;
          })
        : reply(text, values),
    );
    let done = false;
    const work = s.run().then((r) => {
      done = true;
      return r;
    });
    await barrier(() => Boolean(unblock));
    assert.equal(done, false);
    assert.equal(s.calls.length, target === 2 ? 0 : 1);
    unblock(reply("COMMIT"));
    assert.equal((await work).ok, true);
  }
});
test("pending from lookup or acquire never invokes provider or legacy recovery even when configured", async () => {
  for (const phase of ["lookup", "acquire"]) {
    const f = fixture(),
      s = service(f);
    s.deps.recovery = {
      lookup: async () => {
        assert.fail("Legacy recovery must not run");
      },
    };
    f.setQuery(async (text, values) =>
      (
        phase === "lookup"
          ? text.includes("ai_receipt_lookup")
          : text.includes("ai_conversation_reserve")
      )
        ? {
            command: "SELECT",
            rowCount: 1,
            rows: [{ result: { kind: "pending" } }],
          }
        : reply(text, values),
    );
    const r = await s.run();
    assert.equal(r.ok, false);
    assert.equal(s.calls.length, 0);
    assert.equal(
      f.calls.some((c) => c.text.includes("ai_conversation_complete")),
      false,
    );
  }
});
test("completed replay returns original schema-checked response before active context or new provider work", async () => {
  const f = fixture(),
    s = service(f);
  f.setQuery(async (text, values) =>
    text.includes("ai_receipt_lookup")
      ? {
          command: "SELECT",
          rowCount: 1,
          rows: [
            {
              result: {
                kind: "completed",
                response: response("start_conversation"),
              },
            },
          ],
        }
      : reply(text, values),
  );
  assert.deepEqual(await s.run(), {
    ok: true,
    response: response("start_conversation"),
  });
  assert.equal(s.calls.length, 0);
  assert.equal(f.opened(), 1);
});
test("provider failure or invalid model result cannot complete or release the pending reservation", async () => {
  for (const raw of [
    "not-json",
    JSON.stringify({ ...response("start_conversation"), session_id: userB }),
  ]) {
    const f = fixture(),
      s = service(f);
    s.deps.provider.generate = async () => raw;
    const r = await s.run();
    assert.equal(r.ok, false);
    assert.equal(
      f.calls.some((c) => c.text.includes("ai_conversation_complete")),
      false,
    );
  }
});
test("unknown acquisition/completion COMMIT outcome returns no success and never retries a transaction", async () => {
  for (const phase of [2, 3]) {
    const f = fixture(),
      s = service(f);
    let commits = 0;
    f.setQuery(async (text, values) => {
      if (text === "COMMIT" && ++commits === phase)
        throw Error("PRIVATE token");
      return reply(text, values);
    });
    const r = await s.run();
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.error.code, "NETWORK_UNAVAILABLE");
    assert.equal(s.calls.length, phase === 2 ? 0 : 1);
    assert.equal(f.opened(), phase);
    assert.equal(f.closed(), phase);
  }
});
test("pre-abort opens nothing; ignored connect query and COMMIT cancellation cannot advance after late settlement", async () => {
  const p = new AbortController();
  p.abort();
  const f = fixture();
  await failure(
    f
      .repo()
      .acquire(
        key("start_conversation"),
        request("start_conversation"),
        p.signal,
      ),
  );
  assert.equal(f.opened(), 0);
  for (const phase of ["connect", "query", "commit"]) {
    const f = fixture(),
      parent = new AbortController();
    let unblock!: () => void;
    if (phase === "connect")
      f.setConnect(
        () =>
          new Promise((resolve) => {
            unblock = resolve;
          }),
      );
    else
      f.setQuery((text, values) =>
        (phase === "query" ? text.startsWith("SELECT") : text === "COMMIT")
          ? new Promise((resolve) => {
              unblock = () => resolve(reply(text, values));
            })
          : Promise.resolve(reply(text, values)),
      );
    const work = f
      .repo()
      .acquire(
        key("start_conversation"),
        request("start_conversation"),
        parent.signal,
      );
    await barrier(() => Boolean(unblock));
    parent.abort();
    await failure(work);
    const n = f.calls.length;
    unblock();
    await setImmediate();
    assert.equal(f.calls.length, n);
    assert.equal(f.closed(), 1);
    assert.equal(getEventListeners(parent.signal, "abort").length, 0);
  }
});
test("independent bounded timeout terminates ignored I/O and late results never issue another query", async () => {
  const f = fixture();
  let unblock!: () => void;
  f.setConnect(
    () =>
      new Promise((resolve) => {
        unblock = resolve;
      }),
  );
  await failure(
    f
      .repo(5)
      .acquire(
        key("start_conversation"),
        request("start_conversation"),
        signal(),
      ),
  );
  unblock();
  await setImmediate();
  assert.equal(f.calls.length, 0);
  assert.equal(f.closed(), 1);
});
test("caller mutation during connection wait cannot change captured owner event request token output or context", async () => {
  const f = fixture(),
    k = key("start_conversation"),
    req = request("start_conversation"),
    ctx = context("start_conversation"),
    r = response("start_conversation");
  let unblock!: () => void;
  f.setConnect(
    () =>
      new Promise((resolve) => {
        unblock = resolve;
      }),
  );
  const work = f.repo().complete(k, req, token, r, ctx, signal());
  k.userId = userB;
  (req as { client_event_id: string }).client_event_id = userB;
  (r.assistant_message as { text_ja: string }).text_ja = "変更";
  (ctx as { instruction: string }).instruction = "変更";
  unblock();
  await work;
  assert.deepEqual(f.calls[5]?.values, [
    userA,
    "start_conversation",
    JSON.stringify(request("start_conversation")),
    token,
    JSON.stringify(response("start_conversation")),
  ]);
});
test("three interleaved account calls never share a connection or mutable context", async () => {
  const f = fixture(),
    repo = f.repo();
  const claims = await Promise.all(
    [userA, userB, userA].map((owner) =>
      repo.acquire(
        key("start_conversation", owner),
        request("start_conversation"),
        signal(),
      ),
    ),
  );
  assert.equal(f.opened(), 3);
  assert.equal(f.closed(), 3);
  assert.deepEqual(
    f.calls
      .filter((c) => c.text.startsWith("SELECT"))
      .map((c) => c.values?.[0]),
    [userA, userB, userA],
  );
  assert.notEqual(claims[0], claims[2]);
});
test("trusted construction rejects URL overrides and validates timeout without logging configuration", () => {
  for (const url of [
    "https://PRIVATE",
    "postgresql://u:p@localhost/db?sslmode=disable",
    "postgresql://u:p@localhost/db#PRIVATE",
  ])
    assert.throws(() => createPostgresConversationStore(contracts, url), {
      message: "Invalid trusted PostgreSQL configuration",
    });
  for (const timeout of [0, -1, 15001, NaN, 1.5])
    assert.throws(
      () =>
        new PostgresConversationStore(contracts, fixture().factory, timeout),
      { message: "Invalid conversation timeout" },
    );
});
test("service captures the acquired capability and context before asynchronous provider work", async () => {
  const s = setup(),
    claim = {
      kind: "acquired" as const,
      token,
      context: context("start_conversation"),
    };
  let completed = 0;
  s.deps.conversations = {
    lookup: async () => ({ kind: "missing" }),
    acquire: async () => claim,
    complete: async (k, req, storedToken, result, captured) => {
      completed++;
      assert.ok(Object.isFrozen(k));
      assert.ok(Object.isFrozen(req));
      assert.ok(Object.isFrozen(result));
      assert.equal(storedToken, token);
      assert.equal(captured.instruction, "N5; fixed server context");
    },
  };
  s.deps.provider.generate = async () => {
    claim.token = userB;
    (claim.context as { instruction: string }).instruction = "late mutation";
    return JSON.stringify(response("start_conversation"));
  };
  const r = await new AiService(contracts, s.deps).execute(
    "start_conversation",
    "valid-A",
    JSON.stringify(request("start_conversation")),
  );
  assert.equal(r.ok, true);
  assert.equal(completed, 1);
});
