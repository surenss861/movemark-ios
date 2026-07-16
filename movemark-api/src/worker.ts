import { assertEnv } from "./lib/env.js";
import {
  claimExportJobs,
  processClaimedJobs,
  reapStuckExportJobs,
} from "./lib/exportJobProcessor.js";
import { captureException, initSentry } from "./lib/sentry.js";

assertEnv();
initSentry();

const POLL_MS = Number(process.env.EXPORT_WORKER_POLL_MS ?? 1500);
const CLAIM_BATCH = Number(process.env.EXPORT_WORKER_CLAIM_BATCH ?? 2);
const JOB_CONCURRENCY = Number(process.env.EXPORT_WORKER_JOB_CONCURRENCY ?? 1);
const REAP_EVERY_N_LOOPS = Number(process.env.EXPORT_WORKER_REAP_EVERY ?? 20);

let stopping = false;
let loops = 0;

async function sleep(ms: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function tick(): Promise<void> {
  loops += 1;
  if (loops % REAP_EVERY_N_LOOPS === 0) {
    const reaped = await reapStuckExportJobs();
    if (reaped > 0) {
      console.log(`[movemark-api:worker] reaped=${reaped}`);
    }
  }

  const jobs = await claimExportJobs(CLAIM_BATCH);
  if (jobs.length === 0) return;

  console.log(`[movemark-api:worker] claimed=${jobs.length}`);
  await processClaimedJobs(jobs, JOB_CONCURRENCY);
}

async function main(): Promise<void> {
  console.log(
    `[movemark-api:worker] starting pollMs=${POLL_MS} claimBatch=${CLAIM_BATCH} jobConcurrency=${JOB_CONCURRENCY}`
  );

  while (!stopping) {
    try {
      await tick();
    } catch (error) {
      console.error("[movemark-api:worker] tick error", error);
      captureException(error);
    }
    if (stopping) break;
    await sleep(POLL_MS);
  }

  console.log("[movemark-api:worker] stopped");
  process.exit(0);
}

function shutdown(signal: string) {
  console.log(`[movemark-api:worker] ${signal} received — draining`);
  stopping = true;
  setTimeout(() => process.exit(1), 30_000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("uncaughtException", (error) => {
  console.error("[movemark-api:worker] uncaughtException", error);
  captureException(error);
});
process.on("unhandledRejection", (reason) => {
  console.error("[movemark-api:worker] unhandledRejection", reason);
  captureException(reason);
});

void main();
