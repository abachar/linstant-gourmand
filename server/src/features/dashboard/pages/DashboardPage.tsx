import { PageLayout } from "@components/layouts";
import type { DashboardData } from "../api.server";
import { Calendar, Statistics } from "./components";

export const DashboardPage = (props: DashboardData) => (
	<PageLayout title="Bienvenue, Salma !">
		<div className="space-y-5">
			<Calendar {...props} />
			<Statistics {...props} />
		</div>
	</PageLayout>
);
