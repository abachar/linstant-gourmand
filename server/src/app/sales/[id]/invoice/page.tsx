export const dynamic = "force-dynamic";

import { findInvoiceCandidatesAction, SaleInvoicePage } from "@features/sales";
import { notFound } from "next/navigation";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const data = await findInvoiceCandidatesAction(id);
	if (!data) notFound();

	return <SaleInvoicePage {...data} />;
}
