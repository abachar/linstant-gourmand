import { db, saleItems, sales } from "@common/db";
import { ConflictError, NotFoundError } from "@common/errors";
import { decideDelete, decideWrite } from "@common/sync";
import { endOfDay, startOfDay } from "date-fns";
import { and, asc, between, desc, eq, inArray, isNull } from "drizzle-orm";
import type { SaleInput } from "./schemas";

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];
type SaleRow = typeof sales.$inferSelect;
type SaleItemRow = typeof saleItems.$inferSelect;

export async function getDistinctClients() {
	return await db
		.selectDistinctOn([sales.clientName, sales.deliveryAddress], {
			clientName: sales.clientName,
			deliveryAddress: sales.deliveryAddress,
		})
		.from(sales)
		.where(isNull(sales.deletedAt))
		.orderBy(asc(sales.clientName), asc(sales.deliveryAddress));
}

export async function findSalesByRange(from: Date, end: Date) {
	return await db
		.select()
		.from(sales)
		.where(and(between(sales.deliveryDatetime, startOfDay(from), endOfDay(end)), isNull(sales.deletedAt)))
		.orderBy(desc(sales.deliveryDatetime));
}

export async function findSaleById(id: string) {
	const [sale] = await db
		.select()
		.from(sales)
		.where(and(eq(sales.id, id), isNull(sales.deletedAt)))
		.limit(1);
	if (!sale) return sale;
	const items = await db.select().from(saleItems).where(eq(saleItems.saleId, id)).orderBy(asc(saleItems.sortOrder));
	return { ...sale, items };
}

export function toSaleDto(sale: SaleRow, items: SaleItemRow[]) {
	return {
		id: sale.id,
		version: sale.version,
		clientName: sale.clientName,
		deliveryDatetime: sale.deliveryDatetime.toISOString(),
		deliveryAddress: sale.deliveryAddress,
		description: sale.description,
		amount: sale.amount,
		deposit: sale.deposit,
		depositPaymentMethod: sale.depositPaymentMethod,
		remaining: sale.remaining,
		remainingPaymentMethod: sale.remainingPaymentMethod,
		items: [...items]
			.sort((a, b) => a.sortOrder - b.sortOrder)
			.map((item) => ({ description: item.description, unitPrice: item.unitPrice, quantity: item.quantity })),
		createdAt: sale.createdAt.toISOString(),
		updatedAt: sale.updatedAt.toISOString(),
		deletedAt: sale.deletedAt?.toISOString() ?? null,
	};
}

export type SaleDto = ReturnType<typeof toSaleDto>;

/** DTOs of several sales with their items, in the order of `rows`. */
export async function toSaleDtos(rows: SaleRow[], tx: Tx | typeof db = db): Promise<SaleDto[]> {
	if (rows.length === 0) return [];
	const items = await tx
		.select()
		.from(saleItems)
		.where(
			inArray(
				saleItems.saleId,
				rows.map((r) => r.id),
			),
		);
	return rows.map((row) =>
		toSaleDto(
			row,
			items.filter((item) => item.saleId === row.id),
		),
	);
}

async function lockSale(tx: Tx, id: string) {
	const [row] = await tx.select().from(sales).where(eq(sales.id, id)).for("update");
	return row;
}

async function currentDto(tx: Tx, row: SaleRow | undefined) {
	return row ? (await toSaleDtos([row], tx))[0] : null;
}

function saleValues(input: SaleInput) {
	return {
		clientName: input.clientName,
		deliveryDatetime: input.deliveryDatetime,
		deliveryAddress: input.deliveryAddress,
		description: input.description,
		amount: input.amount,
		deposit: input.deposit,
		depositPaymentMethod: input.depositPaymentMethod,
		remaining: input.remaining,
		remainingPaymentMethod: input.remainingPaymentMethod,
	};
}

/** Creates or updates a sale with optimistic locking (docs/api.md, "Écriture"). Items are replaced as a whole. */
export async function saveSale(id: string, baseVersion: number | null, input: SaleInput): Promise<SaleDto> {
	return await db.transaction(async (tx) => {
		const existing = await lockSale(tx, id);
		const decision = decideWrite(existing, baseVersion);
		if (decision === "conflict") throw new ConflictError(await currentDto(tx, existing));

		let row: SaleRow;
		if (decision === "create") {
			[row] = await tx
				.insert(sales)
				.values({ id, ...saleValues(input) })
				.returning();
		} else {
			// The bump_sync_columns trigger increments version and change_seq.
			[row] = await tx.update(sales).set(saleValues(input)).where(eq(sales.id, id)).returning();
			await tx.delete(saleItems).where(eq(saleItems.saleId, id));
		}

		if (input.items.length > 0) {
			await tx.insert(saleItems).values(
				input.items.map((item, i) => ({
					saleId: id,
					description: item.description,
					unitPrice: item.unitPrice,
					quantity: item.quantity,
					sortOrder: i,
				})),
			);
		}

		return (await toSaleDtos([row], tx))[0];
	});
}

/** Soft delete, so the deletion reaches the iOS app through /sync. */
export async function deleteSale(id: string, baseVersion: number): Promise<SaleDto> {
	return await db.transaction(async (tx) => {
		const existing = await lockSale(tx, id);
		const decision = decideDelete(existing, baseVersion);
		if (decision === "not_found") throw new NotFoundError("Vente introuvable.");
		if (decision === "conflict") throw new ConflictError(await currentDto(tx, existing));

		let row = existing as SaleRow;
		if (decision === "delete") {
			[row] = await tx.update(sales).set({ deletedAt: new Date() }).where(eq(sales.id, id)).returning();
		}
		return (await toSaleDtos([row], tx))[0];
	});
}
