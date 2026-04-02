import Link from "next/link";
import type { PropsWithChildren } from "react";

export const CalendarNavButton = ({ month, children }: PropsWithChildren<{ month: string }>) => (
	<Link
		href={`/?month=${month}`}
		className="size-8 flex items-center justify-center rounded-lg bg-slate-100 dark:bg-white/5 text-slate-600 dark:text-white"
	>
		{children}
	</Link>
);
