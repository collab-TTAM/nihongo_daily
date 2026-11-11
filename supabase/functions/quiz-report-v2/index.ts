import { installPostgresNodeGlobals } from "../../../backend/ai/edge/postgres_node_globals.ts";
import {
  createQuizReportV2EdgeHandler,
  readQuizReportV2EdgeConfiguration,
} from "../../../backend/ai/edge/quiz_report_v2_edge.ts";
import schema from "../../../contracts/quiz/v2/schema.json" with {
  type: "json",
};

// pg's CommonJS graph must load only after the actual Node globals are installed.
installPostgresNodeGlobals();

const configuration = readQuizReportV2EdgeConfiguration((name) =>
  Deno.env.get(name)
);
const { createTrustedPostgresQuizReportV2Submitter } = await import(
  "../../../backend/ai/src/quiz_report_v2_host.ts"
);
const { createQuizReportV2HttpHandler } = await import(
  "../../../backend/ai/src/quiz_report_v2_http.ts"
);
const submit = createTrustedPostgresQuizReportV2Submitter(
  schema,
  configuration.trusted,
);
const http = createQuizReportV2HttpHandler(submit);
Deno.serve(
  createQuizReportV2EdgeHandler(http, configuration.allowedOrigins),
);
