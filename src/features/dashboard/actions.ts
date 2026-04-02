"use server";

import { isValid, parse } from "date-fns";
import { findDaySales, getDashboard } from "./api.server";

export async function getDashboardAction(month: string | undefined) {
	const d = month ? parse(month, "yyyy-MM-dd", new Date()) : new Date();
	return getDashboard(d);
}

export async function findDaySalesAction(date: string) {
	const d = parse(date, "yyyy-MM-dd", new Date());
	return isValid(d) ? findDaySales(d) : [];
}
