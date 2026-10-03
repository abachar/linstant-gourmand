"use server";

import { randomUUID } from "node:crypto";
import { runAction } from "@common/errors";
import { deletePurchase, findAllPurchases, findPurchaseById, importPurchasesFromCsv, savePurchase } from "./api.server";
import { purchaseInputSchema } from "./schemas";

export async function findAllPurchasesAction(year: number) {
	return findAllPurchases(year);
}

export type FindAllPurchasesReturn = Awaited<ReturnType<typeof findAllPurchasesAction>>;

export async function findPurchaseByIdAction(id: string) {
	return findPurchaseById(id);
}

export type FindPurchaseByIdReturn = NonNullable<Awaited<ReturnType<typeof findPurchaseByIdAction>>>;

type PurchaseFormData = { date: string; amount: string; description?: string };

export async function createPurchaseAction(data: PurchaseFormData) {
	return runAction(async () => {
		const purchase = await savePurchase(randomUUID(), null, purchaseInputSchema.parse(data));
		return { id: purchase.id };
	});
}

export async function updatePurchaseAction(data: PurchaseFormData & { id: string; version: number }) {
	return runAction(async () => {
		await savePurchase(data.id, data.version, purchaseInputSchema.parse(data));
	});
}

export async function deletePurchaseByIdAction(id: string, version: number) {
	return runAction(async () => {
		await deletePurchase(id, version);
	});
}

export async function importPurchasesFromCsvAction(content: string) {
	return importPurchasesFromCsv(content);
}
