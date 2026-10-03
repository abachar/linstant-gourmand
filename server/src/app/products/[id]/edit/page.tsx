export const dynamic = "force-dynamic";

import { findProductByIdAction, ProductEditPage } from "@features/products";
import { notFound } from "next/navigation";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const product = await findProductByIdAction(id);
	if (!product) notFound();

	return <ProductEditPage product={product} />;
}
