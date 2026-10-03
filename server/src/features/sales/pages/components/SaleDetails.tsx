import { amount, datetimeLong } from "@common/format";
import { Clock, MapPin } from "lucide-react";
import type { FindSaleByIdReturn } from "../../actions";
import { PaymentMethodValue } from "./PaymentMethodValue";

export const SaleDetails = ({ sale }: { sale: FindSaleByIdReturn }) => {
	return (
		<>
			<div className="p-4 rounded-xl bg-white dark:bg-surface-dark shadow-sm border border-slate-100 dark:border-white/5">
				<div className="flex justify-between items-start mb-4">
					<div>
						<h3 className="text-xl font-bold text-slate-900 dark:text-white">{sale.clientName}</h3>
						<p className="text-slate-500 dark:text-[#c9929b] text-sm flex items-center gap-2 mt-1">
							<Clock size={18} />
							{datetimeLong(sale.deliveryDatetime)}
						</p>
					</div>
					<p className="text-2xl font-black text-slate-900 dark:text-white text-right">{amount(sale.amount)}</p>
				</div>

				{sale.deliveryAddress && (
					<div className="flex items-center gap-2 py-3 border-t border-slate-100 dark:border-white/5 text-slate-600 dark:text-[#c9929b]">
						<MapPin />
						<p className="text-sm">{sale.deliveryAddress}</p>
					</div>
				)}

				{sale.description && (
					<div className="py-3 border-t border-slate-100 dark:border-white/5">
						<p className="text-sm font-medium text-slate-800 dark:text-slate-200">{sale.description}</p>
					</div>
				)}
			</div>

			{/* Articles */}
			{sale.items?.length > 0 && (
				<div className="p-4 rounded-xl bg-white dark:bg-surface-dark shadow-sm border border-slate-100 dark:border-white/5">
					<h4 className="text-slate-400 dark:text-white/40 text-[11px] font-bold uppercase tracking-widest mb-3">
						Articles
					</h4>
					<div className="space-y-2">
						{sale.items.map((item) => {
							const lineTotal = Number.parseFloat(item.unitPrice) * item.quantity;
							return (
								<div
									key={item.id}
									className="flex justify-between items-start py-2 border-b border-slate-100 dark:border-white/5 last:border-0"
								>
									<div className="flex-1">
										<p className="text-sm font-medium text-slate-800 dark:text-slate-200">{item.description}</p>
										<p className="text-xs text-slate-400 dark:text-[#c9929b]">
											{amount(item.unitPrice)} × {item.quantity}
										</p>
									</div>
									<p className="text-sm font-bold text-slate-900 dark:text-white ml-4">
										{amount(lineTotal.toFixed(2))}
									</p>
								</div>
							);
						})}
					</div>
				</div>
			)}

			{/* Payment Card */}
			<div className="p-4 rounded-xl bg-white dark:bg-surface-dark shadow-sm border border-slate-100 dark:border-white/5">
				<h4 className="text-slate-400 dark:text-white/40 text-[11px] font-bold uppercase tracking-widest mb-4">
					Paiement
				</h4>
				<div className="grid grid-cols-3 gap-2">
					<div className="bg-slate-50 dark:bg-black/20 p-3 rounded-lg text-center">
						<p className="text-[10px] text-slate-400 uppercase font-bold mb-1">Acompte</p>
						<p className="text-lg font-bold text-slate-700 dark:text-white">{amount(sale.deposit)}</p>
						<span className="text-[9px] px-1.5 py-0.5 rounded bg-blue-500/10 text-blue-400 font-bold">
							<PaymentMethodValue value={sale.depositPaymentMethod} />
						</span>
					</div>
					<div className="bg-primary/10 dark:bg-primary/20 p-3 rounded-lg text-center">
						<p className="text-[10px] text-primary uppercase font-bold mb-1">Reste</p>
						<p className="text-lg font-bold text-primary">{amount(sale.remaining)}</p>
						<span className="text-[9px] px-1.5 py-0.5 rounded bg-primary/10 text-primary font-bold">
							<PaymentMethodValue value={sale.remainingPaymentMethod} />
						</span>
					</div>
					<div className="bg-slate-50 dark:bg-black/20 p-3 rounded-lg text-center border border-primary/20">
						<p className="text-[10px] text-slate-400 uppercase font-bold mb-1">Total</p>
						<p className="text-lg font-bold text-slate-700 dark:text-white">{amount(sale.amount)}</p>
					</div>
				</div>
			</div>

			{/* Meta */}
			<p className="text-center text-slate-400 dark:text-white/40 text-xs italic">
				Créée le {datetimeLong(sale.createdAt)}
			</p>
		</>
	);
};
