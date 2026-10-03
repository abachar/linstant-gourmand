"use client";

import { PageLayout } from "@components/layouts";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createSaleAction } from "../actions";
import { SaleForm, type SaleFormValues } from "./components/SaleForm";

export const SaleCreatePage = () => {
	const router = useRouter();
	const [isPending, setIsPending] = useState(false);

	const initialValues: SaleFormValues = {
		clientName: "",
		deliveryDatetime: "",
		deliveryAddress: "",
		description: "",
		amount: "",
		deposit: "",
		depositPaymentMethod: "Bank",
		remaining: "",
		remainingPaymentMethod: "Cash",
		items: [{ key: "0", description: "", unitPrice: "", quantity: "1" }],
	};

	async function handleSubmit(values: SaleFormValues) {
		setIsPending(true);
		try {
			const result = await createSaleAction({
				...values,
				deliveryAddress: values.deliveryAddress || undefined,
				description: values.description || undefined,
				items: values.items
					.filter((item) => item.description && item.unitPrice)
					.map((item) => ({
						description: item.description,
						unitPrice: item.unitPrice,
						quantity: Number.parseInt(item.quantity, 10) || 1,
					})),
			});
			if (!result.ok) {
				alert(result.message);
				return;
			}
			router.push(`/sales/${result.data.id}`);
		} finally {
			setIsPending(false);
		}
	}

	return (
		<PageLayout title="Nouvelle vente" withCancel={true}>
			<SaleForm
				initialValues={initialValues}
				onSubmit={handleSubmit}
				submitLabel="Enregistrer la vente"
				cancelHref="/sales/"
				isPending={isPending}
			/>
		</PageLayout>
	);
};
