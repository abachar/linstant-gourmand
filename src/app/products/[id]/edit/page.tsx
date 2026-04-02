export const dynamic = "force-dynamic";

import { findProductByIdAction, ProductEditPage } from "@features/products";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const product = await findProductByIdAction(id);

	return <ProductEditPage product={product} />;
}
