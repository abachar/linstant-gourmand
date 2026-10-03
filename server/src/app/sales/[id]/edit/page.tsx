export const dynamic = "force-dynamic";

import { findSaleByIdAction, SaleEditPage } from "@features/sales";
import { notFound } from "next/navigation";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const sale = await findSaleByIdAction(id);
	if (!sale) notFound();

	return <SaleEditPage sale={sale} />;
}
