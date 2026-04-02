import { DAYS_OF_WEEK } from "@common/format";
import { ChevronLeft, ChevronRight } from "lucide-react";
import type { DashboardData } from "../../../api.server";
import { CalendarDay } from "./CalendarDay";
import { CalendarNavButton } from "./CalendarNavButton";

export const Calendar = (props: DashboardData) => (
	<div className="bg-white/5 dark:bg-white/5 rounded-xl p-4 border border-slate-200 dark:border-white/10">
		<div className="flex items-center justify-between mb-4">
			<h3 className="text-slate-900 dark:text-white font-bold text-lg">Planning des commandes</h3>
			<div className="flex gap-2">
				<CalendarNavButton month={props.prevMonth}>
					<ChevronLeft />
				</CalendarNavButton>
				<CalendarNavButton month={props.nextMonth}>
					<ChevronRight />
				</CalendarNavButton>
			</div>
		</div>
		<div className="mb-4">
			<p className="text-primary text-sm font-semibold">{props.calendarTitle}</p>
		</div>

		<div className="grid grid-cols-7 gap-y-2">
			{DAYS_OF_WEEK.map((d) => (
				<p key={d} className="flex-1 text-slate-400 dark:text-white/40 text-[11px] font-bold text-center">
					{d}
				</p>
			))}

			{props.monthSales.map((entry) => (
				<CalendarDay key={entry.date} {...entry} />
			))}
		</div>
	</div>
);
