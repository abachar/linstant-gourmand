import { route } from "@features/api/http.server";
import { renderSalePdf } from "@features/sales";
import { findInvoiceSales, parseInvoiceIds } from "@features/sales/invoice.server";

/** Grouped quote/invoice: GET /api/v1/sales/pdf?ids=a,b,c&type=quote|invoice (docs/api.md). */
export const GET = route(async (request) => {
	const sales = await findInvoiceSales(parseInvoiceIds(request.url));
	const isInvoice = new URL(request.url).searchParams.get("type") === "invoice";
	return renderSalePdf(sales, isInvoice);
});
