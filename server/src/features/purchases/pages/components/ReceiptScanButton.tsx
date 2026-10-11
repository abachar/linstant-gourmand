"use client";

import { useMutation } from "@tanstack/react-query";
import { LoaderCircle, ScanLine } from "lucide-react";
import { useRef } from "react";
import { scanReceiptAction } from "../../actions";
import type { ReceiptScan } from "../../receipt.server";

/** Longest side of the photo sent to the server: enough to read a receipt, small enough for the 2 MB action limit. */
const MAX_SIDE = 1600;
const JPEG_QUALITY = 0.8;

/** Downscales the photo in the browser and returns it as base64 JPEG. */
async function toJpegBase64(file: File): Promise<string> {
	const bitmap = await createImageBitmap(file);
	const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height));
	const canvas = document.createElement("canvas");
	canvas.width = Math.round(bitmap.width * scale);
	canvas.height = Math.round(bitmap.height * scale);
	canvas.getContext("2d")?.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
	bitmap.close();
	const dataUrl = canvas.toDataURL("image/jpeg", JPEG_QUALITY);
	return dataUrl.slice(dataUrl.indexOf(",") + 1);
}

export const ReceiptScanButton = ({ onScan }: { onScan: (scan: ReceiptScan) => void }) => {
	const fileInputRef = useRef<HTMLInputElement>(null);
	const { mutate: scan, isPending } = useMutation({
		mutationFn: async (file: File) => scanReceiptAction({ data: await toJpegBase64(file), mediaType: "image/jpeg" }),
		onSuccess: (result) => (result.ok ? onScan(result.data) : alert(result.message)),
		onError: () => alert("Lecture du ticket impossible, réessayez."),
	});

	function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
		const file = e.currentTarget.files?.[0];
		if (fileInputRef.current) fileInputRef.current.value = "";
		if (file) scan(file);
	}

	return (
		<>
			<button
				type="button"
				disabled={isPending}
				onClick={() => fileInputRef.current?.click()}
				className="flex w-full h-14 items-center justify-center gap-2 rounded-xl border-2 border-dashed border-primary/50 text-primary font-bold text-base hover:bg-primary/5 transition-colors disabled:opacity-50"
			>
				{isPending ? <LoaderCircle className="animate-spin" /> : <ScanLine />}
				{isPending ? "Lecture du ticket…" : "Scanner un ticket"}
			</button>
			<input
				ref={fileInputRef}
				type="file"
				accept="image/*"
				capture="environment"
				className="hidden"
				onChange={handleFileChange}
			/>
		</>
	);
};
