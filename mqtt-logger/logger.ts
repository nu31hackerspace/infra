// Subscribes to every topic of the broker and keeps the last RETENTION_HOURS of
// messages in PostgreSQL, so Grafana can show the history of any topic.
//
// Messages are buffered and written in batches, and rows older than the
// retention window are deleted periodically, so the table never grows
// unbounded (that is what got the previous version of this service removed).

import mqtt from "mqtt";
import { Client, Pool, escapeIdentifier, escapeLiteral } from "pg";

function requireEnv(name: string): string {
  const val = process.env[name];
  if (!val) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(1);
  }
  return val;
}

const MQTT_URL      = process.env.MQTT_URL ?? "mqtt://mqtt:1883";
const MQTT_USER     = requireEnv("MQTT_USER");
const MQTT_PASSWORD = requireEnv("MQTT_PASSWORD");
const MQTT_TOPIC    = process.env.MQTT_TOPIC ?? "#";

const PG_DATABASE = process.env.PGDATABASE ?? "mqtt_store";
const PG_CONFIG = {
  host:     process.env.PGHOST ?? "postgres-1",
  port:     parseInt(process.env.PGPORT ?? "5432", 10),
  user:     requireEnv("PGUSER"),
  password: requireEnv("PGPASSWORD"),
};

// Read-only role used by the Grafana datasource. Grafana editors can run any
// SQL from Explore, so the datasource must not use the superuser.
const READER_USER     = process.env.READER_USER;
const READER_PASSWORD = process.env.READER_PASSWORD;

const RETENTION_HOURS   = parseInt(process.env.RETENTION_HOURS ?? "24", 10);
const CLEANUP_EVERY_MS  = 10 * 60 * 1000;
const FLUSH_EVERY_MS    = 1000;
const FLUSH_BATCH_SIZE  = 500;
// Upper bound of buffered messages while postgres is unreachable, so an
// outage can't run the container out of memory.
const MAX_BUFFERED      = 50_000;

const SCHEMA_SQL = `
  CREATE TABLE IF NOT EXISTS mqtt_history (
    id          BIGSERIAL   PRIMARY KEY,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    topic       TEXT        NOT NULL,
    payload     TEXT        NOT NULL,
    qos         SMALLINT    NOT NULL,
    retain      BOOLEAN     NOT NULL
  );
  CREATE INDEX IF NOT EXISTS mqtt_history_received_at_idx
    ON mqtt_history (received_at);
  CREATE INDEX IF NOT EXISTS mqtt_history_topic_received_at_idx
    ON mqtt_history (topic, received_at);

  -- MQTT topic filter matching, so dashboards can filter with the same syntax
  -- as a subscription: '#', 'prismo/#', 'sensors/+/temperature', 'a/b'.
  CREATE OR REPLACE FUNCTION mqtt_topic_matches(topic TEXT, filter TEXT)
  RETURNS BOOLEAN LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $fn$
    SELECT CASE
      WHEN filter IS NULL OR filter = '' OR filter = '#' THEN TRUE
      ELSE topic ~ (
        '^' ||
        replace(
          replace(
            regexp_replace(filter, '([.^$*?()\\[\\]{}|\\\\])', '\\\\\\1', 'g'),
            '+', '[^/]*'),
          '/#', '(/.*)?')
        || '$')
    END
  $fn$;
`;

interface Row {
  receivedAt: Date;
  topic: string;
  payload: string;
  qos: number;
  retain: boolean;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function retry<T>(what: string, fn: () => Promise<T>): Promise<T> {
  while (true) {
    try {
      return await fn();
    } catch (err) {
      console.warn(`[pg] ${what} failed (${(err as Error).message}), retrying in 5s...`);
      await sleep(5000);
    }
  }
}

async function ensureDatabase(): Promise<void> {
  const client = new Client({ ...PG_CONFIG, database: "postgres" });
  await client.connect();
  try {
    const { rowCount } = await client.query("SELECT 1 FROM pg_database WHERE datname = $1", [PG_DATABASE]);
    if (!rowCount) {
      console.log(`[pg] Creating database ${PG_DATABASE}`);
      await client.query(`CREATE DATABASE ${escapeIdentifier(PG_DATABASE)}`);
    }
  } finally {
    await client.end();
  }
}

async function ensureReader(pool: Pool): Promise<void> {
  if (!READER_USER || !READER_PASSWORD) {
    console.log("[pg] READER_USER/READER_PASSWORD not set, skipping read-only role.");
    return;
  }
  const role = escapeIdentifier(READER_USER);
  const { rowCount } = await pool.query("SELECT 1 FROM pg_roles WHERE rolname = $1", [READER_USER]);
  if (!rowCount) await pool.query(`CREATE ROLE ${role} LOGIN`);
  await pool.query(`ALTER ROLE ${role} WITH LOGIN PASSWORD ${escapeLiteral(READER_PASSWORD)}`);
  // A heavy dashboard query must not hold the database for long.
  await pool.query(`ALTER ROLE ${role} SET statement_timeout = '30s'`);
  await pool.query(`GRANT CONNECT ON DATABASE ${escapeIdentifier(PG_DATABASE)} TO ${role}`);
  await pool.query(`GRANT USAGE ON SCHEMA public TO ${role}`);
  await pool.query(`GRANT SELECT ON mqtt_history TO ${role}`);
  console.log(`[pg] Read-only role ${READER_USER} ready.`);
}

async function main(): Promise<void> {
  await retry("create database", ensureDatabase);

  const pool = new Pool({ ...PG_CONFIG, database: PG_DATABASE, max: 3 });
  pool.on("error", (err) => console.error("[pg] Idle client error:", err.message));

  await retry("create schema", () => pool.query(SCHEMA_SQL));
  await retry("create reader role", () => ensureReader(pool));
  console.log(`[pg] Connected to ${PG_CONFIG.host}/${PG_DATABASE}, keeping ${RETENTION_HOURS}h of messages.`);

  let buffer: Row[] = [];
  let flushing = false;

  async function flush(): Promise<void> {
    if (flushing || buffer.length === 0) return;
    flushing = true;
    try {
      while (buffer.length > 0) {
        const batch = buffer.slice(0, FLUSH_BATCH_SIZE);
        await pool.query(
          `INSERT INTO mqtt_history (received_at, topic, payload, qos, retain)
           SELECT * FROM unnest($1::timestamptz[], $2::text[], $3::text[], $4::smallint[], $5::boolean[])`,
          [
            batch.map((r) => r.receivedAt),
            batch.map((r) => r.topic),
            batch.map((r) => r.payload),
            batch.map((r) => r.qos),
            batch.map((r) => r.retain),
          ],
        );
        buffer = buffer.slice(batch.length);
      }
    } catch (err) {
      console.error(`[pg] Insert failed, ${buffer.length} messages buffered: ${(err as Error).message}`);
    } finally {
      flushing = false;
    }
  }

  async function cleanup(): Promise<void> {
    try {
      const { rowCount } = await pool.query(
        "DELETE FROM mqtt_history WHERE received_at < now() - make_interval(hours => $1)",
        [RETENTION_HOURS],
      );
      if (rowCount) console.log(`[pg] Deleted ${rowCount} messages older than ${RETENTION_HOURS}h.`);
    } catch (err) {
      console.error("[pg] Cleanup failed:", (err as Error).message);
    }
  }

  const flushTimer = setInterval(flush, FLUSH_EVERY_MS);
  const cleanupTimer = setInterval(cleanup, CLEANUP_EVERY_MS);
  await cleanup();

  const client = mqtt.connect(MQTT_URL, {
    username: MQTT_USER,
    password: MQTT_PASSWORD,
    clientId: `mqtt-logger-${Math.random().toString(16).slice(2, 10)}`,
    reconnectPeriod: 5000,
  });

  client.on("connect", () => {
    console.log(`[mqtt] Connected to ${MQTT_URL}, subscribing to '${MQTT_TOPIC}'`);
    client.subscribe(MQTT_TOPIC, { qos: 1 }, (err, granted) => {
      if (err) return console.error("[mqtt] Subscribe error:", err.message);
      // 128 is the SUBACK failure code, e.g. when the ACL denies the subscription.
      if (granted?.some((g) => g.qos === 128)) console.error(`[mqtt] Subscription to '${MQTT_TOPIC}' rejected by broker.`);
    });
  });

  client.on("message", (topic, payload, packet) => {
    if (buffer.length >= MAX_BUFFERED) buffer.shift();
    buffer.push({
      receivedAt: new Date(),
      topic,
      // Postgres text can't hold NUL bytes; binary payloads end up lossy, which
      // is fine for a debugging history.
      payload: payload.toString("utf8").replace(/\u0000/g, ""),
      qos: packet.qos,
      retain: packet.retain,
    });
    if (buffer.length >= FLUSH_BATCH_SIZE) void flush();
  });

  client.on("error", (err) => console.error("[mqtt] Error:", err.message));
  client.on("reconnect", () => console.log("[mqtt] Reconnecting..."));

  const shutdown = async (signal: string) => {
    console.log(`[app] ${signal} received, flushing and exiting.`);
    clearInterval(flushTimer);
    clearInterval(cleanupTimer);
    await new Promise<void>((resolve) => client.end(false, {}, () => resolve()));
    while (flushing) await sleep(50);
    await flush();
    await pool.end();
    process.exit(0);
  };
  process.on("SIGTERM", () => void shutdown("SIGTERM"));
  process.on("SIGINT", () => void shutdown("SIGINT"));
}

main().catch((err) => {
  console.error("[app] Fatal:", err);
  process.exit(1);
});
