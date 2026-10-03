import { z } from "zod";

export const productInputSchema = z.object({
	productName: z.string().trim().min(1, "Nom du produit obligatoire"),
	quantity: z.number().int("Quantité entière").min(0, "La quantité doit être positive"),
	expirationDate: z
		.string()
		.trim()
		.nullish()
		.refine((v) => !v || !Number.isNaN(Date.parse(v)), "Date invalide")
		.transform((v) => (v ? new Date(v) : null)),
});

export type ProductInput = z.output<typeof productInputSchema>;
