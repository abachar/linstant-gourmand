import Link from "next/link";
import clsx from "clsx";
import type { FindAllPurchasesReturn } from "../../actions";

const FilterLink = ({ year, active }: { year: number; active: boolean }) => (
	<Link
		href={`/purchases?year=${year}`}
		className={clsx("flex h-9 shrink-0 items-center justify-center gap-x-2 rounded-xl px-4", {
			"bg-primary shadow-l shadow-primary/20": active,
			"bg-slate-200 dark:bg-surface-dark": !active,
		})}
	>
		<p
			className={clsx("text-sm font-medium whitespace-nowrap", {
				"text-white": active,
				"text-slate-700 dark:text-white": !active,
			})}
		>
			{year}
		</p>
	</Link>
);

export const PurchaseListFilter = ({
	availableYears,
	selectedYear,
}: Pick<FindAllPurchasesReturn, "availableYears" | "selectedYear">) => (
	<div className="flex gap-2 py-3 overflow-x-auto hide-scrollbar">
		{availableYears.map((year) => (
			<FilterLink key={year} year={year} active={selectedYear === year} />
		))}
	</div>
);
