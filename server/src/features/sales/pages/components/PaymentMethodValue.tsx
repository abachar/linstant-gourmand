export const PaymentMethodValue = ({ value }: { value: string }) => {
	if (value === "Bank") return "Bancaire";
	if (value === "Cash") return "Espèces";
	return value;
};
