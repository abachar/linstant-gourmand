import { baseVersionSchema } from "@common/validation";
import { parseBaseVersion, parseId, readJson, route } from "@features/api/http.server";
import { deleteSale, saveSale } from "@features/sales/api.server";
import { saleInputSchema } from "@features/sales/schemas";
import { z } from "zod";

const bodySchema = z.object({ baseVersion: baseVersionSchema });

export const PUT = route<{ id: string }>(async (request, { id }) => {
	const body = await readJson(request);
	const { baseVersion } = bodySchema.parse(body);
	return Response.json(await saveSale(parseId(id), baseVersion, saleInputSchema.parse(body)));
});

export const DELETE = route<{ id: string }>(async (request, { id }) => {
	return Response.json(await deleteSale(parseId(id), parseBaseVersion(request)));
});
