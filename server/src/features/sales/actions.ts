"use server";

import { randomUUID } from "node:crypto";
import { runAction } from "@common/errors";
import { addDays, addYears, endOfDay, endOfMonth, startOfDay, startOfMonth, subDays } from "date-fns";
import { deleteSale, findSaleById, findSalesByRange, getDistinctClients, saveSale } from "./api.server";
import { saleInputSchema } from "./schemas";

function validFilter(filter: string) {
	return ["upcoming", "month", "past", "all"].includes(filter) ? filter : "upcoming";
}

function getSaleInterval(filter: string): [Date, Date] {
	const now = new Date();
	const minDate = new Date("2020-01-01T00:00:00");
	const maxDate = endOfDay(addYears(now, 2));

	switch (filter) {
		case "upcoming":
			return [startOfDay(addDays(now, 1)), maxDate];
		case "month":
			return [startOfMonth(now), endOfMonth(now)];
		case "past":
			return [minDate, endOfDay(subDays(now, 1))];
	}

	// all
	return [minDate, maxDate];
}

export async function getDistinctClientsAction() {
	return getDistinctClients();
}

export type GetDistinctClientsReturn = Awaited<ReturnType<typeof getDistinctClientsAction>>;

export async function findSalesByRangeAction(filter: string) {
	const selectedFilter = validFilter(filter);
	const [from, to] = getSaleInterval(selectedFilter);
	return {
		selectedFilter,
		sales: await findSalesByRange(from, to),
	};
}

export type FindSalesByRangeReturn = Awaited<ReturnType<typeof findSalesByRangeAction>>;

export async function findSaleByIdAction(id: string) {
	return findSaleById(id);
}

export type FindSaleByIdReturn = NonNullable<Awaited<ReturnType<typeof findSaleByIdAction>>>;

type SaleFormData = {
	clientName: string;
	deliveryDatetime: string;
	deliveryAddress?: string;
	description?: string;
	amount: string;
	deposit: string;
	depositPaymentMethod: string;
	remaining: string;
	remainingPaymentMethod: string;
	items?: { description: string; unitPrice: string; quantity: number }[];
};

export async function createSaleAction(data: SaleFormData) {
	return runAction(async () => {
		const sale = await saveSale(randomUUID(), null, saleInputSchema.parse(data));
		return { id: sale.id };
	});
}

export async function updateSaleAction(data: SaleFormData & { id: string; version: number }) {
	return runAction(async () => {
		await saveSale(data.id, data.version, saleInputSchema.parse(data));
	});
}

export async function deleteSaleByIdAction(id: string, version: number) {
	return runAction(async () => {
		await deleteSale(id, version);
	});
}
