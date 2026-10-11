import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

/**
 * Receipt scanning: Claude reads a photo of a supplier receipt and proposes the fields of a purchase.
 * Nothing is saved here, the user checks the proposal in the form (web or iOS) before creating the purchase.
 */

export const RECEIPT_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type ReceiptMediaType = (typeof RECEIPT_MEDIA_TYPES)[number];
/** Phones downscale before uploading; this only guards against unexpectedly large payloads. */
export const MAX_RECEIPT_BYTES = 5 * 1024 * 1024;

/** The scan could not be done (service not configured, unreadable image, upstream failure). */
export class ReceiptScanError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "ReceiptScanError";
	}
}

const receiptItemSchema = z.object({
	label: z.string().describe("Libellé de la ligne tel qu'imprimé, sans le prix"),
	quantity: z.number().nullable().describe("Quantité si imprimée"),
	total: z.number().nullable().describe("Prix total TTC de la ligne en euros, négatif pour une remise ou un retour"),
});

const receiptExtractionSchema = z.object({
	isReceipt: z.boolean().describe("false si l'image n'est pas un ticket de caisse, une facture ou un reçu"),
	merchant: z.string().nullable().describe("Enseigne ou fournisseur, nom court (ex. « Metro », « Grand Frais »)"),
	date: z.string().nullable().describe("Date d'achat au format YYYY-MM-DD, null si absente"),
	total: z
		.number()
		.nullable()
		.describe("Montant total TTC réellement payé, en euros. Négatif pour un avoir ou un remboursement"),
	items: z
		.array(receiptItemSchema)
		.describe("Lignes d'articles, dans l'ordre, hors sous-totaux, TVA et moyens de paiement"),
});

export type ReceiptExtraction = z.output<typeof receiptExtractionSchema>;

/** What the forms receive: purchase fields ready to be edited, plus the detail used for the consistency check. */
export type ReceiptScan = {
	date: string | null;
	amount: string | null;
	description: string | null;
	merchant: string | null;
	items: ReceiptExtraction["items"];
	warnings: string[];
};

const SYSTEM_PROMPT = `Tu lis les tickets de caisse et factures fournisseurs d'une traiteuse française (produits alimentaires, emballages, fournitures).
Extrais les informations du document photographié. Si une information n'est pas lisible, laisse-la à null plutôt que de deviner.
La date est celle de l'achat (pas une date d'impression, d'échéance ou de livraison). Le total est le montant TTC payé, après remises.
Un avoir ou un remboursement donne un total négatif.`;

const DESCRIPTION_MAX_ITEMS = 6;
const DESCRIPTION_MAX_LENGTH = 120;

const euros = (n: number) => `${n.toFixed(2).replace(".", ",")} €`;

/** Turns the raw extraction into form fields and warnings. Pure, tested without the API. */
export function toReceiptScan(extraction: ReceiptExtraction, today = new Date()): ReceiptScan {
	const warnings: string[] = [];
	if (!extraction.isReceipt) {
		return {
			date: null,
			amount: null,
			description: null,
			merchant: null,
			items: [],
			warnings: ["L'image ne ressemble pas à un ticket de caisse."],
		};
	}

	let date: string | null = null;
	if (extraction.date && /^\d{4}-\d{2}-\d{2}$/.test(extraction.date) && !Number.isNaN(Date.parse(extraction.date))) {
		date = extraction.date;
		if (Date.parse(date) > today.getTime() + 24 * 60 * 60 * 1000) warnings.push("La date lue est dans le futur.");
	} else {
		warnings.push("Date non lue.");
	}

	let amount: string | null = null;
	if (extraction.total !== null && Number.isFinite(extraction.total)) {
		amount = extraction.total.toFixed(2);
	} else {
		warnings.push("Montant total non lu.");
	}

	const itemTotals = extraction.items.map((i) => i.total).filter((t): t is number => t !== null && Number.isFinite(t));
	if (amount !== null && extraction.items.length > 0 && itemTotals.length === extraction.items.length) {
		const sum = Math.round(itemTotals.reduce((a, b) => a + b, 0) * 100);
		const total = Math.round(Number(amount) * 100);
		if (sum !== total) {
			warnings.push(`Le total des lignes (${euros(sum / 100)}) ne correspond pas au total lu (${euros(total / 100)}).`);
		}
	}

	const merchant = extraction.merchant?.trim() || null;
	const labels = [...new Set(extraction.items.map((i) => i.label.trim()).filter(Boolean))];
	const shown = labels.slice(0, DESCRIPTION_MAX_ITEMS).join(", ") + (labels.length > DESCRIPTION_MAX_ITEMS ? "…" : "");
	let description = merchant && shown ? `${merchant} : ${shown}` : merchant || shown || null;
	if (description && description.length > DESCRIPTION_MAX_LENGTH) {
		description = `${description.slice(0, DESCRIPTION_MAX_LENGTH - 1)}…`;
	}

	return { date, amount, description, merchant, items: extraction.items, warnings };
}

/** Sends the photo to Claude and returns the purchase proposal. */
export async function scanReceipt(image: Buffer, mediaType: ReceiptMediaType): Promise<ReceiptScan> {
	if (!process.env.ANTHROPIC_API_KEY) {
		throw new ReceiptScanError("Le scan de tickets n'est pas configuré sur le serveur.");
	}
	if (image.byteLength === 0) throw new ReceiptScanError("Image vide.");
	if (image.byteLength > MAX_RECEIPT_BYTES) throw new ReceiptScanError("Image trop lourde (5 Mo maximum).");

	const client = new Anthropic();
	const request = {
		model: "claude-opus-5-5",
		max_tokens: 4096,
		system: SYSTEM_PROMPT,
		output_config: { effort: "medium", format: zodOutputFormat(receiptExtractionSchema) },
		messages: [
			{
				role: "user",
				content: [
					{ type: "image", source: { type: "base64", media_type: mediaType, data: image.toString("base64") } },
					{ type: "text", text: "Extrais les informations de ce ticket." },
				],
			},
		],
	} satisfies Parameters<typeof client.messages.parse>[0];

	let extraction: ReceiptExtraction | null;
	let refused: boolean;
	try {
		const response = await client.messages.parse(request);
		extraction = response.parsed_output;
		refused = response.stop_reason === "refusal";
	} catch (e) {
		if (e instanceof Anthropic.APIError) {
			console.error("[receipt] Anthropic API error", e.status, e.message);
			throw new ReceiptScanError("Le service de lecture est indisponible, réessayez plus tard.");
		}
		throw e;
	}

	if (refused || !extraction) throw new ReceiptScanError("Ticket illisible, réessayez avec une photo plus nette.");
	return toReceiptScan(extraction);
}
