import { clientIp, publicRoute, readJson } from "@features/api/http.server";
import { verifyCredentials } from "@features/auth/api.server";
import { createApiSession } from "@features/auth/api-session.server";
import { z } from "zod";

const loginSchema = z.object({
	email: z.string().trim(),
	password: z.string(),
	deviceName: z.string().trim().min(1).max(100),
});

export const POST = publicRoute(async (request) => {
	const { email, password, deviceName } = loginSchema.parse(await readJson(request));
	await verifyCredentials(email, password, clientIp(request));
	return Response.json(await createApiSession(deviceName));
});
