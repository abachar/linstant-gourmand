import { Document, Font, Page } from "@react-pdf/renderer";
import type { FindSaleByIdReturn } from "../actions";
import { PrintEventLine, PrintFooter, PrintHeader, PrintInfoSection, PrintItemsTable } from "./components";

Font.register({
	family: "Helvetica",
	fonts: [{ src: "Helvetica" }, { src: "Helvetica-Bold", fontWeight: "bold" }],
});

interface SalePrintDocumentProps {
	sale: FindSaleByIdReturn;
	isInvoice: boolean;
}

export const SalePrintDocument = ({ sale, isInvoice = false }: SalePrintDocumentProps) => (
	<Document>
		<Page size="A4" style={{ padding: 40, fontSize: 10, fontFamily: "Helvetica", color: "#333" }}>
			<PrintHeader isInvoice={isInvoice} />
			<PrintInfoSection clientName={sale.clientName} isInvoice={isInvoice} />
			<PrintEventLine datetime={sale.deliveryDatetime} address={sale.deliveryAddress} />
			<PrintItemsTable items={sale.items} />
			<PrintFooter />
		</Page>
	</Document>
);
