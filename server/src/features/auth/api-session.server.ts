import { createHash, randomBytes } from "node:crypto";
import { apiSessions, db } from "@common/db";
import { addDays, addMinutes, subMinutes } from "date-fns";
import { and, eq, gt, isNull, or } from "drizzle-orm";
import { jwtVerify, SignJWT } from "jose";
import { getSessionKey } from "./api.server";

/** Native app sessions: short-lived JWT access token + rotating refresh token (docs/api.md, "Auth"). */

const ACCESS_TOKEN_MINUTES = 15;
const REFRESH_TOKEN_DAYS = 90;
const ROTATION_GRACE_MINUTES = 5;

export class InvalidRefreshTokenError extends Error {}

const hashToken = (token: string) => createHash("sha256").update(token).digest("hex");

async function issueTokens(sessionId: string, refreshToken: string, refreshTokenExpiresAt: Date) {
	const accessTokenExpiresAt = addMinutes(new Date(), ACCESS_TOKEN_MINUTES);
	const accessToken = await new SignJWT({ typ: "access" })
		.setProtectedHeader({ alg: "HS256" })
		.setSubject(sessionId)
		.setIssuedAt()
		.setExpirationTime(accessTokenExpiresAt)
		.sign(getSessionKey());

	return {
		accessToken,
		accessTokenExpiresAt: accessTokenExpiresAt.toISOString(),
		refreshToken,
		refreshTokenExpiresAt: refreshTokenExpiresAt.toISOString(),
	};
}

export type ApiTokens = Awaited<ReturnType<typeof issueTokens>>;

/** Opens a session for a device whose credentials were already verified. */
export async function createApiSession(deviceName: string): Promise<ApiTokens> {
	const refreshToken = randomBytes(32).toString("base64url");
	const expiresAt = addDays(new Date(), REFRESH_TOKEN_DAYS);
	const [session] = await db
		.insert(apiSessions)
		.values({ tokenHash: hashToken(refreshToken), deviceName, expiresAt })
		.returning({ id: apiSessions.id });
	return issueTokens(session.id, refreshToken, expiresAt);
}

/**
 * Rotates the refresh token. The previous token stays valid for a few minutes so a device that never
 * received the response (flaky network) can retry instead of being logged out.
 */
export async function refreshApiSession(refreshToken: string): Promise<ApiTokens> {
	const hash = hashToken(refreshToken);
	const now = new Date();

	return await db.transaction(async (tx) => {
		const [session] = await tx
			.select()
			.from(apiSessions)
			.where(
				and(
					or(
						eq(apiSessions.tokenHash, hash),
						and(
							eq(apiSessions.previousTokenHash, hash),
							gt(apiSessions.rotatedAt, subMinutes(now, ROTATION_GRACE_MINUTES)),
						),
					),
					isNull(apiSessions.revokedAt),
					gt(apiSessions.expiresAt, now),
				),
			)
			.for("update");
		if (!session) throw new InvalidRefreshTokenError("Session expirée, reconnectez-vous.");

		const nextToken = randomBytes(32).toString("base64url");
		const expiresAt = addDays(now, REFRESH_TOKEN_DAYS);
		const isCurrentToken = session.tokenHash === hash;
		await tx
			.update(apiSessions)
			.set({
				tokenHash: hashToken(nextToken),
				// A retry with the previous token keeps the original grace window.
				previousTokenHash: isCurrentToken ? hash : session.previousTokenHash,
				rotatedAt: isCurrentToken ? now : session.rotatedAt,
				lastUsedAt: now,
				expiresAt,
			})
			.where(eq(apiSessions.id, session.id));

		return issueTokens(session.id, nextToken, expiresAt);
	});
}

export async function revokeApiSession(refreshToken: string) {
	const hash = hashToken(refreshToken);
	await db
		.update(apiSessions)
		.set({ revokedAt: new Date() })
		.where(
			and(or(eq(apiSessions.tokenHash, hash), eq(apiSessions.previousTokenHash, hash)), isNull(apiSessions.revokedAt)),
		);
}

/** Validates a Bearer access token and that its session has not been revoked. */
export async function verifyAccessToken(token: string | undefined): Promise<boolean> {
	if (!token) return false;
	try {
		const { payload } = await jwtVerify(token, getSessionKey(), { algorithms: ["HS256"] });
		if (payload.typ !== "access" || !payload.sub) return false;

		const [session] = await db
			.select({ id: apiSessions.id })
			.from(apiSessions)
			.where(and(eq(apiSessions.id, payload.sub), isNull(apiSessions.revokedAt)))
			.limit(1);
		return session !== undefined;
	} catch {
		return false;
	}
}
