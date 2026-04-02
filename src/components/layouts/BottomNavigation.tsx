"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import clsx from "clsx";
import { ChartPie, LayoutDashboard, Refrigerator, ShoppingBag, ShoppingBasket } from "lucide-react";
import type { ReactNode } from "react";

const NavigationLink = ({ href, label, icon }: { href: string; label: string; icon: ReactNode }) => {
	const pathname = usePathname();
	const isActive = href === "/" ? pathname === "/" : pathname.startsWith(href);

	return (
		<Link
			href={href}
			className={clsx("flex flex-col items-center gap-1", {
				"text-primary": isActive,
				"text-slate-400 dark:text-[#c9929b]": !isActive,
			})}
		>
			{icon}
			<span className="text-[10px] font-bold">{label}</span>
		</Link>
	);
};

export const BottomNavigation = () => (
	<nav className="fixed bottom-0 left-0 right-0 ios-tab-bar bg-white/90 dark:bg-background-dark/90 border-t border-slate-200 dark:border-white/5 py-4 z-50">
		<div className="grid grid-cols-5 px-2">
			<NavigationLink href="/" label="Dashboard" icon={<LayoutDashboard />} />
			<NavigationLink href="/sales" label="Ventes" icon={<ShoppingBag />} />
			<NavigationLink href="/purchases" label="Achats" icon={<ShoppingBasket />} />
			<NavigationLink href="/products" label="Stock" icon={<Refrigerator />} />
			<NavigationLink href="/taxes" label="Taxes" icon={<ChartPie />} />
		</div>
	</nav>
);
