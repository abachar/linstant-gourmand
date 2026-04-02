"use client";

import { PageLayout } from "@components/layouts";
import { CardList, EmptyState } from "@components/ui";
import { useMutation } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { ShoppingBasket } from "lucide-react";
import type { FindAllPurchasesReturn } from "../actions";
import { deletePurchaseByIdAction } from "../actions";
import { HeaderUploadButton, PurchaseCardContent, PurchaseListFilter } from "./components";

export const PurchaseListPage = (props: FindAllPurchasesReturn) => {
	const router = useRouter();
	const { mutate: deletePurchase } = useMutation({
		mutationFn: (id: string) => deletePurchaseByIdAction(id),
		onSuccess: () => router.refresh(),
	});

	const onEditClick = (purchase: FindAllPurchasesReturn["purchases"][number]) =>
		router.push(`/purchases/${purchase.id}/edit`);

	const onDeleteClick = (purchase: FindAllPurchasesReturn["purchases"][number]) => {
		if (!confirm("Supprimer cet achat ?")) return;
		deletePurchase(purchase.id);
	};

	return (
		<PageLayout title="Achats" addUrl="/purchases/new" moreActions={<HeaderUploadButton />}>
			<PurchaseListFilter availableYears={props.availableYears} selectedYear={props.selectedYear} />

			{props.purchases.length === 0 ? (
				<EmptyState
					emptyIcon={<ShoppingBasket />}
					emptyLabel="Aucun achat trouvé."
					actionUrl="/purchases/new"
					actionLabel="Créer un achat"
				/>
			) : (
				<CardList
					rows={props.purchases}
					onEditClick={onEditClick}
					onDeleteClick={onDeleteClick}
					canEdit={(p) => !p.isImported}
					canDelete={(p) => !p.isImported}
				>
					{(purchase) => <PurchaseCardContent purchase={purchase} />}
				</CardList>
			)}
		</PageLayout>
	);
};
