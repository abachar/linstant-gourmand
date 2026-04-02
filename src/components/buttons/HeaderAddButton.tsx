import Link from "next/link";
import { Plus } from "lucide-react";

export const HeaderAddButton = ({ href }: { href: string }) => (
	<Link
		href={href}
		className="flex items-center justify-center rounded-full size-10 bg-primary text-white shadow-lg shadow-primary/20"
	>
		<Plus />
	</Link>
);
