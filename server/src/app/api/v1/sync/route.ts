import { BadRequestError, route } from "@features/api/http.server";
import { getChanges, SYNC_DEFAULT_LIMIT, SYNC_MAX_LIMIT } from "@features/sync/api.server";

export const GET = route(async (request) => {
	const params = new URL(request.url).searchParams;
	const cursor = Number(params.get("cursor") ?? 0);
	const limit = Number(params.get("limit") ?? SYNC_DEFAULT_LIMIT);
	if (!Number.isSafeInteger(cursor) || cursor < 0) throw new BadRequestError("Paramètre cursor invalide.");
	if (!Number.isInteger(limit) || limit < 1) throw new BadRequestError("Paramètre limit invalide.");

	return Response.json(await getChanges(cursor, Math.min(limit, SYNC_MAX_LIMIT)));
});
