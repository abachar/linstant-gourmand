import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { drizzle } from "drizzle-orm/node-postgres";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import pg from "pg";

/**
 * Standalone migration runner, executed before the server starts (linstant-gourmand-migrate.container).
 * It deliberately imports nothing from the app: no path aliases, no env other than DATABASE_URL.
 * The migrations folder is found by walking up from this file, never from the cwd: the source sits
 * in src/common/db/, the bundle in dist/, and `drizzle/` is beside `src/` and `dist/`.
 */
const url = process.env.DATABASE_URL;
if (!url) {
	console.error("[migrate] DATABASE_URL manquant");
	process.exit(1);
}

function findUp(from: string, name: string): string {
	for (let dir = from; ; dir = path.dirname(dir)) {
		const candidate = path.join(dir, name);
		if (fs.existsSync(candidate)) return candidate;
		if (dir === path.dirname(dir)) throw new Error(`dossier ${name}/ introuvable au-dessus de ${from}`);
	}
}

const folder = findUp(path.dirname(fileURLToPath(import.meta.url)), "drizzle");
const client = new pg.Client({ connectionString: url });

try {
	await client.connect();
	console.log(`[migrate] application des migrations depuis ${folder}`);
	await migrate(drizzle(client), { migrationsFolder: folder });
	console.log("[migrate] à jour");
} catch (e) {
	console.error("[migrate] échec:", (e as Error).message);
	process.exitCode = 1;
} finally {
	await client.end();
}
