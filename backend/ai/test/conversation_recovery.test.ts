// TEST ONLY trusted lookup/Auth/store fixtures. They do not authenticate upstream.
import { test } from "node:test";
import assert from "node:assert/strict";
import { getEventListeners } from "node:events";
import { setImmediate } from "node:timers/promises";
import { CorrelatedConversationRecovery } from "../src/conversation_recovery.ts";
import { AiService } from "../src/service.ts";
import { BoundaryError } from "../src/contracts.ts";
import type { Mutation, Requests, Responses } from "../src/contracts.ts";
import type {
  ConversationStore,
  ConversationRecoveryStore,
  ConversationRecoveryLookup,
  AuthenticatedConversationLookup,
  PreparedContext,
  ReceiptKey,
} from "../src/ports.ts";
import { contracts, fixtures, setup, userA, userB } from "./support.ts";
type Mutable<T> = T extends object
  ? { -readonly [P in keyof T]: Mutable<T[P]> }
  : T;
const signal = () => new AbortController().signal;
function fixture(op: Mutation = "start_conversation", owner = userA) {
  const request = structuredClone(fixtures[`${op}_request`]) as Mutable<
    Requests[Mutation]
  >;
  const key: ReceiptKey = {
    userId: owner,
    operation: op,
    eventId: request.client_event_id.toLowerCase(),
  };
  const response = structuredClone(fixtures[`${op}_response`]) as Mutable<
    Responses[Mutation]
  >;
  if (op === "conversation_turn")
    (response as Mutable<Responses[typeof op]>).assistant_message.sequence_no =
      2;
  const ctx: PreparedContext = {
    instruction: "Original server context",
    allowedRefs: [],
    transcript:
      op === "start_conversation" ? [] : [{ role: "assistant", text_ja: "文" }],
    sessionId:
      op === "start_conversation"
        ? (response as Responses["start_conversation"]).session_id
        : (request as Requests["conversation_turn"]).session_id,
    ...(op === "finish_conversation"
      ? {}
      : {
          messageId: (response as Responses["conversation_turn"])
            .assistant_message.id,
          sequenceNo: (response as Responses["conversation_turn"])
            .assistant_message.sequence_no,
        }),
  };
  const correlation = {
    receipt_id: "aa000000-0000-4000-8000-000000000001",
    user_id: owner,
    operation: op,
    client_event_id: key.eventId,
    idempotency_key: `${owner}/${op}/${key.eventId}`,
  };
  const state = {
    found: {
      kind: "pending",
      correlation,
      context: ctx,
    } as unknown as ConversationRecoveryLookup,
    record: {
      user_id: owner,
      operation: op,
      client_event_id: key.eventId,
      idempotency_key: correlation.idempotency_key,
      request: structuredClone(request),
      context: structuredClone(ctx),
      response: structuredClone(response),
    },
    lookups: 0,
    reconciliations: 0,
    claims: 0,
    providerLookups: 0,
    completed: undefined as undefined | Responses[Mutation],
  };
  const store: ConversationStore & ConversationRecoveryStore = {
    lookup: async () => ({ kind: "pending" }),
    acquire: async () => {
      state.claims++;
      return { kind: "pending" };
    },
    complete: async () => assert.fail("ordinary token completion"),
    lookupRecovery: async (k, req) => {
      state.lookups++;
      assert.deepEqual(k, key);
      assert.deepEqual(req, request);
      return state.found;
    },
    reconcile: async (k, req, bound, context, value) => {
      state.reconciliations++;
      assert.deepEqual(k, key);
      assert.deepEqual(req, request);
      assert.equal(bound.receipt_id, "aa000000-0000-4000-8000-000000000001");
      assert.equal(context.instruction, "Original server context");
      assert.ok(Object.isFrozen(k));
      assert.ok(Object.isFrozen(req));
      assert.ok(Object.isFrozen(bound));
      assert.ok(Object.isFrozen(context.transcript));
      assert.ok(Object.isFrozen(value));
      state.completed = structuredClone(value);
    },
  };
  const lookup: AuthenticatedConversationLookup = {
    lookupExisting: async (input) => {
      state.providerLookups++;
      assert.deepEqual(input, {
        key,
        request,
        context: ctx,
        idempotencyKey: correlation.idempotency_key,
      });
      assert.ok(Object.isFrozen(input));
      assert.ok(Object.isFrozen(input.key));
      assert.ok(Object.isFrozen(input.request));
      assert.ok(Object.isFrozen(input.context));
      assert.equal("receipt_id" in input, false);
      assert.equal("token" in input, false);
      return JSON.stringify(state.record);
    },
  };
  const s = setup();
  s.deps.conversations = store;
  s.deps.conversationRecovery = { store, lookup };
  s.deps.provider.generate = async () =>
    assert.fail("Recovery must never generate");
  for (const method of ["lookup", "claim", "complete", "reconcile"] as const)
    s.store[method] = async () => assert.fail("Legacy receipt/recovery used");
  s.deps.recovery = { lookup: async () => assert.fail("Legacy lookup used") };
  s.deps.context = {
    prepare: async () => assert.fail("split prepare"),
    validateResult: async () => assert.fail("split validation"),
  };
  return {
    key,
    request,
    response,
    ctx,
    correlation,
    state,
    store,
    lookup,
    deps: s.deps,
    recover: (timeout = 10000, parent = signal()) =>
      new CorrelatedConversationRecovery(
        contracts,
        store,
        lookup,
        timeout,
      ).recover(key, request, parent),
    run: (parent?: AbortSignal) =>
      new AiService(contracts, s.deps).execute(
        op,
        owner === userA ? "valid-A" : "valid-B",
        JSON.stringify(request),
        parent,
      ),
  };
}
async function failure(work: Promise<unknown>, code = "PROVIDER_UNAVAILABLE") {
  await assert.rejects(work, (e: unknown) => {
    assert.ok(e instanceof BoundaryError);
    assert.equal(e.code, code);
    assert.equal(e.message, code);
    assert.equal(JSON.stringify(e).includes("PRIVATE"), false);
    return true;
  });
}
async function barrier(ready: () => boolean) {
  const end = performance.now() + 1000;
  while (!ready() && performance.now() < end) await setImmediate();
  assert.ok(ready(), "Recovery fixture barrier did not arrive within bound");
}
test("correlated runtime recovers all three original mutations with frozen original association and no dispatch", async () => {
  for (const op of [
    "start_conversation",
    "conversation_turn",
    "finish_conversation",
  ] as const) {
    const f = fixture(op),
      out = await f.run();
    assert.deepEqual(out, { ok: true, response: f.response });
    assert.equal(f.state.lookups, 1);
    assert.equal(f.state.providerLookups, 1);
    assert.equal(f.state.reconciliations, 1);
    assert.equal(f.state.claims, 0);
  }
});
test("recovery completed original replay bypasses upstream and missing legacy pending never claim or dispatch", async () => {
  for (const kind of ["completed", "missing", "pending"] as const) {
    const f = fixture();
    f.state.found =
      kind === "completed"
        ? { kind, response: f.response }
        : kind === "missing"
          ? { kind: "missing" }
          : { kind: "pending" };
    if (kind === "completed") assert.deepEqual(await f.recover(), f.response);
    else await failure(f.recover());
    assert.equal(f.state.providerLookups, 0);
    assert.equal(f.state.reconciliations, 0);
    assert.equal(f.state.claims, 0);
  }
});
test("pending recovery is explicit and same-store only without legacy fallback", async () => {
  for (const mode of ["absent", "different", "acquire-race"] as const) {
    const f = fixture();
    if (mode === "absent") delete f.deps.conversationRecovery;
    else if (mode === "different")
      f.deps.conversationRecovery = {
        store: fixture().store,
        lookup: f.lookup,
      };
    else {
      f.store.lookup = async () => ({ kind: "missing" });
      f.state.found = { kind: "missing" };
    }
    const out = await f.run();
    assert.equal(out.ok, false);
    assert.equal(f.state.reconciliations, 0);
    assert.equal(f.state.providerLookups, 0);
    assert.equal(f.state.claims, mode === "acquire-race" ? 1 : 0);
  }
});
test("correlated runtime rejects every changed owner operation event key request context response and unknown field", async () => {
  for (const field of [
    "user_id",
    "operation",
    "client_event_id",
    "idempotency_key",
    "request",
    "context",
    "response",
    "PRIVATE",
  ]) {
    const f = fixture();
    (f.state.record as unknown as Record<string, unknown>)[field] =
      field === "request"
        ? { ...f.request, jlpt_level: "N4" }
        : field === "context"
          ? { ...f.ctx, instruction: "Changed" }
          : field === "response"
            ? { PRIVATE: true }
            : "PRIVATE";
    const out = await f.run();
    assert.equal(out.ok, false);
    if (!out.ok) {
      assert.equal(out.error.code, "PROVIDER_UNAVAILABLE");
      assert.equal(JSON.stringify(out).includes("PRIVATE"), false);
    }
    assert.equal(f.state.reconciliations, 0);
    assert.equal(f.state.claims, 0);
  }
});
test("correlation checker rejects malformed database shape context and borrowed metadata before upstream", async () => {
  for (const bad of ["token", "context", "owner", "receipt", "incomplete"]) {
    const f = fixture();
    f.state.found = (
      bad === "token"
        ? { ...f.state.found, token: "PRIVATE" }
        : bad === "context"
          ? {
              kind: "pending",
              correlation: f.correlation,
              context: {
                ...f.ctx,
                transcript: [{ role: "user", text_ja: "文" }],
              },
            }
          : bad === "incomplete"
            ? { kind: "pending", correlation: f.correlation }
            : {
                kind: "pending",
                context: f.ctx,
                correlation: {
                  ...f.correlation,
                  ...(bad === "owner"
                    ? { user_id: userB }
                    : { receipt_id: "PRIVATE" }),
                },
              }
    ) as ConversationRecoveryLookup;
    await assert.rejects(f.recover(), BoundaryError);
    assert.equal(f.state.providerLookups, 0);
    assert.equal(f.state.reconciliations, 0);
  }
});
test("unknown absent malformed oversized and untrusted lookup errors never reconcile or redispatch", async () => {
  for (const raw of [
    null,
    "not-json",
    "[]",
    "null",
    "PRIVATE".repeat(300000),
  ]) {
    const f = fixture();
    f.lookup.lookupExisting = async () => raw;
    await failure(f.recover());
    assert.equal(f.state.reconciliations, 0);
    assert.equal(f.state.claims, 0);
  }
  const f = fixture();
  f.lookup.lookupExisting = async () => {
    throw Error("PRIVATE credential");
  };
  await failure(f.recover());
  assert.equal(f.state.reconciliations, 0);
});
test("recovered result cannot override reserved session message sequence audio or typed refs", async () => {
  for (const field of ["session", "message", "sequence", "audio", "refs"]) {
    const f = fixture(),
      out = f.state.record.response as Mutable<Responses["start_conversation"]>;
    if (field === "session") out.session_id = userB;
    else if (field === "message") out.assistant_message.id = userB;
    else if (field === "sequence") out.assistant_message.sequence_no = 8;
    else if (field === "audio") out.assistant_message.audio_ref = "PRIVATE";
    else
      (out as unknown as Record<string, unknown>).live_feedback = [
        {
          original_text: "文",
          corrected_text: "文",
          explanation_vi: "fixture",
          item_refs: [{ item_type: "VOCABULARY", item_id: userB }],
        },
      ];
    await failure(f.recover());
    assert.equal(f.state.reconciliations, 0);
  }
});
test("recovery input output byte limits and immutable original casing are enforced", async () => {
  const f = fixture("finish_conversation");
  f.state.record.response = {
    ...(f.response as Mutable<Responses["finish_conversation"]>),
    strengths_vi: Array(100).fill("界".repeat(2000)),
    focus_next_vi: Array(100).fill("界".repeat(2000)),
  };
  await failure(f.recover());
  assert.equal(f.state.reconciliations, 0);
  const g = fixture();
  g.request.client_event_id = "ABCDEF00-0000-4000-8000-000000000001";
  g.key.eventId = g.request.client_event_id.toLowerCase();
  g.correlation.client_event_id = g.key.eventId;
  g.correlation.idempotency_key = `${userA}/${g.key.operation}/${g.key.eventId}`;
  g.state.record.client_event_id = g.key.eventId;
  g.state.record.idempotency_key = g.correlation.idempotency_key;
  g.state.record.request.client_event_id = g.request.client_event_id;
  assert.deepEqual(await g.recover(), g.response);
  g.state.record.request.client_event_id = g.key.eventId;
  await failure(g.recover());
  assert.equal(g.state.reconciliations, 1);
});
test("recovery matches JSON semantics while preserving array and full original request meaning", async () => {
  const f = fixture();
  f.state.record.context = Object.fromEntries(
    Object.entries(f.ctx).reverse(),
  ) as unknown as PreparedContext;
  f.state.record.request = Object.fromEntries(
    Object.entries(f.request).reverse(),
  ) as unknown as Mutable<Requests[Mutation]>;
  assert.deepEqual(await f.recover(), f.response);
});
test("recovery captures database receipt and context before asynchronous upstream and cleans its private signal", async () => {
  const f = fixture();
  let release!: (raw: string) => void;
  let own!: AbortSignal;
  f.lookup.lookupExisting = (input, signal) => {
    own = signal;
    assert.ok(Object.isFrozen(input.context));
    return new Promise((resolve) => {
      release = resolve;
    });
  };
  const work = f.recover();
  await barrier(() => Boolean(release));
  f.correlation.receipt_id = userB;
  (f.ctx as { instruction: string }).instruction = "Changed";
  release(JSON.stringify(f.state.record));
  assert.deepEqual(await work, f.response);
  assert.equal(f.state.reconciliations, 1);
  assert.equal(own.aborted, true);
});
test("runtime captures configured store and lookup before another asynchronous host binding change", async () => {
  const f = fixture();
  let release!: () => void;
  f.store.lookup = () =>
    new Promise((resolve) => {
      release = () => resolve({ kind: "pending" });
    });
  const work = f.run();
  await barrier(() => Boolean(release));
  f.deps.conversationRecovery = {
    store: fixture().store,
    lookup: {
      lookupExisting: async () => assert.fail("late host replacement used"),
    },
  };
  release();
  assert.equal((await work).ok, true);
  assert.equal(f.state.reconciliations, 1);
});
test("recovery waits for reconciliation confirmation and never retries unknown commit delivery", async () => {
  for (const lose of [false, true]) {
    const f = fixture();
    let release!: () => void,
      done = false;
    f.store.reconcile = async () => {
      f.state.reconciliations++;
      await new Promise<void>((resolve) => {
        release = resolve;
      });
      if (lose) throw new BoundaryError("NETWORK_UNAVAILABLE");
    };
    const work = f.recover().then((r) => {
      done = true;
      return r;
    });
    await barrier(() => Boolean(release));
    assert.equal(done, false);
    release();
    if (lose) await failure(work, "NETWORK_UNAVAILABLE");
    else assert.deepEqual(await work, f.response);
    assert.equal(f.state.reconciliations, 1);
    assert.equal(f.state.claims, 0);
  }
});
test("recovery pre-abort opens no port and ignored late store upstream or reconciliation never advances", async () => {
  const f = fixture(),
    aborted = new AbortController();
  aborted.abort();
  await failure(f.recover(10000, aborted.signal));
  assert.equal(f.state.lookups, 0);
  for (const phase of ["store", "upstream", "reconcile"]) {
    const f = fixture(),
      parent = new AbortController();
    let release!: () => void;
    if (phase === "store")
      f.store.lookupRecovery = () =>
        new Promise((resolve) => {
          release = () => resolve(f.state.found);
        });
    else if (phase === "upstream")
      f.lookup.lookupExisting = () =>
        new Promise((resolve) => {
          release = () => resolve(JSON.stringify(f.state.record));
        });
    else
      f.store.reconcile = () => {
        f.state.reconciliations++;
        return new Promise((resolve) => {
          release = resolve;
        });
      };
    const work = f.recover(10000, parent.signal);
    await barrier(() => Boolean(release));
    parent.abort();
    await failure(work);
    const count = f.state.reconciliations;
    release();
    await setImmediate();
    assert.equal(f.state.reconciliations, count);
    assert.equal(f.state.claims, 0);
    assert.equal(getEventListeners(parent.signal, "abort").length, 0);
  }
});
test("independent recovery timeout and monotonic deadline fence ignored or timer-starving upstream results", async () => {
  for (const blocking of [false, true]) {
    const f = fixture();
    let release!: () => void;
    f.lookup.lookupExisting = () => {
      if (blocking) {
        const end = performance.now() + 15;
        while (performance.now() < end) {
          /* starve timers */
        }
        return Promise.resolve(JSON.stringify(f.state.record));
      }
      return new Promise((resolve) => {
        release = () => resolve(JSON.stringify(f.state.record));
      });
    };
    await failure(f.recover(5));
    if (release) {
      release();
      await setImmediate();
    }
    assert.equal(f.state.reconciliations, 0);
  }
});
test("recovery A B A same event stays per-call with no shared identity context or result", async () => {
  const fs = [
    fixture("start_conversation", userA),
    fixture("start_conversation", userB),
    fixture("start_conversation", userA),
  ];
  const outs = await Promise.all(fs.map((f) => f.run()));
  assert.ok(outs.every((o) => o.ok));
  assert.ok(
    fs.every((f) => f.state.reconciliations === 1 && f.state.claims === 0),
  );
  assert.notEqual(fs[0]!.state.completed, fs[2]!.state.completed);
});
test("recovery validates constructor bounds and original key request before any lookup", async () => {
  const f = fixture();
  for (const timeout of [0, -1, NaN, 15001, 1.5])
    assert.throws(
      () =>
        new CorrelatedConversationRecovery(
          contracts,
          f.store,
          f.lookup,
          timeout,
        ),
      { message: "Invalid recovery timeout" },
    );
  f.key.eventId = userB;
  await failure(f.recover(), "SYNC_CONFLICT");
  assert.equal(f.state.lookups, 0);
});
