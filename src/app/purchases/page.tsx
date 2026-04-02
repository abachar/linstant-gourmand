export const dynamic = "force-dynamic";

import { findAllPurchasesAction, PurchaseListPage } from "@features/purchases";

export default async function Page({ searchParams }: { searchParams: Promise<{ year?: string }> }) {
	const { year } = await searchParams;
	const data = await findAllPurchasesAction(year ? Number(year) : new Date().getFullYear());

	return <PurchaseListPage {...data} />;
}
