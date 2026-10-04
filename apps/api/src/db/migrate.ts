import "dotenv/config";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { pool } from "./client.js";

type Migration = {
  filename: string;
  sql: string;
};

const migrationsDirectory = path.resolve(
  process.cwd(),
  "migrations",
);

async function loadMigrations(): Promise<Migration[]> {
  console.log(`Looking for migrations in: ${migrationsDirectory}`);

  const files = (await readdir(migrationsDirectory))
    .filter((file) => file.endsWith(".sql"))
    .sort();

  console.log(`Found ${files.length} migration file(s).`);

  return Promise.all(
    files.map(async (filename) => ({
      filename,
      sql: await readFile(
        path.join(migrationsDirectory, filename),
        "utf8",
      ),
    })),
  );
}

async function ensureMigrationsTable(): Promise<void> {
  console.log("Checking schema_migrations table...");

  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      filename VARCHAR(255) NOT NULL UNIQUE,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  console.log("schema_migrations table ready.");
}

async function getAppliedMigrations(): Promise<Set<string>> {
  const result = await pool.query<{ filename: string }>(
    "SELECT filename FROM schema_migrations ORDER BY filename",
  );

  return new Set(
    result.rows.map((row) => row.filename),
  );
}

async function showStatus(): Promise<void> {
  await ensureMigrationsTable();

  const migrations = await loadMigrations();
  const applied = await getAppliedMigrations();

  if (migrations.length === 0) {
    console.log("No migrations found.");
    return;
  }

  for (const migration of migrations) {
    console.log(
      `${applied.has(migration.filename) ? "APPLIED" : "PENDING"}  ${migration.filename}`,
    );
  }
}

async function migrate(): Promise<void> {
  console.log("Starting migration runner...");

  await ensureMigrationsTable();

  const migrations = await loadMigrations();
  const applied = await getAppliedMigrations();

  let appliedCount = 0;

  for (const migration of migrations) {
    if (applied.has(migration.filename)) {
      console.log(`Skipping ${migration.filename} - already applied.`);
      continue;
    }

    console.log(`Applying ${migration.filename}...`);

    const client = await pool.connect();

    try {
      await client.query("BEGIN");
      await client.query(migration.sql);

      await client.query(
        "INSERT INTO schema_migrations (filename) VALUES ($1)",
        [migration.filename],
      );

      await client.query("COMMIT");

      console.log(`Applied ${migration.filename}`);
      appliedCount += 1;
    } catch (error) {
      await client.query("ROLLBACK");
      console.error(`Failed to apply ${migration.filename}`);
      throw error;
    } finally {
      client.release();
    }
  }

  if (appliedCount === 0) {
    console.log("Database is already up to date.");
  } else {
    console.log(`Applied ${appliedCount} migration(s).`);
  }
}

const command = process.argv[2];

try {
  if (command === "--status") {
    await showStatus();
  } else {
    await migrate();
  }
} catch (error) {
  console.error("Migration failed:");
  console.error(error);
  process.exitCode = 1;
} finally {
  await pool.end();
}