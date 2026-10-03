import { scryptSync } from "node:crypto";

export const TEST_ADMIN_EMAIL = "admin@test.fr";
export const TEST_ADMIN_PASSWORD = "mot-de-passe";

if (process.env.TEST_DATABASE_URL) {
	const salt = "0123456789abcdef";
	process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
	process.env.APP_ADMIN_EMAIL = TEST_ADMIN_EMAIL;
	process.env.APP_ADMIN_PASSWORD_HEX = `${salt}:${scryptSync(TEST_ADMIN_PASSWORD, salt, 64).toString("hex")}`;
	process.env.SESSION_SECRET_HEX = "74657374".repeat(8);
	// Silences the drizzle query logger
	Object.assign(process.env, { NODE_ENV: "production" });
}
