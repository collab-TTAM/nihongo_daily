import { BoundaryError, UUID } from "./contracts.ts";
import type { AuthVerifier } from "./ports.ts";

const maxBytes = 65536;
const unavailable = () => new BoundaryError("NETWORK_UNAVAILABLE");
const cancelBody = (response: Response) => {
  void response.body?.cancel().catch(() => {});
};

async function untilAbort<T>(
  work: Promise<T>,
  signal: AbortSignal,
): Promise<T> {
  if (signal.aborted) {
    void work.catch(() => {});
    throw unavailable();
  }
  let abort: (() => void) | undefined;
  try {
    return await new Promise<T>((resolve, reject) => {
      abort = () => reject(unavailable());
      signal.addEventListener("abort", abort, { once: true });
      void work.then(resolve, reject);
    });
  } finally {
    if (abort) signal.removeEventListener("abort", abort);
  }
}

function configuration(projectUrl: string, publicKey: string): string {
  try {
    const url = new URL(projectUrl);
    if (
      projectUrl.length > 2048 ||
      projectUrl !== projectUrl.trim() ||
      url.protocol !== "https:" ||
      url.username ||
      url.password ||
      url.pathname !== "/" ||
      url.search ||
      url.hash ||
      projectUrl.includes("?") ||
      projectUrl.includes("#") ||
      publicKey.length > 8192 ||
      !/^[A-Za-z0-9_.-]+$/.test(publicKey)
    )
      throw new Error();
    if (!/^sb_publishable_[A-Za-z0-9_-]{10,200}$/.test(publicKey)) {
      const parts = publicKey.split(".");
      if (parts.length !== 3 || parts.some((part) => !part)) throw new Error();
      // Classification of a trusted PUBLIC configuration key only. Never use
      // decoded learner JWT claims as identity or authorization evidence.
      const payload: unknown = JSON.parse(
        atob(parts[1]!.replace(/-/g, "+").replace(/_/g, "/")),
      );
      if (
        !payload ||
        typeof payload !== "object" ||
        !("role" in payload) ||
        payload.role !== "anon"
      )
        throw new Error();
    }
    return new URL("/auth/v1/user", url.origin).href;
  } catch {
    throw new Error("Invalid trusted Supabase public configuration");
  }
}

async function readIdentity(
  response: Response,
  signal: AbortSignal,
  alive: () => void,
): Promise<{ id: string }> {
  if (!response.body || response.bodyUsed || response.body.locked)
    throw unavailable();
  const reader = response.body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
  const parts: string[] = [];
  let bytes = 0;
  let reads = 0;
  let complete = false;
  try {
    while (true) {
      alive();
      if (++reads > maxBytes + 1) throw unavailable();
      const { done, value } = await untilAbort(reader.read(), signal);
      alive();
      if (done) {
        complete = true;
        break;
      }
      if (!(value instanceof Uint8Array)) throw unavailable();
      bytes += value.byteLength;
      if (bytes > maxBytes) throw unavailable();
      if (value.byteLength) parts.push(decoder.decode(value, { stream: true }));
    }
    parts.push(decoder.decode());
    const value: unknown = JSON.parse(parts.join(""));
    alive();
    if (
      !value ||
      typeof value !== "object" ||
      Array.isArray(value) ||
      !("id" in value) ||
      typeof value.id !== "string" ||
      !UUID.test(value.id) ||
      !("aud" in value) ||
      value.aud !== "authenticated"
    )
      throw unavailable();
    return { id: value.id.toLowerCase() };
  } finally {
    if (!complete) void reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

/** Server-only, opt-in Auth port; no SDK session/cache/refresh ownership.
 * Supabase Auth at the trusted project verifies the caller's access token.
 * Deployment configuration and fetch implementation must never be learner input.
 */
export class SupabaseAuthVerifier implements AuthVerifier {
  private readonly endpoint: string;
  private readonly publicKey: string;
  private readonly fetcher: typeof fetch;
  private readonly timeoutMs: number;
  constructor(
    projectUrl: string,
    publicKey: string,
    fetcher: typeof fetch = fetch,
    timeoutMs = 5000,
  ) {
    this.endpoint = configuration(projectUrl, publicKey);
    this.publicKey = publicKey;
    this.fetcher = fetcher;
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000)
      throw new Error("Invalid Auth timeout");
    this.timeoutMs = timeoutMs;
  }
  async verify(
    bearer: string,
    signal: AbortSignal,
  ): Promise<{ id: string } | null> {
    if (
      !bearer ||
      bearer.length > 8192 ||
      !/^[A-Za-z0-9._~+/-]+=*$/.test(bearer)
    )
      return null;
    const controller = new AbortController();
    const stop = () => controller.abort();
    const deadline = performance.now() + this.timeoutMs;
    const alive = () => {
      if (performance.now() >= deadline) stop();
      if (controller.signal.aborted) throw unavailable();
    };
    const timer = setTimeout(stop, this.timeoutMs);
    signal.addEventListener("abort", stop, { once: true });
    let response: Response | undefined;
    try {
      if (signal.aborted) stop();
      alive();
      const pending = this.fetcher(this.endpoint, {
        method: "GET",
        redirect: "error",
        cache: "no-store",
        credentials: "omit",
        headers: {
          apikey: this.publicKey,
          authorization: `Bearer ${bearer}`,
          accept: "application/json",
        },
        signal: controller.signal,
      }).then((value) => {
        if (controller.signal.aborted) {
          cancelBody(value);
          throw unavailable();
        }
        return value;
      });
      response = await untilAbort(pending, controller.signal);
      alive();
      if (
        response.redirected ||
        (response.url && response.url !== this.endpoint)
      )
        throw unavailable();
      if (response.status === 401 || response.status === 403) return null;
      if (response.status === 429) throw new BoundaryError("RATE_LIMITED");
      if (response.status !== 200) throw unavailable();
      if (
        !/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(
          response.headers.get("content-type") ?? "",
        )
      )
        throw unavailable();
      const identity = await readIdentity(response, controller.signal, alive);
      alive();
      return identity;
    } catch (error) {
      if (error instanceof BoundaryError) throw error;
      throw unavailable();
    } finally {
      clearTimeout(timer);
      signal.removeEventListener("abort", stop);
      stop();
      if (response) cancelBody(response);
    }
  }
}
