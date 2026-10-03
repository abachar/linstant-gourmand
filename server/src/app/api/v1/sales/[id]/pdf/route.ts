import { NotFoundError } from "@common/errors";
import { parseId, route } from "@features/api/http.server";
import { renderSalePdf } from "@features/sales";
import { findSaleById } from "@features/sales/api.server";

export const GET = route<{ id: string }>(async (request, { id }) => {
	const sale = await findSaleById(parseId(id));
	if (!sale || sale.items.length === 0) throw new NotFoundError("Vente introuvable ou sans articles.");

	const isInvoice = new URL(request.url).searchParams.get("type") === "invoice";
	return renderSalePdf(sale, isInvoice);
});
