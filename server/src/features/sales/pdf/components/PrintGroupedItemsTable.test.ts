import { describe, expect, it } from "vitest";
import { mainDeliveryAddress } from "./PrintGroupedItemsTable";

const sale = (deliveryAddress: string | null) => ({
	id: deliveryAddress ?? "none",
	clientName: "PLN Studio",
	deliveryDatetime: new Date(),
	deliveryAddress,
	items: [],
});

describe("mainDeliveryAddress", () => {
	it("retient l'adresse la plus fréquente, la première en cas d'égalité", () => {
		expect(mainDeliveryAddress([sale("A"), sale("B"), sale("B"), sale(null)])).toBe("B");
		expect(mainDeliveryAddress([sale("A"), sale("B")])).toBe("A");
	});

	it("vaut null sans aucune adresse", () => {
		expect(mainDeliveryAddress([sale(null), sale(null)])).toBeNull();
	});
});
