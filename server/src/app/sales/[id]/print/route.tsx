import { findSaleByIdAction, renderSalePdf } from "@features/sales";

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
	const { id } = await params;
	const sale = await findSaleByIdAction(id);

	if (!sale || sale.items.length === 0) {
		return new Response("Not found", { status: 404 });
	}

	const isInvoice = new URL(request.url).searchParams.get("type") === "invoice";
	return renderSalePdf(sale, isInvoice);
}
