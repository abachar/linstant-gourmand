import type { ReactNode } from "react";
import { CardRow } from "./CardRow";

type CardListProps<T> = {
	rows: T[];
	onCardClick?: (row: T) => void;
	onEditClick?: (row: T) => void;
	onDeleteClick?: (row: T) => void;
	canEdit?: (row: T) => boolean;
	canDelete?: (row: T) => boolean;
	children: (row: T) => ReactNode;
};

export const CardList = <T,>({ rows, ...props }: CardListProps<T>) => (
	<div className="space-y-5">
		{rows.map((row, i) => (
			// biome-ignore lint/suspicious/noArrayIndexKey: pas d'id générique disponible
			<CardRow key={i} row={row} {...props} />
		))}
	</div>
);
