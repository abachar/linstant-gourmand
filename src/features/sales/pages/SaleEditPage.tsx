"use client";

import { formatDatetimeLocal } from "@common/format/date";
import { PageLayout } from "@components/layouts";
import { useRouter } from "next/navigation";
import { useState } from "react";
import type { FindSaleByIdReturn } from "../actions";
import { updateSaleAction } from "../actions";
import { SaleForm, type SaleFormValues } from "./components/SaleForm";

export const SaleEditPage = ({ sale }: { sale: FindSaleByIdReturn }) => {
	const router = useRouter();
	const [isPending, setIsPending] = useState(false);

	const initialValues: SaleFormValues = {
		clientName: sale.clientName,
		deliveryDatetime: formatDatetimeLocal(sale.deliveryDatetime),
		deliveryAddress: sale.deliveryAddress ?? "",
		description: sale.description ?? "",
		amount: sale.amount,
		deposit: sale.deposit,
		depositPaymentMethod: sale.depositPaymentMethod,
		remaining: sale.remaining,
		remainingPaymentMethod: sale.remainingPaymentMethod,
	};

	async function handleSubmit(values: SaleFormValues) {
		setIsPending(true);
		try {
			await updateSaleAction({
				id: sale.id,
				...values,
				deliveryAddress: values.deliveryAddress || undefined,
				description: values.description || undefined,
			});
			router.push(`/sales/${sale.id}`);
		} finally {
			setIsPending(false);
		}
	}

	return (
		<PageLayout title="Modifier vente" withCancel={true}>
			<SaleForm
				initialValues={initialValues}
				onSubmit={handleSubmit}
				submitLabel="Enregistrer"
				cancelHref={`/sales/${sale.id}`}
				isPending={isPending}
			/>
		</PageLayout>
	);
};
