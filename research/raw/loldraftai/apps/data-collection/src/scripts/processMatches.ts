import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import Bottleneck from "bottleneck";
import { sleep } from "../utils";
import { RegionSchema } from "@draftking/riot-api";
import { RiotAPIClient } from "@draftking/riot-api";
import { Match, PrismaClient, Prisma } from "@draftking/riot-database";
import { config } from "dotenv";
import { processMatchData } from "../utils/matchProcessing";
import { telemetry } from "../utils/telemetry";
import { DatabaseBackoff } from "../utils/databaseErrorHandling";

config();

// Enhance logging to always show timestamp and add log levels
const log = (level: "INFO" | "ERROR" | "DEBUG", message: string) => {
  //console.log(`[${new Date().toISOString()}] [${level}] ${message}`);
};

const argv = await yargs(hideBin(process.argv))
  .option("region", {
    type: "string",
    demandOption: true,
    describe: "The region to fetch PUUIDs for",
  })
  .parse();

log("INFO", `Starting processMatches for region: ${argv.region}`);

const region = RegionSchema.parse(argv.region);
const apiKey = process.env.X_RIOT_API_KEY;

if (!apiKey) {
  throw new Error("X_RIOT_API_KEY is not set");
}

const riotApiClient = new RiotAPIClient(apiKey, region);
const prisma = new PrismaClient();

// Rate limiter settings
const limiter = new Bottleneck({
  minTime: 100,
  reservoir: 100,
  reservoirRefreshAmount: 100,
  reservoirRefreshInterval: 10 * 1000,
  maxConcurrent: 20,
});

// Database rate limiter
const dbLimiter = new Bottleneck({
  minTime: 100,
  maxConcurrent: 20,
});

let isShuttingDown = false;

// Add rate limiter monitoring
limiter.on("depleted", () => {
  log(
    "INFO",
    `Rate limit depleted - Current reservoir: ${limiter.currentReservoir}`
  );
});

limiter.on("failed", (error) => {
  log("ERROR", `Rate limiter failed: ${error}`);
});

// Add signal handlers
process.on("SIGTERM", () => {
  log("INFO", "Received SIGTERM signal");
  isShuttingDown = true;
});

process.on("SIGINT", () => {
  log("INFO", "Received SIGINT signal");
  isShuttingDown = true;
});

const dbBackoff = new DatabaseBackoff();

// Modify updateMatchWithRawSQL to use DatabaseBackoff
async function updateMatchWithRawSQL(
  matchId: string,
  data: {
    processed: boolean;
    processingErrored?: boolean;
    queueId?: number;
    gameDuration?: number;
    gameStartTimestamp?: Date;
    gameVersionMajorPatch?: number;
    gameVersionMinorPatch?: number;
    teams?: any;
  }
) {
  return dbBackoff.withRetry(async () => {
    let query = 'UPDATE "Match" SET "processed" = $1';
    const params: any[] = [data.processed];
    let paramIndex = 2;

    if (data.processingErrored !== undefined) {
      query += `, "processingErrored" = $${paramIndex}`;
      params.push(data.processingErrored);
      paramIndex++;
    }

    if (data.queueId !== undefined) {
      query += `, "queueId" = $${paramIndex}`;
      params.push(data.queueId);
      paramIndex++;
    }

    if (data.gameDuration !== undefined) {
      query += `, "gameDuration" = $${paramIndex}`;
      params.push(data.gameDuration);
      paramIndex++;
    }

    if (data.gameStartTimestamp !== undefined) {
      query += `, "gameStartTimestamp" = $${paramIndex}`;
      params.push(data.gameStartTimestamp);
      paramIndex++;
    }

    if (data.gameVersionMajorPatch !== undefined) {
      query += `, "gameVersionMajorPatch" = $${paramIndex}`;
      params.push(data.gameVersionMajorPatch);
      paramIndex++;
    }

    if (data.gameVersionMinorPatch !== undefined) {
      query += `, "gameVersionMinorPatch" = $${paramIndex}`;
      params.push(data.gameVersionMinorPatch);
      paramIndex++;
    }

    if (data.teams !== undefined) {
      query += `, "teams" = $${paramIndex}`;
      params.push(data.teams);
      paramIndex++;
    }

    query += `, "updatedAt" = NOW() WHERE id = $${paramIndex}`;
    params.push(matchId);

    await prisma.$executeRawUnsafe(query, ...params);
  }, log); // Pass the log function to use our custom logger
}

async function processMatches() {
  log("INFO", "processMatches function started");
  try {
    // Get the maximum runtime in minutes
    const maxRuntimeMinutes = parseInt(
      process.env.MAX_RUNTIME_MINUTES || "1075"
    );
    const startTime = Date.now();
    const endTime = startTime + maxRuntimeMinutes * 60 * 1000;

    log(
      "INFO",
      `Will run for ${maxRuntimeMinutes} minutes (${(
        maxRuntimeMinutes / 60
      ).toFixed(2)} hours) until ${new Date(endTime).toISOString()}`
    );

    let nextMatchesPromise: Promise<Match[]> | null = null;
    let iterationCount = 0;

    while (!isShuttingDown) {
      // Check if we've exceeded our runtime
      if (Date.now() >= endTime) {
        log(
          "INFO",
          `Reached maximum runtime of ${maxRuntimeMinutes} minutes, exiting`
        );
        break;
      }

      iterationCount++;
      log(
        "DEBUG",
        `Starting iteration ${iterationCount} of main processing loop`
      );

      try {
        log("DEBUG", "Fetching next batch of matches");

        // Fetch matches with retry
        const matches = await dbBackoff.withRetry(async () => {
          return (
            nextMatchesPromise ??
            (prisma.$queryRaw`
              SELECT *
              FROM "Match"
              WHERE processed = false 
              AND "processingErrored" = false
              AND region = ${region}::text::"Region"
              LIMIT 500
            ` as Promise<Match[]>)
          );
        }, log);

        log("INFO", `Found ${matches.length} matches to process`);

        // Start fetching next batch immediately
        const currentlyProcessingIds = matches.map((m) => m.id);
        log(
          "DEBUG",
          `Pre-fetching next batch, excluding ${currentlyProcessingIds.length} currently processing IDs`
        );

        // Wrap the next batch query in withRetry as well
        nextMatchesPromise = dbBackoff.withRetry(async () => {
          if (currentlyProcessingIds.length === 0) {
            return prisma.$queryRaw`
              SELECT *
              FROM "Match"
              WHERE processed = false 
              AND "processingErrored" = false
              AND region = ${region}::text::"Region"
              LIMIT 500
            ` as Promise<Match[]>;
          } else {
            const idList = currentlyProcessingIds
              .map((id) => `'${id}'`)
              .join(",");

            return prisma.$queryRaw`
              SELECT *
              FROM "Match"
              WHERE processed = false 
              AND "processingErrored" = false
              AND region = ${region}::text::"Region"
              AND id NOT IN (${Prisma.raw(idList)})
              LIMIT 500
            ` as Promise<Match[]>;
          }
        }, log);

        if (matches.length === 0) {
          log("INFO", "No matches found, sleeping for 60 seconds");
          await sleep(60 * 1000);
          log("DEBUG", "Waking up from sleep");
          continue;
        }

        // Process matches in parallel
        log(
          "DEBUG",
          `Starting parallel processing of ${matches.length} matches`
        );
        const startTime = Date.now();

        await Promise.all(
          matches.map(async (match) => {
            log("DEBUG", `Processing match ${match.matchId}`);

            try {
              const apiStart = Date.now();
              const processedData = await processMatchData(
                riotApiClient,
                match.matchId,
                limiter
              );
              log(
                "DEBUG",
                `API call completed in ${Date.now() - apiStart}ms for match ${
                  match.matchId
                }`
              );

              if (
                processedData.queueId !== 420 &&
                processedData.queueId !== 700
              ) {
                log(
                  "INFO",
                  `Skipping non-ranked/clash match ${match.matchId} (queueId: ${processedData.queueId})`
                );

                await dbLimiter.schedule(async () => {
                  await updateMatchWithRawSQL(match.id, {
                    processed: true,
                    processingErrored: true,
                    queueId: processedData.queueId,
                  });
                });

                return;
              }

              const updateStart = Date.now();

              await dbLimiter.schedule(async () => {
                await updateMatchWithRawSQL(match.id, {
                  processed: true,
                  gameDuration: processedData.gameDuration,
                  gameStartTimestamp: new Date(
                    processedData.gameStartTimestamp
                  ),
                  queueId: processedData.queueId,
                  gameVersionMajorPatch: processedData.gameVersionMajorPatch,
                  gameVersionMinorPatch: processedData.gameVersionMinorPatch,
                  teams: processedData.teams,
                });
              });

              log(
                "DEBUG",
                `Database update completed in ${
                  Date.now() - updateStart
                }ms for match ${match.matchId}`
              );

              telemetry.trackEvent("MatchesProcessed", {
                count: 1,
                region,
              });
            } catch (error) {
              log("ERROR", `Error processing match ${match.matchId}: ${error}`);

              try {
                await dbLimiter.schedule(async () => {
                  await updateMatchWithRawSQL(match.id, {
                    processed: true,
                    processingErrored: true,
                  });
                });
                log("DEBUG", `Marked match ${match.matchId} as errored`);
              } catch (updateError) {
                log(
                  "ERROR",
                  `Failed to mark match ${match.matchId} as errored: ${updateError}`
                );
              }
            }
          })
        );

        log(
          "INFO",
          `Completed batch processing in ${Date.now() - startTime}ms`
        );
      } catch (batchError) {
        log("ERROR", `Error processing batch: ${batchError}`);
        await dbBackoff.handleDatabaseError(batchError, log);
        await sleep(5000);
      }
    }
  } catch (error) {
    log("ERROR", `Fatal error in processMatches: ${error}`);
  } finally {
    log("INFO", "Disconnecting from database");
    await prisma.$disconnect();
    log("INFO", "Database disconnected");
  }
}

// Properly handle the promise
log("INFO", "Starting main process");
processMatches().catch((error) => {
  log("ERROR", `Unhandled error in main process: ${error}`);
  process.exitCode = 1;
});
