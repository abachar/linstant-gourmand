import { amount as formatAmount } from "@common/format";
import { Text, View } from "@react-pdf/renderer";
import { itemsTotal, type PrintItem } from "../types";

interface PrintItemsTableProps {
	items: PrintItem[];
	/** "Total :" for a single sale, "Sous-total :" inside a grouped invoice. */
	totalLabel: string;
}

export const PrintItemsTable = ({ items, totalLabel }: PrintItemsTableProps) => (
	<>
		<View style={{ marginBottom: 20 }}>
			<View
				style={{
					flexDirection: "row",
					backgroundColor: "#333",
					color: "#fff",
					padding: 8,
					fontWeight: "bold",
					fontSize: 9,
				}}
			>
				<Text style={{ flex: 3 }}>DESCRIPTION</Text>
				<Text style={{ flex: 1, textAlign: "center" }}>PRIX</Text>
				<Text style={{ flex: 1, textAlign: "center" }}>QUANTITÉ</Text>
				<Text style={{ flex: 1, textAlign: "right" }}>TOTAL</Text>
			</View>
			{items.map((item, i) => {
				const lineTotal = Number.parseFloat(item.unitPrice) * item.quantity;
				return (
					<View
						key={item.id}
						wrap={false}
						style={{
							flexDirection: "row",
							borderBottomWidth: 1,
							borderBottomColor: "#eee",
							padding: 8,
							fontSize: 9,
							backgroundColor: i % 2 === 1 ? "#fafafa" : "transparent",
						}}
					>
						<Text style={{ flex: 3 }}>{item.description}</Text>
						<Text style={{ flex: 1, textAlign: "center" }}>{formatAmount(item.unitPrice)}</Text>
						<Text style={{ flex: 1, textAlign: "center" }}>{item.quantity}</Text>
						<Text style={{ flex: 1, textAlign: "right" }}>{formatAmount(lineTotal)}</Text>
					</View>
				);
			})}
		</View>

		<View
			wrap={false}
			style={{ flexDirection: "row", justifyContent: "flex-end", marginTop: 10, marginBottom: 20, paddingRight: 8 }}
		>
			<Text style={{ fontSize: 12, fontWeight: "bold", marginRight: 20 }}>{totalLabel}</Text>
			<Text style={{ fontSize: 12, fontWeight: "bold" }}>{formatAmount(itemsTotal(items))}</Text>
		</View>
	</>
);
