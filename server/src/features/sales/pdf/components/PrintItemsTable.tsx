import { Text, View } from "@react-pdf/renderer";
import { itemsTotal, type PrintItem, printAmount } from "../types";

interface PrintItemsTableProps {
	items: PrintItem[];
}

export const PrintItemsTable = ({ items }: PrintItemsTableProps) => (
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
						<Text style={{ flex: 1, textAlign: "center" }}>{printAmount(item.unitPrice)}</Text>
						<Text style={{ flex: 1, textAlign: "center" }}>{item.quantity}</Text>
						<Text style={{ flex: 1, textAlign: "right" }}>{printAmount(lineTotal)}</Text>
					</View>
				);
			})}
		</View>

		<View wrap={false} style={{ flexDirection: "row", justifyContent: "flex-end", marginTop: 10, paddingRight: 8 }}>
			<Text style={{ fontSize: 12, fontWeight: "bold", marginRight: 20 }}>Total :</Text>
			<Text style={{ fontSize: 12, fontWeight: "bold" }}>{printAmount(itemsTotal(items))}</Text>
		</View>
	</>
);
