import { BadRequestError, route } from "@features/api/http.server";
import { importPurchasesFromCsv } from "@features/purchases/api.server";

export const POST = route(async (request) => {
	const csv = await request.text();
	if (!csv.trim()) throw new BadRequestError("Fichier CSV vide.");
	return Response.json(await importPurchasesFromCsv(csv));
});
