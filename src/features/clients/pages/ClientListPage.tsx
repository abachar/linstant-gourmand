"use client";

import { amount as formatAmount } from "@common/format/amount";
import { Check, Users } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import type { ListClientsReturn } from "../actions";
import { updateClientAction } from "../actions";

type Client = ListClientsReturn[number];

const rowKey = (c: Pick<Client, "clientName" | "deliveryAddress">) =>
	`${c.clientName}::${c.deliveryAddress ?? ""}`;

export const ClientListPage = ({ clients }: { clients: ListClientsReturn }) => {
	const router = useRouter();
	const [drafts, setDrafts] = useState<Record<string, { clientName: string; deliveryAddress: string }>>({});
	const [pendingKey, setPendingKey] = useState<string | null>(null);
	const [isPending, startTransition] = useTransition();

	function getDraft(client: Client) {
		return (
			drafts[rowKey(client)] ?? {
				clientName: client.clientName,
				deliveryAddress: client.deliveryAddress ?? "",
			}
		);
	}

	function setDraft(client: Client, patch: Partial<{ clientName: string; deliveryAddress: string }>) {
		const key = rowKey(client);
		const current = getDraft(client);
		setDrafts((prev) => ({ ...prev, [key]: { ...current, ...patch } }));
	}

	function isDirty(client: Client) {
		const d = drafts[rowKey(client)];
		if (!d) return false;
		return d.clientName !== client.clientName || d.deliveryAddress !== (client.deliveryAddress ?? "");
	}

	function onSave(client: Client) {
		const draft = getDraft(client);
		if (!draft.clientName.trim()) return;
		const key = rowKey(client);
		setPendingKey(key);
		startTransition(async () => {
			await updateClientAction({
				oldClientName: client.clientName,
				oldDeliveryAddress: client.deliveryAddress,
				newClientName: draft.clientName.trim(),
				newDeliveryAddress: draft.deliveryAddress.trim() || null,
			});
			setDrafts({});
			setPendingKey(null);
			router.refresh();
		});
	}

	return (
		<div className="min-h-screen bg-slate-50 dark:bg-background-dark">
			<header className="border-b border-slate-200 dark:border-border-dark bg-white dark:bg-surface-dark">
				<div className="max-w-6xl mx-auto px-8 py-6 flex items-center justify-between">
					<div>
						<h1 className="text-2xl font-bold text-slate-900 dark:text-white">Administration — Clients</h1>
						<p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
							{clients.length} client{clients.length > 1 ? "s" : ""} au total
						</p>
					</div>
				</div>
			</header>

			<main className="max-w-6xl mx-auto px-8 py-8">
				{clients.length === 0 ? (
					<div className="flex flex-col items-center justify-center py-24 text-slate-400">
						<Users size={48} />
						<p className="mt-4">Aucun client trouvé.</p>
					</div>
				) : (
					<div className="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-border-dark overflow-hidden shadow-sm">
						<table className="w-full">
							<thead className="bg-slate-50 dark:bg-background-dark border-b border-slate-200 dark:border-border-dark">
								<tr className="text-left text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
									<th className="px-6 py-4">Nom du client</th>
									<th className="px-6 py-4">Adresse de livraison</th>
									<th className="px-6 py-4 text-right">Commandes</th>
									<th className="px-6 py-4 text-right">Total</th>
									<th className="px-6 py-4 w-20" />
								</tr>
							</thead>
							<tbody className="divide-y divide-slate-100 dark:divide-white/5">
								{clients.map((client) => {
									const key = rowKey(client);
									const draft = getDraft(client);
									const dirty = isDirty(client);
									const rowPending = isPending && pendingKey === key;
									return (
										<tr key={key} className="hover:bg-slate-50 dark:hover:bg-white/5 transition-colors">
											<td className="px-3 py-2">
												<input
													type="text"
													value={draft.clientName}
													onChange={(e) => setDraft(client, { clientName: e.currentTarget.value })}
													disabled={rowPending}
													className="form-input w-full rounded-md border border-transparent hover:border-slate-200 focus:border-primary focus:ring-2 focus:ring-primary/30 bg-transparent text-sm font-semibold text-slate-900 dark:text-white px-3 py-2"
												/>
											</td>
											<td className="px-3 py-2">
												<input
													type="text"
													value={draft.deliveryAddress}
													onChange={(e) => setDraft(client, { deliveryAddress: e.currentTarget.value })}
													disabled={rowPending}
													placeholder="—"
													className="form-input w-full rounded-md border border-transparent hover:border-slate-200 focus:border-primary focus:ring-2 focus:ring-primary/30 bg-transparent text-sm text-slate-600 dark:text-slate-300 px-3 py-2"
												/>
											</td>
											<td className="px-6 py-4 text-sm text-right text-slate-700 dark:text-slate-200 tabular-nums">
												{client.orderCount}
											</td>
											<td className="px-6 py-4 text-sm text-right font-bold text-primary tabular-nums">
												{formatAmount(client.totalAmount)}
											</td>
											<td className="px-6 py-4 text-right">
												{dirty && (
													<button
														type="button"
														onClick={() => onSave(client)}
														disabled={rowPending}
														className="inline-flex items-center gap-1 h-8 px-3 rounded-lg bg-primary text-white text-xs font-bold shadow-sm hover:opacity-90 disabled:opacity-50"
													>
														<Check size={14} />
														{rowPending ? "..." : "Enregistrer"}
													</button>
												)}
											</td>
										</tr>
									);
								})}
							</tbody>
						</table>
					</div>
				)}
			</main>

		</div>
	);
};
