export const dynamic = "force-dynamic";

import { findSaleByIdAction, SaleEditPage } from "@features/sales";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const sale = await findSaleByIdAction(id);

	return <SaleEditPage sale={sale} />;
}
