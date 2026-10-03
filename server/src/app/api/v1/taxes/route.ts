import { BadRequestError, route } from "@features/api/http.server";
import { getTaxReporting } from "@features/taxes/api.server";

export const GET = route(async (request) => {
	const year = Number(new URL(request.url).searchParams.get("year") ?? new Date().getFullYear());
	if (!Number.isInteger(year) || year < 2000 || year > 2100) throw new BadRequestError("Paramètre year invalide.");
	return Response.json(await getTaxReporting(year));
});
