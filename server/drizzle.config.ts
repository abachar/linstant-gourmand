import { defineConfig } from "drizzle-kit";

export default defineConfig({
	schema: "./src/common/db/schema.ts",
	out: "./drizzle",
	dialect: "postgresql",
	// dev only: db:generate never runs in production
	dbCredentials: { url: process.env.DATABASE_URL ?? "postgresql://localhost:5432/linstant_gourmand" },
});
