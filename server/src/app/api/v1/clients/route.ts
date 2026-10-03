import { readJson, route } from "@features/api/http.server";
import { listClients, updateClient } from "@features/clients/api.server";
import { z } from "zod";

const nullableText = z
	.string()
	.trim()
	.nullable()
	.transform((v) => v || null);

const updateClientSchema = z.object({
	oldClientName: z.string(),
	oldDeliveryAddress: z.string().nullable(),
	newClientName: z.string().trim().min(1, "Nom du client obligatoire"),
	newDeliveryAddress: nullableText,
});

export const GET = route(async () => Response.json(await listClients()));

export const PUT = route(async (request) => {
	await updateClient(updateClientSchema.parse(await readJson(request)));
	return new Response(null, { status: 204 });
});
