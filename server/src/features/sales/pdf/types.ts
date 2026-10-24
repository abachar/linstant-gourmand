import { amount } from "@common/format";

/**
 * Amount for the PDF: the fr-FR thousands separator is a narrow no-break space (U+202F), which the
 * built-in Helvetica of react-pdf has no glyph for (it printed "1/042,00 €").
 */
export const printAmount = (value: number | string) => amount(value).replace(/[\u202F\u00A0]/g, " ");

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
