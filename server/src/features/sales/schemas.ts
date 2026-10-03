import { dateString, nonNegativeMoney, optionalText, toCents } from "@common/validation";
import { z } from "zod";

export const PAYMENT_METHODS = ["Bank", "Cash"] as const;

// Older web forms stored the French labels instead of the values.
const LEGACY_PAYMENT_METHODS: Record<string, string> = { Bancaire: "Bank", Espèces: "Cash" };
const paymentMethod = z.preprocess(
	(v) => (typeof v === "string" ? (LEGACY_PAYMENT_METHODS[v] ?? v) : v),
	z.enum(PAYMENT_METHODS),
);

export const saleItemSchema = z.object({
	description: z.string().trim().min(1, "Description obligatoire"),
	unitPrice: nonNegativeMoney,
	quantity: z.number().int().min(1, "Quantité minimale : 1"),
});

export const saleInputSchema = z
	.object({
		clientName: z.string().trim().min(1, "Nom du client obligatoire"),
		deliveryDatetime: dateString,
		deliveryAddress: optionalText,
		description: optionalText,
		amount: nonNegativeMoney,
		deposit: nonNegativeMoney,
		depositPaymentMethod: paymentMethod,
		remaining: nonNegativeMoney,
		remainingPaymentMethod: paymentMethod,
		items: z.array(saleItemSchema).default([]),
	})
	.superRefine((sale, ctx) => {
		if (toCents(sale.deposit) + toCents(sale.remaining) !== toCents(sale.amount)) {
			ctx.addIssue({ code: "custom", path: ["remaining"], message: "Acompte + solde doit égaler le montant total" });
		}
		if (sale.items.length > 0) {
			const total = sale.items.reduce((sum, item) => sum + toCents(item.unitPrice) * item.quantity, 0);
			if (total !== toCents(sale.amount)) {
				ctx.addIssue({ code: "custom", path: ["amount"], message: "Le montant doit égaler le total des articles" });
			}
		}
	});

export type SaleInput = z.output<typeof saleInputSchema>;
