import { BadRequestError, route } from "@features/api/http.server";
import { getDashboard } from "@features/dashboard/api.server";
import { format, isValid, parse } from "date-fns";

export const GET = route(async (request) => {
	const month = new URL(request.url).searchParams.get("month") ?? format(new Date(), "yyyy-MM");
	const date = parse(month, "yyyy-MM", new Date());
	if (!isValid(date)) throw new BadRequestError("Paramètre month invalide (YYYY-MM).");

	const dashboard = await getDashboard(date);
	return Response.json({
		month: format(date, "yyyy-MM"),
		currentMonthSales: dashboard.currentMonthSales,
		currentMonthExpenses: dashboard.currentMonthExpenses,
		currentMonthTax: dashboard.currentMonthTax,
		currentYearSales: dashboard.currentYearSales,
		currentYearExpenses: dashboard.currentYearExpenses,
		currentYearTax: dashboard.currentYearTax,
	});
});
