"use client";

import { amount, datetimeLong, monthYear } from "@common/format";
import { PageLayout } from "@components/layouts";
import { Check, FileText, MapPin } from "lucide-react";
import { useState } from "react";
import type { FindInvoiceCandidatesReturn } from "../actions";

/** Picks the sales of the month to put on one invoice: all of them by default. */
export const SaleInvoicePage = ({ sale, candidates }: FindInvoiceCandidatesReturn) => {
	const [selected, setSelected] = useState<Set<string>>(() => new Set(candidates.map((c) => c.id)));

	const toggle = (id: string) =>
		setSelected((prev) => {
			const next = new Set(prev);
			if (!next.delete(id)) next.add(id);
			return next;
		});

	const chosen = candidates.filter((c) => selected.has(c.id));
	const total = chosen.reduce((sum, c) => sum + Number(c.amount), 0);
	const ids = chosen.map((c) => c.id).join(",");

	return (
		<PageLayout title={`Facture - ${sale.clientName}`} withCancel={true}>
			<div className="space-y-4">
				<p className="text-sm text-slate-500 dark:text-[#c9929b]">
					Ventes de {sale.clientName} livrées en {monthYear(sale.deliveryDatetime)}. Décochez celles à exclure de la
					facture.
				</p>

				<div className="space-y-3">
					{candidates.map((candidate) => {
						const checked = selected.has(candidate.id);
						return (
							<button
								type="button"
								key={candidate.id}
								onClick={() => toggle(candidate.id)}
								aria-pressed={checked}
								className={`w-full text-left p-3 rounded-xl border flex items-start gap-3 transition-colors ${
									checked
										? "bg-white dark:bg-surface-dark border-primary/40"
										: "bg-slate-50 dark:bg-black/20 border-slate-200 dark:border-border-dark opacity-60"
								}`}
							>
								<span
									className={`mt-0.5 size-6 shrink-0 rounded-md border-2 flex items-center justify-center ${
										checked ? "bg-primary border-primary text-white" : "border-slate-300 dark:border-white/20"
									}`}
								>
									{checked && <Check size={16} strokeWidth={3} />}
								</span>
								<span className="flex-1 min-w-0">
									<span className="flex justify-between items-start gap-3">
										<span className="text-sm font-medium text-slate-800 dark:text-slate-200">
											{datetimeLong(candidate.deliveryDatetime)}
										</span>
										<span className="text-base font-black text-slate-900 dark:text-white">
											{amount(candidate.amount)}
										</span>
									</span>
									{candidate.deliveryAddress && (
										<span className="mt-1 flex items-center gap-1 text-xs text-slate-500 dark:text-[#c9929b]">
											<MapPin size={14} /> {candidate.deliveryAddress}
										</span>
									)}
									<span className="mt-1 block text-xs text-slate-400">
										{candidate.items.length} article{candidate.items.length > 1 ? "s" : ""}
									</span>
								</span>
							</button>
						);
					})}
				</div>

				<div className="p-4 rounded-xl bg-white dark:bg-surface-dark shadow-sm border border-slate-100 dark:border-white/5 flex justify-between items-center">
					<span className="text-sm font-bold text-slate-500 dark:text-[#c9929b]">
						{chosen.length} vente{chosen.length > 1 ? "s" : ""}
					</span>
					<span className="text-xl font-black text-slate-900 dark:text-white">{amount(total)}</span>
				</div>

				{chosen.length > 0 ? (
					<a
						href={`/sales/print?ids=${ids}&type=invoice`}
						target="_blank"
						rel="noopener noreferrer"
						className="h-12 rounded-xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 font-bold text-sm flex items-center justify-center gap-2"
					>
						<FileText size={18} /> Ouvrir la facture
					</a>
				) : (
					<p className="h-12 rounded-xl bg-slate-100 dark:bg-white/5 text-slate-400 font-bold text-sm flex items-center justify-center">
						Sélectionnez au moins une vente
					</p>
				)}
			</div>
		</PageLayout>
	);
};
