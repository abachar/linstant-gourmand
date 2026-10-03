import { Text, View } from "@react-pdf/renderer";

export const PrintFooter = () => (
	<View style={{ position: "absolute", bottom: 40, left: 40, right: 40, textAlign: "center" }}>
		<Text style={{ fontSize: 8, color: "#666", marginBottom: 8 }}>
			TVA non applicable selon l'article 293 B du code général des impôts
		</Text>
		<Text style={{ fontSize: 10, fontWeight: "bold", letterSpacing: 2 }}>MERCI DE VOTRE CONFIANCE</Text>
	</View>
);
