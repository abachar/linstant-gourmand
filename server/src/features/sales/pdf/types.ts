/** What the quote/invoice PDF needs from a sale: a single sale or each sale of a grouped invoice. */
export interface PrintSale {
	id: string;
	clientName: string;
	deliveryDatetime: Date;
	deliveryAddress: string | null;
	items: PrintItem[];
}

export interface PrintItem {
	id: string;
	description: string;
	unitPrice: string;
	quantity: number;
}

export const itemsTotal = (items: PrintItem[]) =>
	items.reduce((sum, item) => sum + Number.parseFloat(item.unitPrice) * item.quantity, 0);
