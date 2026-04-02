import { db, products } from "@common/db";
import { asc, eq } from "drizzle-orm";

export async function findAllProducts() {
	return await db.select().from(products).orderBy(asc(products.productName));
}

export async function findProductById(id: string) {
	const [item] = await db.select().from(products).where(eq(products.id, id)).limit(1);
	return item;
}

export async function createProduct(data: { productName: string; quantity: number; expirationDate: string | null }) {
	const [result] = await db
		.insert(products)
		.values({
			productName: data.productName,
			quantity: data.quantity,
			expirationDate: data.expirationDate ? new Date(data.expirationDate) : null,
			updatedAt: new Date(),
		})
		.returning({ id: products.id });
	return { id: result.id };
}

export async function deleteProductById(id: string) {
	await db.delete(products).where(eq(products.id, id));
}

export async function updateProduct(data: {
	id: string;
	productName: string;
	quantity: number;
	expirationDate: string | null;
}) {
	await db
		.update(products)
		.set({
			productName: data.productName,
			quantity: data.quantity,
			expirationDate: data.expirationDate ? new Date(data.expirationDate) : null,
			updatedAt: new Date(),
		})
		.where(eq(products.id, data.id));
}
