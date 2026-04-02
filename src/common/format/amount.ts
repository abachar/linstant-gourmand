const amountFormatter = new Intl.NumberFormat("fr-FR", {
	style: "currency",
	currency: "EUR",
});

/** 1 234,56 € */
export function amount(value: number | string): string {
	return amountFormatter.format(Number(value));
}
