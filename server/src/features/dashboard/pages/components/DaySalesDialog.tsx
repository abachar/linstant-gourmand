"use client";

import { amount, datetimeLong } from "@common/format";
import { findDaySalesAction } from "@features/dashboard";
import { useQuery } from "@tanstack/react-query";
import { X } from "lucide-react";
import Link from "next/link";

export const DaySalesDialog = ({ date, onClose }: { date: string; onClose: () => void }) => {
	const { data: sales, isLoading } = useQuery({
		queryKey: ["day-sales", date],
		queryFn: () => findDaySalesAction(date),
	});

	return (
		<div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
			<dialog
				open
				className="m-auto bg-white dark:bg-surface-dark rounded-xl p-0 max-w-[90vw] w-100 border border-slate-200 dark:border-white/10 shadow-2xl"
			>
				<div className="flex justify-between items-center p-4 border-b border-slate-200 dark:border-white/10">
					<h3 className="text-slate-900 dark:text-white font-bold text-lg">Commandes du 12 Janvier 2025</h3>
					<button
						type="button"
						onClick={onClose}
						className="size-8 flex items-center justify-center rounded-full hover:bg-slate-100 dark:hover:bg-white/10 text-slate-500 dark:text-white/60"
					>
						<X />
					</button>
				</div>
				<div className="p-4 max-h-[60vh] overflow-y-auto">
					{isLoading ? (
						<p className="text-slate-400 text-sm text-center py-4">Chargement...</p>
					) : (
						<div className="space-y-3">
							{sales?.map((sale) => (
								<Link
									key={sale.id}
									href={`/sales/${sale.id}`}
									className="block p-3 rounded-lg bg-slate-50 dark:bg-white/5 hover:bg-slate-100 dark:hover:bg-white/10 transition-colors"
								>
									<div className="flex justify-between items-start">
										<div>
											<p className="font-bold text-slate-900 dark:text-white text-sm">{sale.clientName}</p>
											<p className="text-xs text-slate-500 dark:text-[#c9929b] mt-0.5">
												{datetimeLong(sale.deliveryDatetime)}
											</p>
										</div>
										<p className="font-bold text-slate-900 dark:text-white text-sm">{amount(sale.amount)}</p>
									</div>
								</Link>
							))}
						</div>
					)}
				</div>
			</dialog>
		</div>
	);
};
