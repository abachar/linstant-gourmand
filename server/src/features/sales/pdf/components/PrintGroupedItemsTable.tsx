import { dateCompact } from "@common/format";
import { Text, View } from "@react-pdf/renderer";
import { type PrintSale, printAmount } from "../types";
import { PrintGrandTotal } from "./PrintGrandTotal";

const columns = {
	date: { flex: 1.3 },
	description: { flex: 2.2 },
	price: { flex: 1, textAlign: "center" as const },
	quantity: { flex: 0.8, textAlign: "center" as const },
	total: { flex: 1, textAlign: "right" as const },
};

/** The address most deliveries went to, shown once at the top; the other deliveries name theirs. */
export function mainDeliveryAddress(sales: PrintSale[]): string | null {
	const counts = new Map<string, number>();
	for (const sale of sales) {
		if (sale.deliveryAddress) counts.set(sale.deliveryAddress, (counts.get(sale.deliveryAddress) ?? 0) + 1);
	}
	let best: string | null = null;
	for (const [address, count] of counts) {
		if (best === null || count > (counts.get(best) ?? 0)) best = address;
	}
	return best;
}

/**
 * Grouped invoice: one table for the month, a date column, the lines of a delivery kept together.
 * Compact on purpose: a client with daily deliveries fits on one page.
 */
export const PrintGroupedItemsTable = ({ sales }: { sales: PrintSale[] }) => {
	const mainAddress = mainDeliveryAddress(sales);

	return (
		<>
			{mainAddress && (
				<View
					style={{ backgroundColor: "#f5f5f5", padding: 8, marginBottom: 20, textAlign: "center", fontWeight: "bold" }}
				>
					<Text>Livraison à {mainAddress}</Text>
				</View>
			)}

			<View
				fixed
				style={{
					flexDirection: "row",
					backgroundColor: "#333",
					color: "#fff",
					padding: 8,
					fontWeight: "bold",
					fontSize: 9,
				}}
			>
				<Text style={columns.date}>DATE</Text>
				<Text style={columns.description}>DESCRIPTION</Text>
				<Text style={columns.price}>PRIX</Text>
				<Text style={columns.quantity}>QUANTITÉ</Text>
				<Text style={columns.total}>TOTAL</Text>
			</View>

			{sales.map((sale, i) => {
				const otherAddress = sale.deliveryAddress && sale.deliveryAddress !== mainAddress ? sale.deliveryAddress : null;
				return (
					<View
						key={sale.id}
						wrap={false}
						style={{
							borderBottomWidth: 1,
							borderBottomColor: "#ddd",
							backgroundColor: i % 2 === 1 ? "#fafafa" : "transparent",
						}}
					>
						{sale.items.map((item, j) => {
							const last = j === sale.items.length - 1;
							return (
								<View
									key={item.id}
									style={{
										flexDirection: "row",
										paddingHorizontal: 8,
										paddingTop: 8,
										paddingBottom: last && !otherAddress ? 8 : 4,
										fontSize: 9,
									}}
								>
									<Text style={{ ...columns.date, fontWeight: "bold" }}>
										{j === 0 ? dateCompact(sale.deliveryDatetime) : ""}
									</Text>
									<Text style={columns.description}>{item.description}</Text>
									<Text style={columns.price}>{printAmount(item.unitPrice)}</Text>
									<Text style={columns.quantity}>{item.quantity}</Text>
									<Text style={columns.total}>{printAmount(Number.parseFloat(item.unitPrice) * item.quantity)}</Text>
								</View>
							);
						})}
						{otherAddress && (
							<Text style={{ fontSize: 8, color: "#666", paddingLeft: 8, paddingBottom: 8 }}>
								Livraison à {otherAddress}
							</Text>
						)}
					</View>
				);
			})}

			<PrintGrandTotal sales={sales} />
		</>
	);
};
