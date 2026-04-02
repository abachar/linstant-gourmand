import { db, purchases, sales } from "@common/db";
import {
	addMonths,
	eachDayOfInterval,
	endOfDay,
	endOfMonth,
	endOfWeek,
	endOfYear,
	format,
	startOfDay,
	startOfMonth,
	startOfWeek,
	startOfYear,
	subMonths,
} from "date-fns";
import { asc, between, sql } from "drizzle-orm";

const TAX_RATE = 0.123;

async function sumSales(from: Date, to: Date) {
	const result = await db
		.select({ total: sql<string>`coalesce(sum(${sales.amount}), 0)` })
		.from(sales)
		.where(between(sales.deliveryDatetime, from, to));

	return Number(result[0].total);
}

async function sumPurchases(from: Date, to: Date) {
	const result = await db
		.select({ total: sql<string>`coalesce(sum(${purchases.amount}), 0)` })
		.from(purchases)
		.where(between(purchases.date, from, to));

	return Number(result[0].total);
}

async function getMonthSales(d: Date) {
	const today = format(new Date(), "yyyy-MM-dd");
	const start = startOfWeek(startOfMonth(d), { weekStartsOn: 1 });
	const end = endOfWeek(endOfMonth(d), { weekStartsOn: 1 });

	const result = await db
		.select({
			date: sql<string>`to_char(${sales.deliveryDatetime}, 'YYYY-MM-DD')`,
			salesIds: sql<string[]>`json_agg(${sales.id})`,
		})
		.from(sales)
		.where(between(sales.deliveryDatetime, start, end))
		.groupBy(sql`to_char(${sales.deliveryDatetime}, 'YYYY-MM-DD')`)
		.orderBy(sql`to_char(${sales.deliveryDatetime}, 'YYYY-MM-DD')`);

	return eachDayOfInterval({ start, end }).map((date) => {
		const dateStr = format(date, "yyyy-MM-dd");
		const saleData = result.find((r) => r.date === dateStr);
		return {
			isToday: dateStr === today,
			inSelectedMonth: format(date, "MM") === format(d, "MM"),
			date: dateStr,
			day: format(date, "dd"),
			saleIds: saleData?.salesIds ?? [],
		};
	});
}

export async function getDashboard(d: Date) {
	const startOfMonthDate = startOfMonth(d);
	const endOfMonthDate = endOfMonth(d);
	const startOfYearDate = startOfYear(d);
	const endOfYearDate = endOfYear(d);

	const currentMonthSales = await sumSales(startOfMonthDate, endOfMonthDate);
	const currentYearSales = await sumSales(startOfYearDate, endOfYearDate);

	return {
		calendarTitle: format(d, "MMMM yyyy"),
		prevMonth: format(startOfMonth(subMonths(d, 1)), "yyyy-MM-dd"),
		nextMonth: format(startOfMonth(addMonths(d, 1)), "yyyy-MM-dd"),
		currentMonthSales,
		currentMonthExpenses: await sumPurchases(startOfMonthDate, endOfMonthDate),
		currentYearSales,
		currentYearExpenses: await sumPurchases(startOfYearDate, endOfYearDate),
		currentMonthTax: Math.round(currentMonthSales * TAX_RATE * 100) / 100,
		currentYearTax: Math.round(currentYearSales * TAX_RATE * 100) / 100,
		monthSales: await getMonthSales(d),
	};
}

export type DashboardData = Awaited<ReturnType<typeof getDashboard>>;

export async function findDaySales(d: Date) {
	const start = startOfDay(d);
	const end = endOfDay(d);

	const result = await db
		.select()
		.from(sales)
		.where(between(sales.deliveryDatetime, start, end))
		.orderBy(asc(sales.deliveryDatetime));

	return result.map((s) => ({
		id: s.id,
		clientName: s.clientName,
		deliveryDatetime: s.deliveryDatetime,
		amount: s.amount,
	}));
}
