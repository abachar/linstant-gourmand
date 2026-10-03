export const dynamic = "force-dynamic";

import { findPurchaseByIdAction, PurchaseEditPage } from "@features/purchases";
import { notFound } from "next/navigation";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const purchase = await findPurchaseByIdAction(id);
	if (!purchase) notFound();

	return <PurchaseEditPage purchase={purchase} />;
}
