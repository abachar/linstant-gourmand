"use client";

import { getDistinctClientsAction } from "@features/sales/actions";
import { Combobox, ComboboxInput, ComboboxOption, ComboboxOptions } from "@headlessui/react";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";

interface ClientAutocompleteProps {
	value: string;
	onChange: (clientName: string, deliveryAddress?: string) => void;
}

export const ClientAutocomplete = ({ value, onChange }: ClientAutocompleteProps) => {
	const [query, setQuery] = useState("");

	const { data: knownClients = [] } = useQuery({
		queryKey: ["clients"],
		queryFn: () => getDistinctClientsAction(),
		staleTime: 5 * 60 * 1000,
	});

	const suggestions =
		query.trim().length === 0
			? []
			: knownClients.filter((c) => c.clientName.toLowerCase().includes(query.toLowerCase()));

	function handleSelect(entry: (typeof knownClients)[number] | null) {
		if (!entry) return;
		onChange(entry.clientName, entry.deliveryAddress ?? undefined);
		setQuery("");
	}

	return (
		<Combobox immediate onChange={handleSelect}>
			<ComboboxInput
				required
				value={value}
				onChange={(e) => {
					onChange(e.currentTarget.value);
					setQuery(e.currentTarget.value);
				}}
				placeholder="Ex: Marie Lefebvre"
				autoComplete="off"
				displayValue={() => value}
				className="form-input w-full rounded-lg text-slate-900 dark:text-white focus:outline-0 focus:ring-2 focus:ring-primary/50 border border-slate-200 dark:border-[#67323b] bg-white dark:bg-surface-dark h-14 placeholder:text-slate-400 dark:placeholder:text-[#c9929b] px-4 text-base font-normal"
			/>
			{suggestions.length > 0 && (
				<ComboboxOptions
					anchor="bottom start"
					className="w-[var(--input-width)] z-50 mt-1 bg-white dark:bg-surface-dark border border-slate-200 dark:border-[#67323b] rounded-lg shadow-lg overflow-hidden empty:hidden"
				>
					{suggestions.map((entry) => (
						<ComboboxOption
							key={`${entry.clientName}|${entry.deliveryAddress ?? ""}`}
							value={entry}
							className="px-4 py-3 cursor-pointer data-[focus]:bg-primary/5 dark:data-[focus]:bg-primary/10 transition-colors"
						>
							<span className="text-slate-900 dark:text-white font-medium text-sm block">{entry.clientName}</span>
							{entry.deliveryAddress && (
								<span className="text-slate-400 dark:text-slate-500 text-xs truncate block mt-0.5">
									{entry.deliveryAddress}
								</span>
							)}
						</ComboboxOption>
					))}
				</ComboboxOptions>
			)}
		</Combobox>
	);
};
