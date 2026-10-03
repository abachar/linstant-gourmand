import { defineConfig } from "vitest/config";

export default defineConfig({
	resolve: { tsconfigPaths: true },
	test: {
		env: {
			TZ: "UTC",
		},
		globalSetup: ["./test/global-setup.ts"],
		setupFiles: ["./test/setup.ts"],
		// Database tests share one database
		fileParallelism: false,
	},
});
