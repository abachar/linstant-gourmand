export const dynamic = "force-dynamic";

import { findTaxReportingAction, TaxReportingPage } from "@features/taxes";

export default async function Page({ searchParams }: { searchParams: Promise<{ year?: string }> }) {
	const { year } = await searchParams;
	const data = await findTaxReportingAction(year ? Number(year) : new Date().getFullYear());

	return <TaxReportingPage {...data} />;
}
