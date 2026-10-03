"use client";

import { CreditCard, HandCoins, Plus } from "lucide-react";
import { useRef, useState } from "react";
import { ClientAutocomplete } from "./ClientAutocomplete";
import { PaymentMethodValue } from "./PaymentMethodValue";
import { SaleItemRow, type SaleItemValues } from "./SaleItemRow";

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
	items: SaleItemValues[];
}

interface SaleFormProps {
	initialValues: SaleFormValues;
	onSubmit: (values: SaleFormValues) => Promise<void>;
	submitLabel: string;
	cancelHref: string;
	isPending: boolean;
}

function computeTotal(items: SaleItemValues[]) {
	return items.reduce((sum, item) => {
		return sum + (Number.parseFloat(item.unitPrice) || 0) * (Number.parseInt(item.quantity, 10) || 0);
	}, 0);
}

function computePayment(total: number) {
	// ~70% rounded up to the ten, never more than the total (deposit would be negative)
	const remaining = Math.min(total, Math.ceil((total * 0.7) / 10) * 10);
	const deposit = total - remaining;
	return { deposit, remaining };
}

export const SaleForm = (props: SaleFormProps) => {
	const keyCounter = useRef(props.initialValues.items.length);
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

	function updateItemsAndTotal(newItems: SaleItemValues[]) {
		const total = computeTotal(newItems);
		const { deposit, remaining } = computePayment(total);
		setValues((prev) => ({
			...prev,
			items: newItems,
			amount: total.toFixed(2),
			deposit: deposit.toFixed(2),
			remaining: remaining.toFixed(2),
		}));
	}

	function onItemChange(index: number, field: keyof SaleItemValues, value: string) {
		const newItems = [...values.items];
		newItems[index] = { ...newItems[index], [field]: value };
		updateItemsAndTotal(newItems);
	}

	function addItem() {
		keyCounter.current += 1;
		updateItemsAndTotal([
			...values.items,
			{ key: String(keyCounter.current), description: "", unitPrice: "", quantity: "1" },
		]);
	}

	function removeItem(index: number) {
		updateItemsAndTotal(values.items.filter((_, i) => i !== index));
	}

	function onDepositChange(depositVal: string) {
		const a = Number.parseFloat(values.amount) || 0;
		const d = Number.parseFloat(depositVal) || 0;
		setValues((prev) => ({ ...prev, deposit: depositVal, remaining: (a - d).toFixed(2) }));
	}

	async function handleSubmit(e: React.FormEvent) {
		e.preventDefault();
		await props.onSubmit({ ...values });
	}

	const total = computeTotal(values.items);

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

			{/* Articles */}
			<div>
				<h3 className="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-[-0.015em] pb-2">
					Articles
				</h3>
				<div className="space-y-3">
					{values.items.map((item, index) => (
						<SaleItemRow
							key={item.key}
							item={item}
							index={index}
							onChange={onItemChange}
							onRemove={removeItem}
							canRemove={values.items.length > 1}
						/>
					))}
					<button
						type="button"
						onClick={addItem}
						className="w-full h-10 rounded-lg border-2 border-dashed border-slate-300 dark:border-[#67323b] text-slate-500 dark:text-[#c9929b] font-bold text-sm flex items-center justify-center gap-2 hover:border-primary hover:text-primary transition-colors"
					>
						<Plus size={16} /> Ajouter un article
					</button>

					{/* Total */}
					<div className="flex justify-between items-center px-3 py-2 bg-slate-50 dark:bg-black/20 rounded-lg">
						<span className="text-sm font-bold text-slate-600 dark:text-slate-300">Total</span>
						<span className="text-lg font-black text-slate-900 dark:text-white">{total.toFixed(2)} €</span>
					</div>
				</div>

				{/* Notes */}
				<label className="flex flex-col mt-4">
					<p className="text-slate-700 dark:text-slate-300 text-sm font-medium leading-normal pb-2">
						Notes (optionnel)
					</p>
					<textarea
						rows={2}
						value={values.description}
						onChange={(e) => set("description", e.currentTarget.value)}
						placeholder="Informations complémentaires..."
						className="form-textarea w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 py-3 text-base font-normal resize-none"
					/>
				</label>
			</div>

			{/* Paiement */}
			<div>
				<h3 className="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-[-0.015em] pb-2">
					Paiement
				</h3>
				<div className="space-y-6">
					<div className="bg-primary/5 dark:bg-primary/10 rounded-xl p-5 border border-primary/20">
						<div className="space-y-4">
							{/* Montant total (read-only, computed from items) */}
							<div className="flex flex-col">
								<p className="text-primary font-bold text-sm mb-2">Montant Total (€)</p>
								<input
									type="number"
									step="0.01"
									readOnly
									value={values.amount}
									className="form-input w-full rounded-lg text-lg font-bold bg-slate-100 dark:bg-background-dark border-primary/30 text-slate-900 dark:text-white px-4 py-3 cursor-not-allowed"
								/>
							</div>

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
											<div className="peer-checked:border-primary peer-checked:bg-primary peer-checked:text-white flex flex-col items-center justify-center p-3 rounded-xl border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark text-slate-600 dark:text-slate-400 transition-all">
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
											<div className="peer-checked:border-primary peer-checked:bg-primary peer-checked:text-white flex flex-col items-center justify-center p-3 rounded-xl border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark text-slate-600 dark:text-slate-400 transition-all">
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
