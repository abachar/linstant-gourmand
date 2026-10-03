import type { Metadata } from "next";
import { Providers } from "./providers";
import "./globals.css";

export const metadata: Metadata = {
	title: "L'Instant Gourmand by Salma",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
	return (
		<html lang="fr">
			<head>
				<link rel="preconnect" href="https://fonts.googleapis.com" />
				<link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
				<link
					rel="stylesheet"
					href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap"
				/>
			</head>
			<body className="bg-background-light dark:bg-background-dark text-slate-900 dark:text-white min-h-screen">
				<Providers>{children}</Providers>
			</body>
		</html>
	);
}
