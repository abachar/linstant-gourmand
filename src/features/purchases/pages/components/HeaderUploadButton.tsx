"use client";

import { importPurchasesFromCsvAction } from "@features/purchases";
import { useMutation } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { LoaderCircle, Upload } from "lucide-react";
import { useRef } from "react";

export const HeaderUploadButton = () => {
	const fileInputRef = useRef<HTMLInputElement>(null);
	const router = useRouter();
	const { mutateAsync: importPurchasesFromCsv, isPending } = useMutation({
		mutationFn: (content: string) => importPurchasesFromCsvAction(content),
		onSuccess: () => router.refresh(),
	});

	async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
		const file = e.currentTarget.files?.[0];
		if (!file) return;
		if (fileInputRef.current) fileInputRef.current.value = "";

		await importPurchasesFromCsv(await file.text());
	}

	return (
		<div>
			<button
				type="button"
				onClick={() => fileInputRef.current?.click()}
				className="flex items-center justify-center size-10 text-slate-600 dark:text-white"
			>
				{isPending ? <LoaderCircle className="animate-spin opacity-50" /> : <Upload />}
			</button>
			<input ref={fileInputRef} type="file" accept=".csv" className="hidden" onChange={handleFileChange} />
		</div>
	);
};
