import { PageLayout } from "@components/layouts";
import type { FindSaleByIdReturn } from "../actions";
import { SaleDetails, SaleShowActions } from "./components";

type SaleShowPageProps = {
	sale: FindSaleByIdReturn;
	/** Other sales of the client the same month can be invoiced together with this one. */
	canGroupInvoice: boolean;
};

export const SaleShowPage = ({ sale, canGroupInvoice }: SaleShowPageProps) => {
	return (
		<PageLayout title={`Vente - ${sale.clientName}`} withCancel={true}>
			<div className="space-y-4">
				<SaleDetails sale={sale} />
				<SaleShowActions sale={sale} canGroupInvoice={canGroupInvoice} />
			</div>
		</PageLayout>
	);
};
