export const dynamic = "force-dynamic";

import { findPurchaseByIdAction, PurchaseEditPage } from "@features/purchases";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const purchase = await findPurchaseByIdAction(id);

	return <PurchaseEditPage purchase={purchase} />;
}
