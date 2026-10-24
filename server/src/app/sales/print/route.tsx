import { BadRequestError, NotFoundError } from "@common/errors";
import { renderSalePdf } from "@features/sales";
import { findInvoiceSales, parseInvoiceIds } from "@features/sales/invoice.server";

/** Grouped quote/invoice of several sales: GET /sales/print?ids=a,b,c&type=invoice */
export async function GET(request: Request) {
	try {
		const sales = await findInvoiceSales(parseInvoiceIds(request.url));
		const isInvoice = new URL(request.url).searchParams.get("type") === "invoice";
		return await renderSalePdf(sales, isInvoice);
	} catch (e) {
		if (e instanceof BadRequestError) return new Response(e.message, { status: 400 });
		if (e instanceof NotFoundError) return new Response(e.message, { status: 404 });
		throw e;
	}
}
