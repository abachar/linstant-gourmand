import { db, products, purchases, sales } from "@common/db";
import { toProductDto } from "@features/products/api.server";
import { toPurchaseDto } from "@features/purchases/api.server";
import { toSaleDtos } from "@features/sales/api.server";
import { and, asc, gt, isNull } from "drizzle-orm";

export const SYNC_DEFAULT_LIMIT = 500;
export const SYNC_MAX_LIMIT = 1000;

type Table = typeof sales | typeof purchases | typeof products;

function changedSince<T extends Table>(table: T, cursor: number, limit: number) {
	const changed = gt(table.changeSeq, cursor);
	return (
		db
			.select()
			.from(table as Table)
			// Full sync (cursor 0): the device has nothing yet, deleted rows are useless to it.
			.where(cursor === 0 ? and(changed, isNull(table.deletedAt)) : changed)
			.orderBy(asc(table.changeSeq))
			.limit(limit + 1)
	);
}

/**
 * Every entity changed after `cursor`, in change_seq order across the three tables, at most `limit`.
 * Each table is read up to limit + 1 rows: a table can contribute at most `limit` rows to the page,
 * so every row whose change_seq is below the page's last one has been read.
 */
export async function getChanges(cursor: number, limit: number) {
	const [saleRows, purchaseRows, productRows] = await Promise.all([
		changedSince(sales, cursor, limit) as Promise<(typeof sales.$inferSelect)[]>,
		changedSince(purchases, cursor, limit) as Promise<(typeof purchases.$inferSelect)[]>,
		changedSince(products, cursor, limit) as Promise<(typeof products.$inferSelect)[]>,
	]);

	const seqs = [...saleRows, ...purchaseRows, ...productRows].map((r) => r.changeSeq).sort((a, b) => a - b);
	const hasMore = seqs.length > limit;
	const lastSeq = seqs.slice(0, limit).at(-1) ?? cursor;
	const inPage = <R extends { changeSeq: number }>(rows: R[]) => rows.filter((r) => r.changeSeq <= lastSeq);

	return {
		cursor: lastSeq,
		hasMore,
		sales: await toSaleDtos(inPage(saleRows)),
		purchases: inPage(purchaseRows).map(toPurchaseDto),
		products: inPage(productRows).map(toProductDto),
	};
}
