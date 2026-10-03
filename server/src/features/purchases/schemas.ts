import { dateString, money, optionalText } from "@common/validation";
import { z } from "zod";

export const purchaseInputSchema = z.object({
	date: dateString,
	// Negative for a refund
	amount: money,
	description: optionalText,
});

export type PurchaseInput = z.output<typeof purchaseInputSchema>;
