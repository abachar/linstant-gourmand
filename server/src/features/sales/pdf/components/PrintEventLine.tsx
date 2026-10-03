import { dateLong } from "@common/format";
import { Text, View } from "@react-pdf/renderer";

interface PrintEventLineProps {
	datetime: Date;
	address: string | null;
}

export const PrintEventLine = ({ datetime, address }: PrintEventLineProps) => (
	<View
		style={{
			backgroundColor: "#f5f5f5",
			padding: 8,
			marginBottom: 20,
			textAlign: "center",
			fontSize: 10,
			fontWeight: "bold",
		}}
	>
		<Text>
			Événement privé - {dateLong(datetime)} {address ? ` - Livraison à ${address}` : null}
		</Text>
	</View>
);
