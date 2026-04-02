"use server";

import { createProduct, deleteProductById, findAllProducts, findProductById, updateProduct } from "./api.server";

export async function findAllProductsAction() {
	return findAllProducts();
}

export type FindAllProductsReturn = Awaited<ReturnType<typeof findAllProductsAction>>;

export async function findProductByIdAction(id: string) {
	return findProductById(id);
}

export type FindProductByIdReturn = Awaited<ReturnType<typeof findProductByIdAction>>;

export async function createProductAction(data: {
	productName: string;
	quantity: number;
	expirationDate: string | null;
}) {
	return createProduct(data);
}

export async function deleteProductByIdAction(id: string) {
	return deleteProductById(id);
}

export async function updateProductAction(data: {
	id: string;
	productName: string;
	quantity: number;
	expirationDate: string | null;
}) {
	return updateProduct(data);
}
