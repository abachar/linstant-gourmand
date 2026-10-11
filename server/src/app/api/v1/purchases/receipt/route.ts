import { BadRequestError, route } from "@features/api/http.server";
import {
	MAX_RECEIPT_BYTES,
	RECEIPT_MEDIA_TYPES,
	type ReceiptMediaType,
	scanReceipt,
} from "@features/purchases/receipt.server";

/** Body: the photo itself (image/jpeg, image/png or image/webp). Nothing is saved, see docs/api.md. */
export const POST = route(async (request) => {
	const mediaType = request.headers.get("content-type")?.split(";")[0]?.trim().toLowerCase();
	if (!RECEIPT_MEDIA_TYPES.includes(mediaType as ReceiptMediaType)) {
		throw new BadRequestError("Image attendue (image/jpeg, image/png ou image/webp).");
	}
	const length = Number(request.headers.get("content-length"));
	if (length > MAX_RECEIPT_BYTES) throw new BadRequestError("Image trop lourde (5 Mo maximum).");

	const image = Buffer.from(await request.arrayBuffer());
	return Response.json(await scanReceipt(image, mediaType as ReceiptMediaType));
});
