"use server";

import { getTaxReporting } from "./api.server";

export async function findTaxReportingAction(year: number) {
	return getTaxReporting(year);
}

export type FindTaxReportingReturn = Awaited<ReturnType<typeof findTaxReportingAction>>;
