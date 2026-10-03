import Link from "next/link";
import type { ReactNode } from "react";

type EmptyStateProps = {
	emptyIcon: ReactNode;
	emptyLabel: string;
	actionUrl?: string;
	actionLabel?: string;
};

export const EmptyState = ({ emptyIcon, emptyLabel, actionUrl, actionLabel }: EmptyStateProps) => {
	return (
		<div className="flex flex-col items-center justify-center py-16 text-center">
			<div className="size-16 rounded-full bg-primary/10 flex items-center justify-center text-primary mb-4">
				{emptyIcon}
			</div>
			<p className="text-slate-500 dark:text-[#c9929b] text-sm mb-4">{emptyLabel}</p>
			{actionUrl && (
				<Link
					href={actionUrl}
					className="h-12 px-6 rounded-xl bg-primary text-white font-bold text-sm flex items-center justify-center shadow-lg shadow-primary/20"
				>
					{actionLabel}
				</Link>
			)}
		</div>
	);
};
