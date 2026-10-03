"use client";

import { deleteSaleByIdAction, type FindSaleByIdReturn } from "@features/sales";
import { useMutation } from "@tanstack/react-query";
import { FileText, Pencil, Trash2 } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";

export const SaleShowActions = ({ sale }: { sale: FindSaleByIdReturn }) => {
	const router = useRouter();

	const { mutate: deleteSale } = useMutation({
		mutationFn: () => deleteSaleByIdAction(sale.id, sale.version),
		onSuccess: (result) => (result.ok ? router.push("/sales") : alert(result.message)),
	});

	const onDeleteClick = () => {
		if (!confirm("Supprimer cette vente ?")) return;
		deleteSale();
	};

	return (
		<div className="grid grid-cols-2 gap-3 pt-4">
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
			{sale.items.length > 0 &&
				(new Date(sale.deliveryDatetime) > new Date() ? (
					<a
						href={`/sales/${sale.id}/print`}
						target="_blank"
						rel="noopener noreferrer"
						className="col-span-2 h-12 rounded-xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 font-bold text-sm flex items-center justify-center gap-2"
					>
						<FileText size={18} /> Devis
					</a>
				) : (
					<a
						href={`/sales/${sale.id}/print?type=invoice`}
						target="_blank"
						rel="noopener noreferrer"
						className="col-span-2 h-12 rounded-xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 font-bold text-sm flex items-center justify-center gap-2"
					>
						<FileText size={18} /> Facture
					</a>
				))}
		</div>
	);
};
