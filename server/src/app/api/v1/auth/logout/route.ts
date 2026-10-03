import { readJson, route } from "@features/api/http.server";
import { revokeApiSession } from "@features/auth/api-session.server";
import { z } from "zod";

const logoutSchema = z.object({ refreshToken: z.string().min(1) });

export const POST = route(async (request) => {
	const { refreshToken } = logoutSchema.parse(await readJson(request));
	await revokeApiSession(refreshToken);
	return new Response(null, { status: 204 });
});
