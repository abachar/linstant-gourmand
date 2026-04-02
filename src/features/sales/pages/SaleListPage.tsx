"use client";

import { PageLayout } from "@components/layouts";
import { CardList, EmptyState } from "@components/ui";
import { ShoppingBag } from "lucide-react";
import { useRouter } from "next/navigation";
import type { FindSalesByRangeReturn } from "../actions";
import { SaleCardContent, SaleListFilter } from "./components";

type Sale = FindSalesByRangeReturn["sales"][number];

export const SaleListPage = ({ sales, selectedFilter }: FindSalesByRangeReturn) => {
	const router = useRouter();

	const onCardClick = (sale: Sale) => router.push(`/sales/${sale.id}`);

	return (
		<PageLayout title="Ventes" addUrl="/sales/new">
			<SaleListFilter selectedFilter={selectedFilter} />

			{sales.length === 0 ? (
				<EmptyState
					emptyIcon={<ShoppingBag />}
					emptyLabel="Aucune vente trouvée."
					actionUrl="/sales/new"
					actionLabel="Créer une vente"
				/>
			) : (
				<CardList rows={sales} onCardClick={onCardClick}>
					{(sale) => <SaleCardContent sale={sale} />}
				</CardList>
			)}
		</PageLayout>
	);
};
