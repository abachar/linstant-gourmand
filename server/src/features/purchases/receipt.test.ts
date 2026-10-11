import { describe, expect, it } from "vitest";
import { type ReceiptExtraction, toReceiptScan } from "./receipt.server";

const today = new Date("2026-10-11T12:00:00Z");

const metro: ReceiptExtraction = {
	isReceipt: true,
	merchant: "Metro",
	date: "2026-10-09",
	total: 35.2,
	items: [
		{ label: "Farine T55 25kg", quantity: 1, total: 18.9 },
		{ label: "Beurre doux", quantity: 2, total: 12.3 },
		{ label: "Crème 35%", quantity: 1, total: 4 },
	],
};

describe("toReceiptScan", () => {
	it("fills the purchase fields from a consistent receipt", () => {
		expect(toReceiptScan(metro, today)).toEqual({
			date: "2026-10-09",
			amount: "35.20",
			description: "Metro : Farine T55 25kg, Beurre doux, Crème 35%",
			merchant: "Metro",
			items: metro.items,
			warnings: [],
		});
	});

	it("warns when the lines do not add up to the total", () => {
		const scan = toReceiptScan({ ...metro, total: 36 }, today);
		expect(scan.amount).toBe("36.00");
		expect(scan.warnings).toEqual(["Le total des lignes (35,20 €) ne correspond pas au total lu (36,00 €)."]);
	});

	it("skips the consistency check when a line has no price", () => {
		const items = [...metro.items, { label: "Sachets", quantity: null, total: null }];
		expect(toReceiptScan({ ...metro, items }, today).warnings).toEqual([]);
	});

	it("keeps a refund negative", () => {
		const scan = toReceiptScan(
			{ ...metro, total: -12.3, items: [{ label: "Retour beurre", quantity: 1, total: -12.3 }] },
			today,
		);
		expect(scan.amount).toBe("-12.30");
		expect(scan.warnings).toEqual([]);
	});

	it("warns about missing or malformed date and total", () => {
		const scan = toReceiptScan({ ...metro, date: "09/10/2026", total: null }, today);
		expect(scan.date).toBeNull();
		expect(scan.amount).toBeNull();
		expect(scan.warnings).toEqual(["Date non lue.", "Montant total non lu."]);
	});

	it("warns about a date in the future", () => {
		expect(toReceiptScan({ ...metro, date: "2026-12-01" }, today).warnings).toEqual(["La date lue est dans le futur."]);
	});

	it("shortens the description to a few lines", () => {
		const items = Array.from({ length: 8 }, (_, i) => ({ label: `Article ${i + 1}`, quantity: 1, total: 4.4 }));
		const scan = toReceiptScan({ ...metro, total: 35.2, items }, today);
		expect(scan.description).toBe("Metro : Article 1, Article 2, Article 3, Article 4, Article 5, Article 6…");
	});

	it("falls back to the merchant or the lines alone", () => {
		expect(toReceiptScan({ ...metro, items: [] }, today).description).toBe("Metro");
		expect(toReceiptScan({ ...metro, merchant: "  " }, today).description).toBe(
			"Farine T55 25kg, Beurre doux, Crème 35%",
		);
		expect(toReceiptScan({ ...metro, merchant: null, items: [] }, today).description).toBeNull();
	});

	it("returns nothing but a warning for a photo that is not a receipt", () => {
		expect(toReceiptScan({ ...metro, isReceipt: false }, today)).toEqual({
			date: null,
			amount: null,
			description: null,
			merchant: null,
			items: [],
			warnings: ["L'image ne ressemble pas à un ticket de caisse."],
		});
	});
});
