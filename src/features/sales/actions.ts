"use server";

import { addDays, addYears, endOfDay, endOfMonth, startOfDay, startOfMonth, subDays } from "date-fns";
import {
	createSale,
	deleteSaleById,
	findSaleById,
	findSalesByRange,
	getDistinctClients,
	updateSale,
} from "./api.server";

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

export type FindSaleByIdReturn = Awaited<ReturnType<typeof findSaleByIdAction>>;

export async function createSaleAction(data: {
	clientName: string;
	deliveryDatetime: string;
	deliveryAddress?: string;
	description?: string;
	amount: string;
	deposit: string;
	depositPaymentMethod: string;
	remaining: string;
	remainingPaymentMethod: string;
}) {
	return createSale(data);
}

export async function deleteSaleByIdAction(id: string) {
	return deleteSaleById(id);
}

export async function updateSaleAction(data: {
	id: string;
	clientName: string;
	deliveryDatetime: string;
	deliveryAddress?: string;
	description?: string;
	amount: string;
	deposit: string;
	depositPaymentMethod: string;
	remaining: string;
	remainingPaymentMethod: string;
}) {
	return updateSale(data);
}
