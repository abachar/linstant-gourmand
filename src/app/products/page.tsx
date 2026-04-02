export const dynamic = "force-dynamic";

import { findAllProductsAction, ProductListPage } from "@features/products";

export default async function Page() {
	const products = await findAllProductsAction();

	return <ProductListPage products={products} />;
}
