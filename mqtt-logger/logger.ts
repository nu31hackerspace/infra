import mqtt, { MqttClient } from "mqtt";
import { Pool } from "pg";

function requireEnv(name: string): string {
  const val = process.env[name];
  if (!val) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(1);
  }
  return val;
}

const MQTT_HOST     = process.env.MQTT_HOST  ?? "mqtt";
const MQTT_PORT     = parseInt(process.env.MQTT_PORT ?? "1883", 10);
const MQTT_USER     = requireEnv("MQTT_USER");
const MQTT_PASSWORD = requireEnv("MQTT_PASSWORD");
const MQTT_TOPIC    = process.env.MQTT_TOPIC ?? "#";

const pool = new Pool({
  host:     process.env.PGHOST     ?? "postgres-1",
  port:     parseInt(process.env.PGPORT ?? "5432", 10),
  user:     requireEnv("PGUSER"),
  password: requireEnv("PGPASSWORD"),
  database: process.env.PGDATABASE ?? "mqtt_store",
});

const CREATE_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS mqtt_messages (
    id          BIGSERIAL   PRIMARY KEY,
    topic       TEXT        NOT NULL,
    payload     BYTEA,
    qos         SMALLINT    NOT NULL,
    retain      BOOLEAN     NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
`;

async function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function initDb(): Promise<void> {
  while (true) {
    try {
      await pool.query(CREATE_TABLE_SQL);
      console.log(`[pg] Connected to ${pool.options.host}/${pool.options.database}, table ready.`);
      return;
    } catch (err) {
      console.warn(`[pg] Not ready (${(err as Error).message}), retrying in 5s…`);
      await sleep(5000);
    }
  }
}

function startMqtt(): void {
  const client: MqttClient = mqtt.connect(`mqtt://${MQTT_HOST}:${MQTT_PORT}`, {
    username: MQTT_USER,
    password: MQTT_PASSWORD,
    reconnectPeriod: 5000,
  });

  client.on("connect", () => {
    console.log(`[mqtt] Connected to ${MQTT_HOST}:${MQTT_PORT}, subscribing to '${MQTT_TOPIC}'`);
    client.subscribe(MQTT_TOPIC, { qos: 1 }, (err) => {
      if (err) console.error("[mqtt] Subscribe error:", err.message);
    });
  });

  client.on("message", (topic, payload, packet) => {
    pool
      .query(
        "INSERT INTO mqtt_messages (topic, payload, qos, retain) VALUES ($1, $2, $3, $4)",
        [topic, payload, packet.qos, packet.retain],
      )
      .catch((err: Error) =>
        console.error(`[mqtt] Failed to store '${topic}': ${err.message}`),
      );
  });

  client.on("error",     (err) => console.error("[mqtt] Error:", err.message));
  client.on("reconnect", ()    => console.log("[mqtt] Reconnecting…"));
}

async function main(): Promise<void> {
  await initDb();
  startMqtt();
}

main();
