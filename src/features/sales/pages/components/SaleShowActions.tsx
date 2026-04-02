"use client";

import { deleteSaleByIdAction, type FindSaleByIdReturn } from "@features/sales";
import { useMutation } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Pencil, Trash2 } from "lucide-react";

export const SaleShowActions = ({ sale }: { sale: FindSaleByIdReturn }) => {
	const router = useRouter();

	const { mutate: deleteSale } = useMutation({
		mutationFn: () => deleteSaleByIdAction(sale.id),
		onSuccess: () => router.push("/sales"),
	});

	const onDeleteClick = () => {
		if (!confirm("Supprimer cette vente ?")) return;
		deleteSale();
	};

	return (
		<div className="flex gap-3 pt-4">
			<Link
				href={`/sales/${sale.id}/edit`}
				className="flex-1 h-12 rounded-xl bg-slate-100 dark:bg-white/5 text-slate-700 dark:text-white font-bold text-sm flex items-center justify-center gap-2"
			>
				<Pencil size={18} /> Modifier
			</Link>
			<button
				type="button"
				onClick={onDeleteClick}
				className="flex-1 h-12 rounded-xl bg-primary/10 text-primary font-bold text-sm flex items-center justify-center gap-2"
			>
				<Trash2 size={18} /> Supprimer
			</button>
		</div>
	);
};
