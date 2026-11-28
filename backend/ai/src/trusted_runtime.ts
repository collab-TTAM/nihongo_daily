import { BoundaryError, Contracts, operations } from "./contracts.ts";
import type { Operation } from "./contracts.ts";
import type {
  AiProvider,
  AuthVerifier,
  AuthenticatedConversationLookup,
  ReceiptStore,
} from "./ports.ts";
import { AiService } from "./service.ts";
import { createAiHttpHandler } from "./http.ts";
import { SupabaseAuthVerifier } from "./supabase_auth.ts";
import { createOwnedPostgresFactory } from "./postgres_connection.ts";
import type { PostgresConnection } from "./postgres_connection.ts";
import { PostgresQuotaLimiter } from "./postgres_quota.ts";
import { PostgresTextContextRepository } from "./postgres_text_context.ts";
import { PostgresConversationStore } from "./postgres_conversation.ts";

type ConnectionFactory = () => PostgresConnection;
export interface PostgresAiHost {
  readonly auth: AuthVerifier;
  readonly provider: AiProvider;
  readonly connections: {
    readonly quota: ConnectionFactory;
    readonly text: ConnectionFactory;
    readonly conversation: ConnectionFactory;
  };
  /** Already authenticated server lookup only; structural metadata is not proof. */
  readonly recovery?: AuthenticatedConversationLookup;
}
export type AiHttpHandlers = Readonly<
  Record<Operation, (request: Request) => Promise<Response>>
>;

const disabledLegacy = async (): Promise<never> => {
  throw new BoundaryError("INTERNAL_ERROR");
};
const receipts: ReceiptStore = Object.freeze({
  lookup: disabledLegacy,
  claim: disabledLegacy,
  complete: disabledLegacy,
  reconcile: disabledLegacy,
});

/** Host-only composition seam. Factories MUST return fresh exclusively owned
 * connections. Fixture/plaintext ports are never installed by the trusted factory.
 * Captures methods/receivers before I/O; caller still owns provider/lookup resources.
 */
export function assemblePostgresAiHandlers(
  contracts: Contracts,
  host: PostgresAiHost,
): AiHttpHandlers {
  try {
    const authOwner = host.auth,
      providerOwner = host.provider,
      recoveryOwner = host.recovery;
    const verify = authOwner.verify.bind(authOwner),
      generate = providerOwner.generate.bind(providerOwner);
    const connectionOwner = host.connections;
    const quotaFactory = connectionOwner.quota.bind(connectionOwner),
      textFactory = connectionOwner.text.bind(connectionOwner),
      conversationFactory = connectionOwner.conversation.bind(connectionOwner);
    if (
      [quotaFactory, textFactory, conversationFactory].some(
        (f) => typeof f !== "function",
      )
    )
      throw new Error();
    const lookup = recoveryOwner
      ? Object.freeze({
          lookupExisting: recoveryOwner.lookupExisting.bind(recoveryOwner),
        })
      : undefined;
    const conversations = new PostgresConversationStore(
      contracts,
      conversationFactory,
    );
    const service = new AiService(
      contracts,
      Object.freeze({
        auth: Object.freeze({ verify }),
        provider: Object.freeze({ generate }),
        limiter: new PostgresQuotaLimiter(quotaFactory),
        context: new PostgresTextContextRepository(contracts, textFactory),
        conversations,
        receipts,
        ...(lookup
          ? {
              conversationRecovery: Object.freeze({
                store: conversations,
                lookup,
              }),
            }
          : {}),
      }),
    );
    return Object.freeze(
      Object.fromEntries(
        operations.map((op) => [op, createAiHttpHandler(service, op)]),
      ),
    ) as AiHttpHandlers;
  } catch {
    throw new Error("Invalid trusted AI host bindings");
  }
}

/** Explicit trusted deployment configuration only; no environment/default server,
 * listener, provider selection, SDK session ownership or learner URL/key input.
 * All connections retain mandatory verified TLS and their own short transactions.
 */
export function createTrustedPostgresAiHandlers(
  contracts: Contracts,
  configuration: Readonly<{
    projectUrl: string;
    publicKey: string;
    databaseUrl: string;
  }>,
  provider: AiProvider,
  recovery?: AuthenticatedConversationLookup,
): AiHttpHandlers {
  try {
    const { projectUrl, publicKey, databaseUrl } = configuration;
    return assemblePostgresAiHandlers(contracts, {
      auth: new SupabaseAuthVerifier(projectUrl, publicKey),
      provider,
      connections: {
        quota: createOwnedPostgresFactory(databaseUrl, "nihongo-ai-quota"),
        text: createOwnedPostgresFactory(
          databaseUrl,
          "nihongo-ai-text-context",
        ),
        conversation: createOwnedPostgresFactory(
          databaseUrl,
          "nihongo-ai-conversation",
        ),
      },
      ...(recovery ? { recovery } : {}),
    });
  } catch {
    throw new Error("Invalid trusted AI server configuration");
  }
}
