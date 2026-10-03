export const dynamic = "force-dynamic";

import { findSaleByIdAction, SaleShowPage } from "@features/sales";
import { notFound } from "next/navigation";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const sale = await findSaleByIdAction(id);
	if (!sale) notFound();

	return <SaleShowPage sale={sale} />;
}
