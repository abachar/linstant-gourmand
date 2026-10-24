import { db, saleItems, sales } from "@common/db";
import { BadRequestError, NotFoundError } from "@common/errors";
import { endOfMonth, isSameMonth, startOfMonth } from "date-fns";
import { and, asc, between, eq, inArray, isNull } from "drizzle-orm";

/**
 * Grouped invoice: one PDF for several sales of the same client delivered the same month.
 * Nothing is stored, the document is rendered from the selected sales (docs/api.md, "Lecture seule").
 */

export const MAX_INVOICE_SALES = 20;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The `ids` query parameter: comma-separated UUIDs, duplicates ignored. */
export function parseInvoiceIds(url: string): string[] {
	const raw = new URL(url).searchParams.get("ids") ?? "";
	const ids = [...new Set(raw.split(",").map((id) => id.trim().toLowerCase()))].filter((id) => id !== "");
	if (ids.length === 0) throw new BadRequestError("Aucune vente sélectionnée.");
	if (ids.length > MAX_INVOICE_SALES) throw new BadRequestError(`${MAX_INVOICE_SALES} ventes maximum par facture.`);
	if (ids.some((id) => !UUID.test(id))) throw new BadRequestError("Identifiant de vente invalide.");
	return ids;
}

async function withItems<T extends { id: string }>(rows: T[]) {
	if (rows.length === 0) return [];
	const items = await db
		.select()
		.from(saleItems)
		.where(
			inArray(
				saleItems.saleId,
				rows.map((r) => r.id),
			),
		)
		.orderBy(asc(saleItems.sortOrder));
	return rows.map((row) => ({ ...row, items: items.filter((item) => item.saleId === row.id) }));
}

/**
 * The sales of one invoice, oldest delivery first. Every id must exist (404); the sales must all have
 * items, belong to the same client and be delivered the same month (400).
 */
export async function findInvoiceSales(ids: string[]) {
	const rows = await db
		.select()
		.from(sales)
		.where(and(inArray(sales.id, ids), isNull(sales.deletedAt)))
		.orderBy(asc(sales.deliveryDatetime), asc(sales.createdAt));
	if (rows.length !== ids.length) throw new NotFoundError("Vente introuvable.");

	const result = await withItems(rows);
	const [first] = result;
	if (result.some((sale) => sale.items.length === 0)) {
		throw new BadRequestError("Chaque vente de la facture doit avoir des articles.");
	}
	if (result.some((sale) => sale.clientName !== first.clientName)) {
		throw new BadRequestError("Les ventes d'une même facture doivent être du même client.");
	}
	if (result.some((sale) => !isSameMonth(sale.deliveryDatetime, first.deliveryDatetime))) {
		throw new BadRequestError("Les ventes d'une même facture doivent être livrées le même mois.");
	}
	return result;
}

export type InvoiceSale = Awaited<ReturnType<typeof findInvoiceSales>>[number];

/**
 * The sales that can share an invoice with `saleId`: same client, same delivery month, with items.
 * Includes the sale itself. `undefined` when the sale does not exist.
 */
export async function findInvoiceCandidates(saleId: string) {
	const [sale] = await db
		.select()
		.from(sales)
		.where(and(eq(sales.id, saleId), isNull(sales.deletedAt)))
		.limit(1);
	if (!sale) return undefined;

	const rows = await db
		.select()
		.from(sales)
		.where(
			and(
				eq(sales.clientName, sale.clientName),
				between(sales.deliveryDatetime, startOfMonth(sale.deliveryDatetime), endOfMonth(sale.deliveryDatetime)),
				isNull(sales.deletedAt),
				inArray(sales.id, db.select({ id: saleItems.saleId }).from(saleItems)),
			),
		)
		.orderBy(asc(sales.deliveryDatetime), asc(sales.createdAt));
	return { sale, candidates: await withItems(rows) };
}
