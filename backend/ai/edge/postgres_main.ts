// TEST ONLY supervisor; fixed full PostgreSQL fixture user worker, no host env.
// Pinned API/limits match the retained v1.77.4 memory-port supervisor.
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
    return Response.json(
      { fixtureOnly: true, error: "EDGE_PG_WORKER_FAILED" },
      {
        status: 502,
      },
    );
  }
});
