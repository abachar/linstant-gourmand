import { amount, dateShort } from "@common/format";
import { CloudDownload } from "lucide-react";
import type { FindAllPurchasesReturn } from "../../actions";

export const PurchaseCardContent = ({ purchase }: { purchase: FindAllPurchasesReturn["purchases"][number] }) => (
	<div className="flex flex-col flex-1 min-w-0">
		<div className="flex justify-between items-center">
			<p className="text-slate-900 dark:text-white text-base font-semibold leading-normal">
				{dateShort(purchase.date)}
			</p>
			<p className="text-slate-900 dark:text-white text-base font-bold">{amount(purchase.amount)}</p>
		</div>
		<div className="mt-2 flex items-center gap-2">
			{purchase.isImported && <CloudDownload size={16} className="text-slate-400 dark:text-white/30" />}
			<p className="text-slate-500 dark:text-white/50 text-xs truncate">{purchase.description ?? "Achat"}</p>
		</div>
	</div>
);
