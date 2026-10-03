import { db, products } from "@common/db";
import { ConflictError, NotFoundError } from "@common/errors";
import { decideDelete, decideWrite } from "@common/sync";
import { and, asc, eq, isNull } from "drizzle-orm";
import type { ProductInput } from "./schemas";

type ProductRow = typeof products.$inferSelect;

export async function findAllProducts() {
	return await db.select().from(products).where(isNull(products.deletedAt)).orderBy(asc(products.productName));
}

export async function findProductById(id: string) {
	const [item] = await db
		.select()
		.from(products)
		.where(and(eq(products.id, id), isNull(products.deletedAt)))
		.limit(1);
	return item;
}

export function toProductDto(row: ProductRow) {
	return {
		id: row.id,
		version: row.version,
		productName: row.productName,
		quantity: row.quantity,
		expirationDate: row.expirationDate?.toISOString() ?? null,
		updatedAt: row.updatedAt.toISOString(),
		deletedAt: row.deletedAt?.toISOString() ?? null,
	};
}

export type ProductDto = ReturnType<typeof toProductDto>;

/** Creates or updates a product with optimistic locking (docs/api.md, "Écriture"). */
export async function saveProduct(id: string, baseVersion: number | null, input: ProductInput): Promise<ProductDto> {
	return await db.transaction(async (tx) => {
		const [existing] = await tx.select().from(products).where(eq(products.id, id)).for("update");
		const decision = decideWrite(existing, baseVersion);
		if (decision === "conflict") throw new ConflictError(existing ? toProductDto(existing) : null);

		const values = { productName: input.productName, quantity: input.quantity, expirationDate: input.expirationDate };
		const [row] =
			decision === "create"
				? await tx
						.insert(products)
						.values({ id, ...values })
						.returning()
				: await tx.update(products).set(values).where(eq(products.id, id)).returning();
		return toProductDto(row);
	});
}

export async function deleteProduct(id: string, baseVersion: number): Promise<ProductDto> {
	return await db.transaction(async (tx) => {
		const [existing] = await tx.select().from(products).where(eq(products.id, id)).for("update");
		const decision = decideDelete(existing, baseVersion);
		if (decision === "not_found") throw new NotFoundError("Produit introuvable.");
		if (decision === "conflict") throw new ConflictError(toProductDto(existing));
		if (decision === "noop") return toProductDto(existing);

		const [row] = await tx.update(products).set({ deletedAt: new Date() }).where(eq(products.id, id)).returning();
		return toProductDto(row);
	});
}
