import { describe, expect, it } from "vitest";
import { dateLong, dateShort, datetimeLong, formatDateInput, formatDatetimeLocal } from "./date";

// Tests with UTC noon to avoid timezone-dependent day shifts (TZ=UTC configured in vitest.config.ts)
const JAN_25_2025 = "2025-01-25T12:00:00Z"; // samedi
const JAN_25_2025_14H30 = "2025-01-25T14:30:00Z";

describe("dateShort", () => {
	it("formate en JJ/MM/AAAA", () => {
		expect(dateShort(JAN_25_2025)).toBe("25/01/2025");
	});

	it("accepte un objet Date", () => {
		expect(dateShort(new Date(JAN_25_2025))).toBe("25/01/2025");
	});
});

describe("dateLong", () => {
	it("contient le jour de la semaine, le mois et l'année en français", () => {
		expect(dateLong(JAN_25_2025)).toBe("samedi 25 janvier 2025");
	});

	it("accepte un objet Date", () => {
		expect(dateLong(new Date(JAN_25_2025))).toBe("samedi 25 janvier 2025");
	});
});

describe("datetimeLong", () => {
	it("contient la date complète en français", () => {
		expect(datetimeLong(JAN_25_2025_14H30)).toBe("samedi 25 janvier 2025 à 14h30");
	});

	it("accepte un objet Date", () => {
		expect(datetimeLong(new Date(JAN_25_2025_14H30))).toBe("samedi 25 janvier 2025 à 14h30");
	});
});

describe("formatDatetimeLocal", () => {
	it("formate en AAAA-MM-JJTHH:MM", () => {
		expect(formatDatetimeLocal(new Date("2025-01-25T14:30:00Z"))).toBe("2025-01-25T14:30");
	});

	it("pads les chiffres avec des zéros", () => {
		expect(formatDatetimeLocal(new Date("2025-03-05T09:05:00Z"))).toBe("2025-03-05T09:05");
	});
});

describe("formatDateInput", () => {
	it("formate en AAAA-MM-JJ", () => {
		expect(formatDateInput(new Date("2025-01-25T12:00:00Z"))).toBe("2025-01-25");
	});

	it("accepte une chaîne ISO", () => {
		expect(formatDateInput("2025-06-15T12:00:00Z")).toBe("2025-06-15");
	});
});
