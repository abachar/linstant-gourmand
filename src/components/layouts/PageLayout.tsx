import type { PropsWithChildren } from "react";
import { BottomNavigation } from "./BottomNavigation";
import { TopHeader, type TopHeaderProps } from "./TopHeader";

export const PageLayout = ({ children, ...props }: PropsWithChildren<TopHeaderProps>) => (
	<>
		<TopHeader {...props} />

		<main className="px-4 py-4 pb-24">{children}</main>

		<BottomNavigation />
	</>
);
