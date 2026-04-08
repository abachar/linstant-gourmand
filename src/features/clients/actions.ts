"use server";

import { revalidatePath } from "next/cache";
import { listClients, updateClient } from "./api.server";

export async function listClientsAction() {
	return listClients();
}

export type ListClientsReturn = Awaited<ReturnType<typeof listClientsAction>>;

export async function updateClientAction(data: {
	oldClientName: string;
	oldDeliveryAddress: string | null;
	newClientName: string;
	newDeliveryAddress: string | null;
}) {
	await updateClient(data);
	revalidatePath("/admin/clients");
}
