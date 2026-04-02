"use server";

import {
	createPurchase,
	deletePurchaseById,
	findAllPurchases,
	findPurchaseById,
	importPurchasesFromCsv,
	updatePurchase,
} from "./api.server";

export async function findAllPurchasesAction(year: number) {
	return findAllPurchases(year);
}

export type FindAllPurchasesReturn = Awaited<ReturnType<typeof findAllPurchasesAction>>;

export async function findPurchaseByIdAction(id: string) {
	return findPurchaseById(id);
}

export type FindPurchaseByIdReturn = Awaited<ReturnType<typeof findPurchaseByIdAction>>;

export async function createPurchaseAction(data: { date: string; amount: string; description?: string }) {
	return createPurchase(data);
}

export async function updatePurchaseAction(data: { id: string; date: string; amount: string; description?: string }) {
	return updatePurchase(data);
}

export async function deletePurchaseByIdAction(id: string) {
	return deletePurchaseById(id);
}

export async function importPurchasesFromCsvAction(content: string) {
	return importPurchasesFromCsv(content);
}
