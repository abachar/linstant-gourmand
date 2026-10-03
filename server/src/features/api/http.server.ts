import { ConflictError, ForbiddenError, NotFoundError } from "@common/errors";
import { zodFields } from "@common/validation";
import { InvalidCredentialsError, RateLimitError } from "@features/auth/api.server";
import { InvalidRefreshTokenError, verifyAccessToken } from "@features/auth/api-session.server";
import { z } from "zod";

/** JSON helpers and error mapping for /api/v1 (format documented in docs/api.md, "Erreurs"). */

export class BadRequestError extends Error {}

type ErrorExtra = { fields?: Record<string, string>; current?: unknown };

export function apiError(status: number, code: string, message: string, { fields, ...extra }: ErrorExtra = {}) {
	return Response.json({ error: { code, message, ...(fields && { fields }) }, ...extra }, { status });
}

function toErrorResponse(e: unknown): Response {
	if (e instanceof ConflictError) {
		return apiError(409, "conflict", e.message, { current: e.current });
	}
	if (e instanceof z.ZodError) {
		return apiError(422, "validation", "Données invalides.", { fields: zodFields(e) });
	}
	if (e instanceof ForbiddenError) return apiError(403, "forbidden", e.message);
	if (e instanceof NotFoundError) return apiError(404, "not_found", e.message);
	if (e instanceof BadRequestError) return apiError(400, "bad_request", e.message);
	if (e instanceof InvalidCredentialsError) return apiError(401, "invalid_credentials", e.message);
	if (e instanceof InvalidRefreshTokenError) return apiError(401, "invalid_refresh_token", e.message);
	if (e instanceof RateLimitError) return apiError(429, "rate_limited", e.message);

	console.error("[api]", e);
	return apiError(500, "internal", "Erreur serveur.");
}

type Handler<P> = (request: Request, params: P) => Promise<Response>;
type RouteContext<P> = { params: Promise<P> };

/** Public route (login, refresh): only error mapping. */
export function publicRoute<P = Record<string, never>>(handler: Handler<P>) {
	return async (request: Request, context: RouteContext<P>) => {
		try {
			return await handler(request, await context.params);
		} catch (e) {
			return toErrorResponse(e);
		}
	};
}

/** Authenticated route: requires `Authorization: Bearer <accessToken>`. */
export function route<P = Record<string, never>>(handler: Handler<P>) {
	return publicRoute<P>(async (request, params) => {
		const token = request.headers.get("authorization")?.match(/^Bearer (.+)$/i)?.[1];
		if (!(await verifyAccessToken(token))) {
			return apiError(401, "unauthorized", "Authentification requise.");
		}
		return handler(request, params);
	});
}

export async function readJson(request: Request): Promise<unknown> {
	try {
		return await request.json();
	} catch {
		throw new BadRequestError("JSON invalide.");
	}
}

export const uuidParam = z.uuid();

export function parseId(id: string) {
	const result = uuidParam.safeParse(id);
	if (!result.success) throw new NotFoundError();
	return result.data.toLowerCase();
}

/** `baseVersion` query parameter of DELETE routes. */
export function parseBaseVersion(request: Request) {
	const value = Number(new URL(request.url).searchParams.get("baseVersion"));
	if (!Number.isInteger(value) || value < 1) throw new BadRequestError("Paramètre baseVersion manquant ou invalide.");
	return value;
}

export function clientIp(request: Request) {
	return request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
}
