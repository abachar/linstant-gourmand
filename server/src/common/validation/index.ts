import { z } from "zod";

/** Money as a 2-decimal string ("12.50"); numbers are accepted and normalized. */
export const money = z
	.union([z.string().trim(), z.number()])
	.transform((v) => (typeof v === "number" ? v.toFixed(2) : v))
	.refine((v) => /^-?\d{1,8}(\.\d{1,2})?$/.test(v), "Montant invalide")
	.transform((v) => Number(v).toFixed(2));

export const nonNegativeMoney = money.refine((v) => Number(v) >= 0, "Le montant doit être positif");

/** Any date string `new Date()` understands (ISO 8601 from the API, datetime-local from the web). */
export const dateString = z
	.string()
	.trim()
	.refine((v) => !Number.isNaN(Date.parse(v)), "Date invalide")
	.transform((v) => new Date(v));

export const optionalText = z
	.string()
	.trim()
	.nullish()
	.transform((v) => (v ? v : null));

export const baseVersionSchema = z.number().int().positive().nullable();

/** Amounts compared in cents to avoid floating point noise. */
export const toCents = (v: string) => Math.round(Number(v) * 100);

/** Flattens a ZodError into { "items.0.quantity": "message" }. */
export function zodFields(error: z.ZodError): Record<string, string> {
	const fields: Record<string, string> = {};
	for (const issue of error.issues) {
		const key = issue.path.join(".") || "_";
		fields[key] ??= issue.message;
	}
	return fields;
}
