"use client";

import { formatDateInput } from "@common/format/date";
import { PageLayout } from "@components/layouts";
import { useRouter } from "next/navigation";
import { useState } from "react";
import type { FindPurchaseByIdReturn } from "../actions";
import { updatePurchaseAction } from "../actions";

export const PurchaseEditPage = ({ purchase }: { purchase: FindPurchaseByIdReturn }) => {
	const router = useRouter();
	const [date, setDate] = useState(formatDateInput(purchase.date));
	const [amount, setAmount] = useState(purchase.amount);
	const [description, setDescription] = useState(purchase.description ?? "");
	const [isPending, setIsPending] = useState(false);

	async function handleSubmit(e: React.FormEvent) {
		e.preventDefault();
		setIsPending(true);
		try {
			await updatePurchaseAction({
				id: purchase.id,
				date,
				amount,
				description: description || undefined,
			});
			router.push("/purchases/");
		} finally {
			setIsPending(false);
		}
	}

	return (
		<PageLayout title="Modifier l'achat" withCancel={true}>
			<form onSubmit={handleSubmit} className="space-y-6">
				<div className="space-y-4">
					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Date <span className="text-primary">*</span>
						</p>
						<div className="flex w-full items-center rounded-lg border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark h-14 px-4">
							<input
								type="date"
								required
								value={date}
								onChange={(e) => setDate(e.currentTarget.value)}
								className="bg-transparent border-none text-slate-900 dark:text-white w-full focus:ring-0 p-0 text-base"
							/>
						</div>
					</label>

					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Montant (€) <span className="text-primary">*</span>
						</p>
						<input
							type="number"
							step="0.01"
							required
							value={amount}
							onChange={(e) => setAmount(e.currentTarget.value)}
							placeholder="0.00"
							className="form-input w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark h-14 placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 text-base font-normal"
						/>
					</label>

					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">Description</p>
						<textarea
							rows={3}
							value={description}
							onChange={(e) => setDescription(e.currentTarget.value)}
							placeholder="Ex: Achat ingrédients, fournitures..."
							className="form-textarea w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark min-h-[100px] placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 py-3 text-base font-normal resize-none"
						/>
					</label>
				</div>

				<div className="flex gap-3 pt-4">
					<a
						href="/purchases/"
						className="flex-1 h-14 rounded-xl border border-slate-300 dark:border-[#67323b] text-slate-700 dark:text-white font-bold text-base flex items-center justify-center hover:bg-slate-100 dark:hover:bg-white/5 transition-colors"
					>
						Annuler
					</a>
					<button
						type="submit"
						disabled={isPending}
						className="flex-2 h-14 rounded-xl bg-primary text-white font-bold text-base shadow-lg shadow-primary/25 active:scale-95 transition-transform disabled:opacity-50"
					>
						Enregistrer
					</button>
				</div>
			</form>
		</PageLayout>
	);
};
