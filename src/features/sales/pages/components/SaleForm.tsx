"use client";

import { CreditCard, HandCoins } from "lucide-react";
import { useState } from "react";
import { ClientAutocomplete } from "./ClientAutocomplete";
import { PaymentMethodValue } from "./PaymentMethodValue";

const PAYMENT_METHODS = ["Bank", "Cash"] as const;

export interface SaleFormValues {
	clientName: string;
	deliveryDatetime: string;
	deliveryAddress: string;
	description: string;
	amount: string;
	deposit: string;
	depositPaymentMethod: string;
	remaining: string;
	remainingPaymentMethod: string;
}

interface SaleFormProps {
	initialValues: SaleFormValues;
	onSubmit: (values: SaleFormValues) => Promise<void>;
	submitLabel: string;
	cancelHref: string;
	isPending: boolean;
}

export const SaleForm = (props: SaleFormProps) => {
	const [values, setValues] = useState<SaleFormValues>(props.initialValues);

	function set(key: keyof SaleFormValues, value: string) {
		setValues((prev) => ({ ...prev, [key]: value }));
	}

	function onClientSelect(clientName: string, deliveryAddress?: string) {
		setValues((prev) => ({
			...prev,
			clientName,
			deliveryAddress: deliveryAddress ?? prev.deliveryAddress,
		}));
	}

	function onAmountChange(amountVal: string) {
		const a = parseFloat(amountVal) || 0;
		const remaining = Math.ceil((a * 0.7) / 10) * 10;
		const deposit = a - remaining;
		setValues((prev) => ({
			...prev,
			amount: amountVal,
			deposit: deposit.toFixed(2),
			remaining: remaining.toFixed(2),
		}));
	}

	function onDepositChange(depositVal: string) {
		const a = parseFloat(values.amount) || 0;
		const d = parseFloat(depositVal) || 0;
		setValues((prev) => ({ ...prev, deposit: depositVal, remaining: (a - d).toFixed(2) }));
	}

	async function handleSubmit(e: React.FormEvent) {
		e.preventDefault();
		await props.onSubmit({ ...values });
	}

	return (
		<form onSubmit={handleSubmit} className="space-y-6">
			{/* Client */}
			<div>
				<h3 className="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-[-0.015em] pb-2">
					Informations Client
				</h3>
				<div className="flex flex-col gap-4">
					<div className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Nom du client <span className="text-primary">*</span>
						</p>
						<ClientAutocomplete value={values.clientName} onChange={onClientSelect} />
					</div>
					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Adresse de livraison
						</p>
						<textarea
							rows={2}
							value={values.deliveryAddress}
							onChange={(e) => set("deliveryAddress", e.currentTarget.value)}
							placeholder="15 Rue de Rivoli, Paris"
							className="form-textarea w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 py-3 text-base font-normal resize-none"
						/>
					</label>
				</div>
			</div>

			{/* Logistique */}
			<div>
				<h3 className="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-[-0.015em] pb-2">
					Logistique
				</h3>
				<div>
					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Date et heure de livraison <span className="text-primary">*</span>
						</p>
						<div className="flex w-full items-center rounded-lg border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark h-14 px-4">
							<input
								type="datetime-local"
								required
								value={values.deliveryDatetime}
								onChange={(e) => set("deliveryDatetime", e.currentTarget.value)}
								className="bg-transparent border-none text-slate-900 dark:text-white w-full focus:ring-0 p-0 text-base"
							/>
						</div>
					</label>
				</div>
			</div>

			{/* Commande */}
			<div>
				<h3 className="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-[-0.015em] pb-2">
					Détails Commande
				</h3>
				<div>
					<label className="flex flex-col">
						<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
							Description des produits
						</p>
						<textarea
							rows={3}
							value={values.description}
							onChange={(e) => set("description", e.currentTarget.value)}
							placeholder="Ex: 20 Mini-burgers, 15 Navettes saumon..."
							className="form-textarea w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark min-h-[100px] placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 py-3 text-base font-normal resize-none"
						/>
					</label>
				</div>
			</div>

			{/* Paiement */}
			<div>
				<h3 className="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-[-0.015em] pb-2">
					Paiement
				</h3>
				<div className="space-y-6">
					<div className="bg-primary/5 dark:bg-primary/10 rounded-xl p-5 border border-primary/20">
						<div className="space-y-4">
							{/* Montant total */}
							<label className="flex flex-col">
								<p className="text-primary font-bold text-sm mb-2">
									Montant Total (€) <span className="text-primary">*</span>
								</p>
								<input
									type="number"
									step="0.01"
									required
									value={values.amount}
									onChange={(e) => onAmountChange(e.currentTarget.value)}
									placeholder="0.00"
									className="form-input w-full rounded-lg text-lg font-bold bg-white dark:bg-background-dark border-primary/30 text-slate-900 dark:text-white focus:ring-primary px-4 py-3"
								/>
							</label>

							{/* Acompte */}
							<label className="flex flex-col pt-2 border-t border-primary/10 space-y-2">
								<p className="text-primary font-bold text-sm">Acompte (~30%) *</p>
								<div className="flex gap-2">
									<input
										type="number"
										step="0.01"
										required
										value={values.deposit}
										onChange={(e) => onDepositChange(e.currentTarget.value)}
										placeholder="0.00"
										className="form-input w-full rounded-lg text-lg font-bold bg-white dark:bg-background-dark border-primary/30 text-slate-900 dark:text-white focus:ring-primary px-4 py-3"
									/>
									{PAYMENT_METHODS.map((method) => (
										<label key={method} className="cursor-pointer">
											<input
												type="radio"
												name="deposit_payment_method"
												value={method}
												checked={values.depositPaymentMethod === method}
												onChange={() => set("depositPaymentMethod", method)}
												className="peer hidden"
											/>
											<div className="peer-checked:border-primary peer-checked:border-2 peer-checked:bg-primary peer-checked:text-white flex flex-col items-center justify-center p-3 rounded-xl border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark text-slate-600 dark:text-slate-400 transition-all">
												{method === "Bank" ? <CreditCard /> : <HandCoins />}
												<span className="text-xs font-bold mt-1">
													<PaymentMethodValue value={method} />
												</span>
											</div>
										</label>
									))}
								</div>
							</label>

							{/* Solde */}
							<label className="flex flex-col pt-2 border-t border-primary/10 space-y-2">
								<p className="text-slate-500 dark:text-slate-400 font-bold text-sm">Solde (70%)</p>
								<div className="flex gap-2">
									<input
										type="number"
										step="0.01"
										readOnly
										value={values.remaining}
										placeholder="0.00"
										className="form-input w-full rounded-lg text-lg font-bold bg-white dark:bg-background-dark border-primary/30 text-slate-900 dark:text-white focus:ring-primary px-4 py-3"
									/>
									{PAYMENT_METHODS.map((method) => (
										<label key={method} className="cursor-pointer">
											<input
												type="radio"
												name="remaining_payment_method"
												value={method}
												checked={values.remainingPaymentMethod === method}
												onChange={() => set("remainingPaymentMethod", method)}
												className="peer hidden"
											/>
											<div className="peer-checked:border-primary peer-checked:border-2 peer-checked:bg-primary peer-checked:text-white flex flex-col items-center justify-center p-3 rounded-xl border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark text-slate-600 dark:text-slate-400 transition-all">
												{method === "Bank" ? <CreditCard /> : <HandCoins />}
												<span className="text-xs font-bold mt-1">
													<PaymentMethodValue value={method} />
												</span>
											</div>
										</label>
									))}
								</div>
							</label>
						</div>
					</div>
				</div>
			</div>

			{/* Footer */}
			<div className="flex gap-3 pt-4">
				<a
					href={props.cancelHref}
					className="flex-1 h-14 rounded-xl border border-slate-300 dark:border-[#67323b] text-slate-700 dark:text-white font-bold text-base flex items-center justify-center hover:bg-slate-100 dark:hover:bg-white/5 transition-colors"
				>
					Annuler
				</a>
				<button
					type="submit"
					disabled={props.isPending}
					className="flex-2 h-14 rounded-xl bg-primary text-white font-bold text-base shadow-lg shadow-primary/25 active:scale-95 transition-transform disabled:opacity-50"
				>
					{props.submitLabel}
				</button>
			</div>
		</form>
	);
};
