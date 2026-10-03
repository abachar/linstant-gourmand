import { Trash2 } from "lucide-react";

export interface SaleItemValues {
	key: string;
	description: string;
	unitPrice: string;
	quantity: string;
}

interface SaleItemRowProps {
	item: SaleItemValues;
	index: number;
	onChange: (index: number, field: keyof SaleItemValues, value: string) => void;
	onRemove: (index: number) => void;
	canRemove: boolean;
}

export const SaleItemRow = ({ item, index, onChange, onRemove, canRemove }: SaleItemRowProps) => {
	const lineTotal = (Number.parseFloat(item.unitPrice) || 0) * (Number.parseInt(item.quantity, 10) || 0);

	return (
		<div className="p-3 rounded-lg border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark space-y-3">
			<div className="flex items-start justify-between gap-2">
				<input
					type="text"
					value={item.description}
					onChange={(e) => onChange(index, "description", e.currentTarget.value)}
					placeholder="Ex: Plateau finger food premium"
					className="form-input flex-1 rounded-lg text-sm text-slate-900 dark:text-white bg-slate-50 dark:bg-black/20 border-slate-200 dark:border-[#67323b] px-3 py-2 focus:ring-primary/50 focus:ring-2 focus:outline-0"
				/>
				{canRemove && (
					<button
						type="button"
						onClick={() => onRemove(index)}
						className="p-2 text-slate-400 hover:text-primary transition-colors"
					>
						<Trash2 size={16} />
					</button>
				)}
			</div>
			<div className="flex gap-2 items-center">
				<label className="flex-1">
					<span className="text-[10px] text-slate-400 uppercase font-bold">Prix unit.</span>
					<input
						type="number"
						step="0.01"
						value={item.unitPrice}
						onChange={(e) => onChange(index, "unitPrice", e.currentTarget.value)}
						placeholder="0.00"
						className="form-input w-full rounded-lg text-sm font-bold text-slate-900 dark:text-white bg-slate-50 dark:bg-black/20 border-slate-200 dark:border-[#67323b] px-3 py-2 focus:ring-primary/50 focus:ring-2 focus:outline-0"
					/>
				</label>
				<label className="w-20">
					<span className="text-[10px] text-slate-400 uppercase font-bold">Qté</span>
					<input
						type="number"
						min="1"
						value={item.quantity}
						onChange={(e) => onChange(index, "quantity", e.currentTarget.value)}
						placeholder="1"
						className="form-input w-full rounded-lg text-sm font-bold text-center text-slate-900 dark:text-white bg-slate-50 dark:bg-black/20 border-slate-200 dark:border-[#67323b] px-3 py-2 focus:ring-primary/50 focus:ring-2 focus:outline-0"
					/>
				</label>
				<div className="w-24 text-right pt-4">
					<p className="text-sm font-bold text-slate-900 dark:text-white">
						{lineTotal > 0 ? `${lineTotal.toFixed(2)} €` : "—"}
					</p>
				</div>
			</div>
		</div>
	);
};
