import { drizzle } from "drizzle-orm/node-postgres";
import { apiSessions, products, purchases, saleItems, sales } from "./schema";

function getDb() {
	if (!process.env.DATABASE_URL) {
		throw new Error("DATABASE_URL environment variable not set");
	}

	return drizzle(process.env.DATABASE_URL, {
		schema: { sales, saleItems, purchases, products, apiSessions },
		logger: process.env.NODE_ENV !== "production",
	});
}

// Lazy singleton: only connects when first accessed
let _db: ReturnType<typeof getDb> | null = null;

export const db = new Proxy({} as ReturnType<typeof getDb>, {
	get(_target, prop, receiver) {
		if (!_db) _db = getDb();
		return Reflect.get(_db, prop, receiver);
	},
});

export { apiSessions, products, purchases, saleItems, sales };
