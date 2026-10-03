import { renderToBuffer } from "@react-pdf/renderer";
import type { FindSaleByIdReturn } from "../actions";
import { SalePrintDocument } from "./SalePrintDocument";

/** Quote or invoice PDF response, shared by the web print route and GET /api/v1/sales/:id/pdf. */
export async function renderSalePdf(sale: FindSaleByIdReturn, isInvoice: boolean) {
	const buffer = await renderToBuffer(<SalePrintDocument sale={sale} isInvoice={isInvoice} />);
	const filename = `${isInvoice ? "Facture" : "Devis"}-${sale.clientName.replace(/\s+/g, "_")}.pdf`;
	const asciiFilename = filename.normalize("NFD").replace(/[^\x20-\x7e]|"/g, "");

	return new Response(new Uint8Array(buffer), {
		headers: {
			"Content-Type": "application/pdf",
			"Content-Disposition": `inline; filename="${asciiFilename}"; filename*=UTF-8''${encodeURIComponent(filename)}`,
		},
	});
}
