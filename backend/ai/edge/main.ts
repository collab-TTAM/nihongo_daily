// TEST ONLY supervisor; fixed bundled user service, no environment forwarding/retry.
// API: supabase/edge-runtime v1.77.4 examples/main/index.ts + types/global.d.ts.
type Worker = {
  fetch(request: Request, options: { signal: AbortSignal }): Promise<Response>;
};
const runtime = (globalThis as unknown as {
  EdgeRuntime: {
    userWorkers: {
      create(options: {
        noNpm: boolean;
        allowRemoteModules: boolean;
        servicePath: string;
        memoryLimitMb: number;
        workerTimeoutMs: number;
        noModuleCache: boolean;
        envVars: string[][];
        forceCreate: boolean;
        cpuTimeSoftLimitMs: number;
        cpuTimeHardLimitMs: number;
      }): Promise<Worker>;
    };
  };
}).EdgeRuntime;
Deno.serve(async (request) => {
  try {
    const worker = await runtime.userWorkers.create({
      servicePath: "/probe/worker",
      noNpm: true,
      allowRemoteModules: false,
      memoryLimitMb: 150,
      workerTimeoutMs: 60000,
      noModuleCache: false,
      envVars: [],
      forceCreate: false,
      cpuTimeSoftLimitMs: 10000,
      cpuTimeHardLimitMs: 20000,
    });
    return await worker.fetch(request, { signal: request.signal });
  } catch {
    // No upstream exception/URL/token/request content in response or logs.
    return Response.json({
      fixtureOnly: true,
      error: "EDGE_USER_WORKER_FAILED",
    }, { status: 502 });
  }
});
