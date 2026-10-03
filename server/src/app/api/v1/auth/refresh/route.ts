import { publicRoute, readJson } from "@features/api/http.server";
import { refreshApiSession } from "@features/auth/api-session.server";
import { z } from "zod";

const refreshSchema = z.object({ refreshToken: z.string().min(1) });

export const POST = publicRoute(async (request) => {
	const { refreshToken } = refreshSchema.parse(await readJson(request));
	return Response.json(await refreshApiSession(refreshToken));
});
