import { Text, View } from "@react-pdf/renderer";
import { PrintLogo } from "./PrintLogo";

export const PrintHeader = ({ isInvoice }: { isInvoice: boolean }) => (
	<View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 30 }}>
		<View>
			<Text
				style={{
					fontSize: 16,
					fontWeight: "bold",
					borderBottomWidth: 1,
					borderBottomColor: "#ccc",
					paddingBottom: 4,
					marginBottom: 20,
				}}
			>
				{isInvoice ? "Facture" : "Devis"}
			</Text>
		</View>
		<PrintLogo />
	</View>
);
