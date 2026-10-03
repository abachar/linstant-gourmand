import { ZodError } from "zod";

/** The client's baseVersion no longer matches the server: `current` is the server entity (null if it never existed). */
export class ConflictError<T = unknown> extends Error {
	constructor(readonly current: T | null) {
		super("Cet élément a été modifié ailleurs.");
		this.name = "ConflictError";
	}
}

export class NotFoundError extends Error {
	constructor(message = "Élément introuvable.") {
		super(message);
		this.name = "NotFoundError";
	}
}

export class ForbiddenError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "ForbiddenError";
	}
}

/**
 * Result returned by mutating Server Actions: thrown errors lose their message in production,
 * so expected failures (conflict, validation, forbidden) are returned instead.
 */
export type ActionResult<T = void> = { ok: true; data: T } | { ok: false; code: string; message: string };

/** Runs a mutation for a Server Action, turning expected errors into a French message for the UI. */
export async function runAction<T>(fn: () => Promise<T>): Promise<ActionResult<T>> {
	try {
		return { ok: true, data: await fn() };
	} catch (e) {
		if (e instanceof ConflictError) {
			return {
				ok: false,
				code: "conflict",
				message:
					"Cet élément a été modifié ou supprimé ailleurs (sur l'iPhone ?). Rechargez la page pour voir la dernière version.",
			};
		}
		if (e instanceof ZodError) {
			return { ok: false, code: "validation", message: e.issues.map((i) => i.message).join("\n") };
		}
		if (e instanceof ForbiddenError || e instanceof NotFoundError) {
			return { ok: false, code: e instanceof ForbiddenError ? "forbidden" : "not_found", message: e.message };
		}
		throw e;
	}
}
