"use client";

import { PageLayout } from "@components/layouts";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createProductAction } from "../actions";

export const ProductCreatePage = () => {
	const router = useRouter();
	const [productName, setProductName] = useState("");
	const [quantity, setQuantity] = useState("0");
	const [expirationDate, setExpirationDate] = useState("");
	const [isPending, setIsPending] = useState(false);

	async function handleSubmit(e: React.FormEvent) {
		e.preventDefault();
		setIsPending(true);
		try {
			await createProductAction({
				productName,
				quantity: parseInt(quantity, 10),
				expirationDate: expirationDate || null,
			});
			router.push("/products/");
		} finally {
			setIsPending(false);
		}
	}

	return (
		<PageLayout title="Ajouter au stock" withCancel={true}>
			<form onSubmit={handleSubmit} className="space-y-6">
				<div className="space-y-4">
					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Nom du produit <span className="text-primary">*</span>
						</p>
						<input
							type="text"
							required
							value={productName}
							onChange={(e) => setProductName(e.currentTarget.value)}
							placeholder="Ex: Mini Burger Poulet"
							className="form-input w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark h-14 placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 text-base font-normal"
						/>
					</label>

					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Quantité <span className="text-primary">*</span>
						</p>
						<input
							type="number"
							required
							value={quantity}
							onChange={(e) => setQuantity(e.currentTarget.value)}
							className="form-input w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark h-14 placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 text-base font-normal"
						/>
					</label>

					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Date limite de consommation
						</p>
						<input
							type="date"
							value={expirationDate}
							onChange={(e) => setExpirationDate(e.currentTarget.value)}
							className="form-input w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark h-14 placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 text-base font-normal"
						/>
					</label>
				</div>

				<div className="flex gap-3 pt-4">
					<a
						href="/products/"
						className="flex-1 h-14 rounded-xl border border-slate-300 dark:border-[#67323b] text-slate-700 dark:text-white font-bold text-base flex items-center justify-center hover:bg-slate-100 dark:hover:bg-white/5 transition-colors"
					>
						Annuler
					</a>
					<button
						type="submit"
						disabled={isPending}
						className="flex-2 h-14 rounded-xl bg-primary text-white font-bold text-base shadow-lg shadow-primary/25 active:scale-95 transition-transform disabled:opacity-50"
					>
						Ajouter
					</button>
				</div>
			</form>
		</PageLayout>
	);
};
