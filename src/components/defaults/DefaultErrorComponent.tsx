"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

export function DefaultErrorComponent({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
	const router = useRouter();

	useEffect(() => {
		console.error("Route Error:", error);
	}, [error]);

	return (
		<div className="p-6 flex flex-col items-center justify-center min-h-100 bg-red-50 text-red-900 rounded-lg border border-red-200">
			<h2 className="text-2xl font-bold mb-2">Oups ! Quelque chose a cassé.</h2>

			<p className="mb-4 font-mono text-sm bg-white p-3 rounded border">
				{error.message || "Erreur inconnue"}
			</p>

			<div className="flex gap-4">
				<button
					type="button"
					onClick={() => reset()}
					className="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition"
				>
					Réessayer
				</button>
				<button
					type="button"
					onClick={() => router.push("/")}
					className="px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300 transition"
				>
					Retour à l'accueil
				</button>
			</div>
		</div>
	);
}
