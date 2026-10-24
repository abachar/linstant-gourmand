import { Document, Font, Page } from "@react-pdf/renderer";
import {
	PrintEventLine,
	PrintFooter,
	PrintGrandTotal,
	PrintHeader,
	PrintInfoSection,
	PrintItemsTable,
} from "./components";
import type { PrintSale } from "./types";

Font.register({
	family: "Helvetica",
	fonts: [{ src: "Helvetica" }, { src: "Helvetica-Bold", fontWeight: "bold" }],
});

interface SalePrintDocumentProps {
	/** One sale for a plain quote/invoice, several for a grouped invoice (same client, same month). */
	sales: PrintSale[];
	isInvoice: boolean;
}

export const SalePrintDocument = ({ sales, isInvoice = false }: SalePrintDocumentProps) => {
	const grouped = sales.length > 1;
	const [first] = sales;

	return (
		<Document>
			<Page size="A4" style={{ padding: 40, paddingBottom: 100, fontSize: 10, fontFamily: "Helvetica", color: "#333" }}>
				<PrintHeader isInvoice={isInvoice} />
				<PrintInfoSection
					clientName={first.clientName}
					isInvoice={isInvoice}
					period={grouped ? first.deliveryDatetime : null}
				/>
				{sales.map((sale) => (
					<PrintEventLine key={sale.id} datetime={sale.deliveryDatetime} address={sale.deliveryAddress}>
						<PrintItemsTable items={sale.items} totalLabel={grouped ? "Sous-total :" : "Total :"} />
					</PrintEventLine>
				))}
				{grouped && <PrintGrandTotal sales={sales} />}
				<PrintFooter />
			</Page>
		</Document>
	);
};
