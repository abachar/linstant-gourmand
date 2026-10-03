import { amount, dateShort } from "@common/format";
import { Clock, MapPin } from "lucide-react";
import type { FindSalesByRangeReturn } from "../../actions";
import { PaymentMethodValue } from "./PaymentMethodValue";

export const SaleCardContent = ({ sale }: { sale: FindSalesByRangeReturn["sales"][number] }) => {
	return (
		<div className="flex flex-col gap-3 text-left">
			<div className="flex justify-between items-start">
				<div>
					<div className="flex items-center gap-2 mb-1">
						<p className="text-slate-500 dark:text-[#c9929b] text-xs font-medium flex items-center gap-2">
							<Clock size={18} />
							{dateShort(sale.deliveryDatetime)}
						</p>
					</div>
					<h3 className="text-lg font-bold text-slate-900 dark:text-white">{sale.clientName}</h3>
				</div>
				<p className="text-xl font-black text-slate-900 dark:text-white">{amount(sale.amount)}</p>
			</div>

			{sale.deliveryAddress && (
				<div className="flex items-start gap-2 py-2 border-y border-slate-50 dark:border-white/5 text-slate-600 dark:text-[#c9929b]">
					<MapPin size={18} />
					<p className="text-sm">{sale.deliveryAddress}</p>
				</div>
			)}

			{sale.description && <p className="text-sm font-medium text-slate-800 dark:text-slate-200">{sale.description}</p>}

			<div className="grid grid-cols-3 gap-2 mt-1">
				<div className="bg-slate-50 dark:bg-black/20 p-2 rounded-lg text-center">
					<p className="text-[10px] text-slate-400 uppercase font-bold">Acompte</p>
					<p className="text-sm font-bold text-slate-700 dark:text-white">{amount(sale.deposit)}</p>
					<p className="text-[9px] text-slate-400">
						<PaymentMethodValue value={sale.depositPaymentMethod} />
					</p>
				</div>
				<div className="bg-primary/10 dark:bg-primary/20 p-2 rounded-lg text-center">
					<p className="text-[10px] text-primary uppercase font-bold">Reste</p>
					<p className="text-sm font-bold text-primary">{amount(sale.remaining)}</p>
					<p className="text-[9px] text-primary/70">
						<PaymentMethodValue value={sale.remainingPaymentMethod} />
					</p>
				</div>
				<div className="bg-slate-50 dark:bg-black/20 p-2 rounded-lg text-center border border-primary/20">
					<p className="text-[10px] text-slate-400 uppercase font-bold">Total</p>
					<p className="text-sm font-bold text-slate-700 dark:text-white">{amount(sale.amount)}</p>
				</div>
			</div>
		</div>
	);
};
