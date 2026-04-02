import { PageLayout } from "@components/layouts";
import type { FindSaleByIdReturn } from "../actions";
import { SaleDetails, SaleShowActions } from "./components";

export const SaleShowPage = ({ sale }: { sale: FindSaleByIdReturn }) => {
	return (
		<PageLayout title={`Vente - ${sale.clientName}`} withCancel={true}>
			<div className="space-y-4">
				<SaleDetails sale={sale} />
				<SaleShowActions sale={sale} />
			</div>
		</PageLayout>
	);
};
