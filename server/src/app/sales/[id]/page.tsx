export const dynamic = "force-dynamic";

import { findInvoiceCandidatesAction, findSaleByIdAction, SaleShowPage } from "@features/sales";
import { notFound } from "next/navigation";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const sale = await findSaleByIdAction(id);
	if (!sale) notFound();
	const invoiceCandidates =
		sale.items.length > 0 ? ((await findInvoiceCandidatesAction(id))?.candidates.length ?? 0) : 0;

	return <SaleShowPage sale={sale} canGroupInvoice={invoiceCandidates > 1} />;
}
