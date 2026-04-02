import { db, sales } from "@common/db";
import { getMonthName } from "@common/format";
import { sql } from "drizzle-orm";

const TAX_RATE = 0.123;

async function getAvailableYears() {
	const result = await db
		.select({
			year: sql<number>`EXTRACT(YEAR FROM ${sales.deliveryDatetime})::int`,
		})
		.from(sales)
		.groupBy(sql`EXTRACT(YEAR FROM ${sales.deliveryDatetime})`)
		.orderBy(sql`EXTRACT(YEAR FROM ${sales.deliveryDatetime}) DESC`);

	return result.map((r) => r.year);
}

async function getMonthlySummary(year: number) {
	const rows = await db
		.select({
			month: sql<number>`EXTRACT(MONTH FROM ${sales.deliveryDatetime})::int`,
			deposit: sales.deposit,
			depositPaymentMethod: sales.depositPaymentMethod,
			remaining: sales.remaining,
			remainingPaymentMethod: sales.remainingPaymentMethod,
		})
		.from(sales)
		.where(sql`EXTRACT(YEAR FROM ${sales.deliveryDatetime}) = ${year}`);

	const byMonth = new Map<number, { totalAmount: number; bankTotalAmount: number; cashTotalAmount: number }>();

	for (const row of rows) {
		const deposit = Number(row.deposit);
		const remaining = Number(row.remaining);
		const entry = byMonth.get(row.month) ?? { totalAmount: 0, bankTotalAmount: 0, cashTotalAmount: 0 };

		entry.totalAmount += deposit + remaining;
		if (row.depositPaymentMethod === "Bank") entry.bankTotalAmount += deposit;
		if (row.remainingPaymentMethod === "Bank") entry.bankTotalAmount += remaining;
		if (row.depositPaymentMethod === "Cash") entry.cashTotalAmount += deposit;
		if (row.remainingPaymentMethod === "Cash") entry.cashTotalAmount += remaining;

		byMonth.set(row.month, entry);
	}

	return Array.from(byMonth.entries())
		.sort(([a], [b]) => b - a)
		.map(([month, { totalAmount, bankTotalAmount, cashTotalAmount }]) => ({
			month,
			monthLabel: getMonthName(month),
			totalAmount: Math.round(totalAmount * 100) / 100,
			bankTotalAmount: Math.round(bankTotalAmount * 100) / 100,
			cashTotalAmount: Math.round(cashTotalAmount * 100) / 100,
			taxAmount: Math.round(totalAmount * TAX_RATE * 100) / 100,
		}));
}

export async function getTaxReporting(year: number) {
	return {
		selectedYear: year,
		availableYears: await getAvailableYears(),
		monthlyItems: await getMonthlySummary(year),
	};
}
