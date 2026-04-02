export const dynamic = "force-dynamic";

import { findSalesByRangeAction, SaleListPage } from "@features/sales";

export default async function Page({ searchParams }: { searchParams: Promise<{ filter?: string }> }) {
	const { filter } = await searchParams;
	const data = await findSalesByRangeAction(filter ?? "");

	return <SaleListPage {...data} />;
}
