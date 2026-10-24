import { describe, expect, it } from "vitest";
import { printAmount } from "./types";

describe("printAmount", () => {
	it("remplace les espaces insécables par des espaces que la police du PDF sait rendre", () => {
		expect(printAmount("1042.00")).toBe("1 042,00 €");
		expect(printAmount(1234567.5)).toBe("1 234 567,50 €");
	});
});
