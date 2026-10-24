import { formatDateInput } from "@common/format";
import { renderToBuffer } from "@react-pdf/renderer";
import { SalePrintDocument } from "./SalePrintDocument";
import type { PrintSale } from "./types";

/**
 * Quote or invoice PDF response, shared by the web print routes and GET /api/v1/sales/:id/pdf,
 * GET /api/v1/sales/pdf. Several sales make a grouped invoice.
 */
export async function renderSalePdf(sales: PrintSale[], isInvoice: boolean) {
	const [first] = sales;
	const buffer = await renderToBuffer(<SalePrintDocument sales={sales} isInvoice={isInvoice} />);
	const kind = isInvoice ? "Facture" : "Devis";
	const client = first.clientName.replace(/\s+/g, "_");
	const suffix = sales.length > 1 ? `-${formatDateInput(first.deliveryDatetime).slice(0, 7)}` : "";
	const filename = `${kind}-${client}${suffix}.pdf`;
	const asciiFilename = filename.normalize("NFD").replace(/[^\x20-\x7e]|"/g, "");

	return new Response(new Uint8Array(buffer), {
		headers: {
			"Content-Type": "application/pdf",
			"Content-Disposition": `inline; filename="${asciiFilename}"; filename*=UTF-8''${encodeURIComponent(filename)}`,
		},
	});
}
