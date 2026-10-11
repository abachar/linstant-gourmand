"use server";

import { randomUUID } from "node:crypto";
import { type ActionResult, runAction } from "@common/errors";
import { deletePurchase, findAllPurchases, findPurchaseById, importPurchasesFromCsv, savePurchase } from "./api.server";
import { type ReceiptMediaType, type ReceiptScan, ReceiptScanError, scanReceipt } from "./receipt.server";
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

/** Reads a receipt photo (base64) and proposes the purchase fields; nothing is saved. */
export async function scanReceiptAction(image: {
	data: string;
	mediaType: ReceiptMediaType;
}): Promise<ActionResult<ReceiptScan>> {
	try {
		return { ok: true, data: await scanReceipt(Buffer.from(image.data, "base64"), image.mediaType) };
	} catch (e) {
		if (e instanceof ReceiptScanError) return { ok: false, code: "receipt_scan_failed", message: e.message };
		throw e;
	}
}
