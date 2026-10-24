import { amount as formatAmount } from "@common/format";
import { Text, View } from "@react-pdf/renderer";
import { itemsTotal, type PrintSale } from "../types";

/** Total of a grouped invoice, after the sub-total of each event. */
export const PrintGrandTotal = ({ sales }: { sales: PrintSale[] }) => (
	<View
		wrap={false}
		style={{
			flexDirection: "row",
			justifyContent: "flex-end",
			alignItems: "center",
			borderTopWidth: 2,
			borderTopColor: "#333",
			paddingTop: 10,
			paddingRight: 8,
			marginTop: 10,
		}}
	>
		<Text style={{ fontSize: 10, color: "#666", marginRight: 20 }}>{sales.length} événements</Text>
		<Text style={{ fontSize: 14, fontWeight: "bold", marginRight: 20 }}>Total :</Text>
		<Text style={{ fontSize: 14, fontWeight: "bold" }}>
			{formatAmount(sales.reduce((sum, sale) => sum + itemsTotal(sale.items), 0))}
		</Text>
	</View>
);
