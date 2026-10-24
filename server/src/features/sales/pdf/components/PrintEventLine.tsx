import { dateLong } from "@common/format";
import { Text, View } from "@react-pdf/renderer";
import type { PropsWithChildren } from "react";

interface PrintEventLineProps {
	datetime: Date;
	address: string | null;
}

/** One event: its banner and, below, its items. Stays with at least the start of its table on a page break. */
export const PrintEventLine = ({ datetime, address, children }: PropsWithChildren<PrintEventLineProps>) => (
	<View>
		<View
			minPresenceAhead={80}
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
		{children}
	</View>
);
