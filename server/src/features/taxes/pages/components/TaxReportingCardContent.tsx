import { amount } from "@common/format";
import type { FindTaxReportingReturn } from "../../actions";

type MonthlyItem = FindTaxReportingReturn["monthlyItems"][0];

export const TaxReportingCardContent = ({ monthlyItem }: { monthlyItem: MonthlyItem }) => {
	return (
		<>
			<div className="flex justify-between items-center mb-3">
				<p className="text-slate-900 dark:text-white text-base font-bold">{monthlyItem.monthLabel}</p>
				<p className="text-xl font-black text-slate-900 dark:text-white tabular-nums">
					{amount(monthlyItem.totalAmount)}
				</p>
			</div>
			<div className="grid grid-cols-3 gap-2">
				<div className="bg-blue-50 dark:bg-blue-500/10 p-2 rounded-lg text-center">
					<p className="text-[10px] text-blue-400 uppercase font-bold mb-0.5">Bancaire</p>
					<p className="text-sm font-bold text-blue-600 dark:text-blue-400 tabular-nums">
						{amount(monthlyItem.bankTotalAmount)}
					</p>
				</div>
				<div className="bg-emerald-50 dark:bg-emerald-500/10 p-2 rounded-lg text-center">
					<p className="text-[10px] text-emerald-500 uppercase font-bold mb-0.5">Espèces</p>
					<p className="text-sm font-bold text-emerald-600 dark:text-emerald-400 tabular-nums">
						{amount(monthlyItem.cashTotalAmount)}
					</p>
				</div>
				<div className="bg-primary/10 dark:bg-primary/20 p-2 rounded-lg text-center">
					<p className="text-[10px] text-primary uppercase font-bold mb-0.5">TVA 12.3%</p>
					<p className="text-sm font-bold text-primary tabular-nums">{amount(monthlyItem.taxAmount)}</p>
				</div>
			</div>
		</>
	);
};
