"use server";

import { randomUUID } from "node:crypto";
import { runAction } from "@common/errors";
import { deleteProduct, findAllProducts, findProductById, saveProduct } from "./api.server";
import { productInputSchema } from "./schemas";

export async function findAllProductsAction() {
	return findAllProducts();
}

export type FindAllProductsReturn = Awaited<ReturnType<typeof findAllProductsAction>>;

export async function findProductByIdAction(id: string) {
	return findProductById(id);
}

export type FindProductByIdReturn = NonNullable<Awaited<ReturnType<typeof findProductByIdAction>>>;

type ProductFormData = { productName: string; quantity: number; expirationDate: string | null };

export async function createProductAction(data: ProductFormData) {
	return runAction(async () => {
		const product = await saveProduct(randomUUID(), null, productInputSchema.parse(data));
		return { id: product.id };
	});
}

export async function updateProductAction(data: ProductFormData & { id: string; version: number }) {
	return runAction(async () => {
		await saveProduct(data.id, data.version, productInputSchema.parse(data));
	});
}

export async function deleteProductByIdAction(id: string, version: number) {
	return runAction(async () => {
		await deleteProduct(id, version);
	});
}
