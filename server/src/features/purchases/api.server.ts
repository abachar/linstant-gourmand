import { createHash } from "node:crypto";
import { db, purchases } from "@common/db";
import { ConflictError, ForbiddenError, NotFoundError } from "@common/errors";
import { decideDelete, decideWrite } from "@common/sync";
import { parse } from "csv-parse/sync";
import { and, desc, eq, isNull, sql } from "drizzle-orm";
import type { PurchaseInput } from "./schemas";

type PurchaseRow = typeof purchases.$inferSelect;

async function getAvailableYears() {
	const result = await db
		.select({ year: sql<number>`EXTRACT(YEAR FROM ${purchases.date})::int` })
		.from(purchases)
		.where(isNull(purchases.deletedAt))
		.groupBy(sql`EXTRACT(YEAR FROM ${purchases.date})`)
		.orderBy(sql`EXTRACT(YEAR FROM ${purchases.date}) DESC`);
	return result.map((r) => r.year);
}

export async function findAllPurchases(year: number) {
	const result = await db
		.select()
		.from(purchases)
		.where(and(sql`EXTRACT(YEAR FROM ${purchases.date}) = ${year}`, isNull(purchases.deletedAt)))
		.orderBy(desc(purchases.date));
	return {
		selectedYear: year,
		availableYears: await getAvailableYears(),
		purchases: result.map((s) => ({
			id: s.id,
			version: s.version,
			date: s.date,
			description: s.description,
			amount: s.amount,
			isImported: s.importRef !== null,
		})),
	};
}

export async function importPurchasesFromCsv(csvText: string) {
	console.log("Import purchases from Revolut");

	const records = parse<{ Type: string; "Date de début": string; Description: string; Montant: string }>(csvText, {
		columns: true,
		skip_empty_lines: true,
		relax_column_count: true,
	});

	console.log("Parsed", records.length, "records");

	const rows = records
		.filter((record) => ["Paiement par carte", "Remboursement sur carte"].includes(record.Type))
		.map((record) => ({
			date: record["Date de début"].split(" ")[0] ?? "",
			amount: (Number(record.Montant) * -1).toFixed(2),
			description: record.Description,
		}))
		.map((row) => ({
			...row,
			date: new Date(row.date),
			importRef: createHash("sha256").update(`${row.date}|${row.amount}|${row.description}`).digest("hex"),
		}));

	console.log("Found", rows.length, "payments");

	const result = await db
		.insert(purchases)
		.values(rows)
		.onConflictDoNothing({ target: purchases.importRef })
		.returning({ id: purchases.id });

	console.log("Inserted", result.length, "rows");
	return { inserted: result.length };
}

export async function findPurchaseById(id: string) {
	const [purchase] = await db
		.select()
		.from(purchases)
		.where(and(eq(purchases.id, id), isNull(purchases.deletedAt)))
		.limit(1);
	return purchase;
}

export function toPurchaseDto(row: PurchaseRow) {
	return {
		id: row.id,
		version: row.version,
		date: row.date.toISOString(),
		amount: row.amount,
		description: row.description,
		isImported: row.importRef !== null,
		createdAt: row.createdAt.toISOString(),
		updatedAt: row.updatedAt.toISOString(),
		deletedAt: row.deletedAt?.toISOString() ?? null,
	};
}

export type PurchaseDto = ReturnType<typeof toPurchaseDto>;

const IMPORTED_READONLY = "Les achats importés ne peuvent pas être modifiés ni supprimés.";

/** Creates or updates a purchase with optimistic locking (docs/api.md, "Écriture"). */
export async function savePurchase(id: string, baseVersion: number | null, input: PurchaseInput): Promise<PurchaseDto> {
	return await db.transaction(async (tx) => {
		const [existing] = await tx.select().from(purchases).where(eq(purchases.id, id)).for("update");
		const decision = decideWrite(existing, baseVersion);
		if (decision === "conflict") throw new ConflictError(existing ? toPurchaseDto(existing) : null);
		if (existing?.importRef) throw new ForbiddenError(IMPORTED_READONLY);

		const values = { date: input.date, amount: input.amount, description: input.description };
		const [row] =
			decision === "create"
				? await tx
						.insert(purchases)
						.values({ id, ...values })
						.returning()
				: await tx.update(purchases).set(values).where(eq(purchases.id, id)).returning();
		return toPurchaseDto(row);
	});
}

export async function deletePurchase(id: string, baseVersion: number): Promise<PurchaseDto> {
	return await db.transaction(async (tx) => {
		const [existing] = await tx.select().from(purchases).where(eq(purchases.id, id)).for("update");
		const decision = decideDelete(existing, baseVersion);
		if (decision === "not_found") throw new NotFoundError("Achat introuvable.");
		if (decision === "conflict") throw new ConflictError(toPurchaseDto(existing));
		if (existing.importRef) throw new ForbiddenError(IMPORTED_READONLY);
		if (decision === "noop") return toPurchaseDto(existing);

		const [row] = await tx.update(purchases).set({ deletedAt: new Date() }).where(eq(purchases.id, id)).returning();
		return toPurchaseDto(row);
	});
}
