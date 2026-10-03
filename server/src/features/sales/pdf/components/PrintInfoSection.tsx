import { dateShort } from "@common/format";
import { Text, View } from "@react-pdf/renderer";

interface PrintInfoSectionProps {
	clientName: string;
	isInvoice: boolean;
}

export const PrintInfoSection = ({ clientName, isInvoice }: PrintInfoSectionProps) => (
	<>
		<View style={{ marginBottom: 4 }}>
			<Text style={{ fontSize: 10, marginBottom: 4 }}>
				{isInvoice ? "Date de la facture" : "Date du devis"} : {dateShort(new Date())}
			</Text>
			{!isInvoice && <Text style={{ fontSize: 10, marginBottom: 4 }}>Validité du devis : 72h</Text>}
		</View>

		<View style={{ flexDirection: "row", justifyContent: "space-between", marginBottom: 20 }}>
			<View style={{ maxWidth: "48%" }}>
				<Text style={{ fontWeight: "bold", marginBottom: 4 }}>L'INSTANT GOURMAND BY SALMA</Text>
				<Text style={{ fontSize: 10, marginBottom: 4 }}>N° Siret : 828 544 759 00024</Text>
				<Text style={{ fontSize: 10, marginBottom: 4 }}>Tél : 06 95 82 69 80</Text>
			</View>
			<View style={{ maxWidth: "48%" }}>
				<Text style={{ fontWeight: "bold", textAlign: "right" }}>À L'ATTENTION DE {clientName.toUpperCase()}</Text>
			</View>
		</View>
	</>
);
