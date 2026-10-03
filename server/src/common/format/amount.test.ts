import { describe, expect, it } from "vitest";
import { amount } from "./amount";

describe("amount", () => {
	it("formate zéro", () => {
		expect(amount(0)).toBe("0,00\u00a0€");
	});

	it("formate un entier", () => {
		expect(amount(1000)).toBe("1\u202f000,00\u00a0€");
	});

	it("formate un décimal", () => {
		expect(amount(1234.56)).toBe("1\u202f234,56\u00a0€");
	});

	it("accepte une chaîne numérique", () => {
		expect(amount("99.99")).toBe("99,99\u00a0€");
	});

	it("formate un nombre négatif", () => {
		expect(amount(-50)).toBe("-50,00\u00a0€");
	});

	it("produit le même résultat depuis un nombre ou une chaîne", () => {
		expect(amount(1234.56)).toBe(amount("1234.56"));
	});
});
