import { baseVersionSchema } from "@common/validation";
import { parseBaseVersion, parseId, readJson, route } from "@features/api/http.server";
import { deletePurchase, savePurchase } from "@features/purchases/api.server";
import { purchaseInputSchema } from "@features/purchases/schemas";
import { z } from "zod";

const bodySchema = z.object({ baseVersion: baseVersionSchema });

export const PUT = route<{ id: string }>(async (request, { id }) => {
	const body = await readJson(request);
	const { baseVersion } = bodySchema.parse(body);
	return Response.json(await savePurchase(parseId(id), baseVersion, purchaseInputSchema.parse(body)));
});

export const DELETE = route<{ id: string }>(async (request, { id }) => {
	return Response.json(await deletePurchase(parseId(id), parseBaseVersion(request)));
});
