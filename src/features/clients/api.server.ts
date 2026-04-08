import { db, sales } from "@common/db";
import { and, asc, eq, isNull, sql } from "drizzle-orm";

export async function listClients() {
	const rows = await db
		.select({
			clientName: sales.clientName,
			deliveryAddress: sales.deliveryAddress,
			orderCount: sql<number>`count(*)::int`,
			totalAmount: sql<string>`coalesce(sum(${sales.amount}), 0)::text`,
		})
		.from(sales)
		.groupBy(sales.clientName, sales.deliveryAddress)
		.orderBy(asc(sales.clientName), asc(sales.deliveryAddress));

	return rows;
}

export async function updateClient(data: {
	oldClientName: string;
	oldDeliveryAddress: string | null;
	newClientName: string;
	newDeliveryAddress: string | null;
}) {
	const addressCondition =
		data.oldDeliveryAddress === null
			? isNull(sales.deliveryAddress)
			: eq(sales.deliveryAddress, data.oldDeliveryAddress);

	await db
		.update(sales)
		.set({
			clientName: data.newClientName,
			deliveryAddress: data.newDeliveryAddress,
		})
		.where(and(eq(sales.clientName, data.oldClientName), addressCondition));
}
