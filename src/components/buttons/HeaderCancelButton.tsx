"use client";

import { useRouter } from "next/navigation";

export const HeaderCancelButton = () => {
	const router = useRouter();

	return (
		<button
			type="button"
			onClick={() => router.back()}
			className="text-slate-500 dark:text-[#c9929b] text-sm font-medium hover:opacity-80 transition-opacity"
		>
			Annuler
		</button>
	);
};
