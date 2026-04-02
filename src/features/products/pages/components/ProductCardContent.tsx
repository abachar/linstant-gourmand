import { dateShort } from "@common/format";
import clsx from "clsx";
import { addMonths, isBefore, isPast } from "date-fns";
import type { FindAllProductsReturn } from "../../actions";

export const ProductCardContent = ({ product }: { product: FindAllProductsReturn[number] }) => {
	const expirationStatus = product.expirationDate
		? isPast(product.expirationDate)
			? "expired"
			: isBefore(product.expirationDate, addMonths(new Date(), 1))
				? "soon"
				: "ok"
		: null;

	return (
		<div className="flex flex-col flex-1 min-w-0">
			<div className="flex justify-between items-start">
				<p className="text-slate-900 dark:text-white text-base font-bold leading-tight line-clamp-1">
					{product.productName}
				</p>
				{product.quantity === 0 ? (
					<span className="text-primary font-bold text-sm">0 unité</span>
				) : product.quantity < 10 ? (
					<span className="text-warning font-bold text-sm">{product.quantity} unités</span>
				) : (
					<span className="text-success font-bold text-sm">{product.quantity} unités</span>
				)}
			</div>
			<div className="mt-1 flex items-center gap-6 text-xs text-slate-400 dark:text-slate-500">
				<div className="flex flex-col pt-4 items-start">
					<span className="text-[10px] uppercase">Modifié le</span>
					<span>{dateShort(product.updatedAt)}</span>
				</div>
				<div
					className={clsx("flex flex-col pt-4 items-start", {
						"text-primary font-semibold": expirationStatus === "expired",
						"text-warning font-semibold": expirationStatus === "soon",
					})}
				>
					<span className="text-[10px] uppercase">Date limite</span>
					{product.expirationDate ? <span>{dateShort(product.expirationDate)}</span> : <span>Aucune</span>}
				</div>
				<div className="flex-1 flex justify-end self-start items-center gap-1.5">
					{product.quantity === 0 ? (
						<>
							<div className="size-2 rounded-full bg-primary" />
							<span className="text-[10px] font-bold uppercase tracking-wide text-primary">Rupture</span>
						</>
					) : product.quantity < 10 ? (
						<>
							<div className="size-2 rounded-full bg-warning" />
							<span className="text-[10px] font-bold uppercase tracking-wide text-warning">Stock faible</span>
						</>
					) : (
						<>
							<div className="size-2 rounded-full bg-success" />
							<span className="text-[10px] font-bold uppercase tracking-wide text-success">En stock</span>
						</>
					)}
				</div>
			</div>
		</div>
	);
};
