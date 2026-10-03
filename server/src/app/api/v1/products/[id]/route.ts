import { baseVersionSchema } from "@common/validation";
import { parseBaseVersion, parseId, readJson, route } from "@features/api/http.server";
import { deleteProduct, saveProduct } from "@features/products/api.server";
import { productInputSchema } from "@features/products/schemas";
import { z } from "zod";

const bodySchema = z.object({ baseVersion: baseVersionSchema });

export const PUT = route<{ id: string }>(async (request, { id }) => {
	const body = await readJson(request);
	const { baseVersion } = bodySchema.parse(body);
	return Response.json(await saveProduct(parseId(id), baseVersion, productInputSchema.parse(body)));
});

export const DELETE = route<{ id: string }>(async (request, { id }) => {
	return Response.json(await deleteProduct(parseId(id), parseBaseVersion(request)));
});
