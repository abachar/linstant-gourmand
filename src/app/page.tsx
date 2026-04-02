export const dynamic = "force-dynamic";

import { DashboardPage, getDashboardAction } from "@features/dashboard";

export default async function Page({ searchParams }: { searchParams: Promise<{ month?: string }> }) {
	const { month } = await searchParams;
	const data = await getDashboardAction(month || undefined);

	return <DashboardPage {...data} />;
}
