import { execFileSync } from "node:child_process";
import pg from "pg";

/**
 * Database tests run against TEST_DATABASE_URL (skipped when unset): the schema is wiped and rebuilt
 * with the real migrations, which also tests them.
 */
export default async function setup() {
	const url = process.env.TEST_DATABASE_URL;
	if (!url) return;

	const client = new pg.Client({ connectionString: url });
	await client.connect();
	await client.query(
		"DROP SCHEMA IF EXISTS public CASCADE; DROP SCHEMA IF EXISTS drizzle CASCADE; CREATE SCHEMA public;",
	);
	await client.end();

	execFileSync("node", ["src/common/db/migrate.ts"], { env: { ...process.env, DATABASE_URL: url }, stdio: "inherit" });
}
