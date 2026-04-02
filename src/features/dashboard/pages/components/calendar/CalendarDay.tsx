"use client";

import clsx from "clsx";
import { useState } from "react";
import type { DashboardData } from "../../../api.server";
import { DaySalesDialog } from "../DaySalesDialog";

export const CalendarDay = (props: DashboardData["monthSales"][0]) => {
	const [openDetails, setOpenDetails] = useState<boolean>(false);
	const hasSales = props.saleIds.length > 0;

	return (
		<>
			<button
				type="button"
				onClick={() => setOpenDetails(hasSales)}
				className={clsx("h-10 w-full text-sm flex flex-col items-center justify-center relative rounded-lg", {
					"bg-primary/80 text-white shadow-md": props.isToday,
					"font-medium": hasSales,
					"opacity-15": !props.inSelectedMonth,
					"text-slate-900 dark:text-white": props.inSelectedMonth && !props.isToday && hasSales,
					"text-slate-500 dark:text-white/60": props.inSelectedMonth && !props.isToday && !hasSales,
				})}
			>
				<span>{props.day}</span>
				<div className="flex gap-0.5 absolute bottom-1">
					{props.saleIds.map((saleId) => (
						<span key={saleId} className={clsx("size-1 rounded-full", props.isToday ? "bg-white/80" : "bg-primary")} />
					))}
				</div>
			</button>
			{openDetails && <DaySalesDialog date={props.date} onClose={() => setOpenDetails(false)} />}
		</>
	);
};
