import { jwtVerify, SignJWT } from "jose";

export const SESSION_MAX_AGE_SECONDS = 7 * 24 * 60 * 60; // 7 days

export async function createSessionToken(key: Uint8Array): Promise<string> {
	return new SignJWT()
		.setProtectedHeader({ alg: "HS256" })
		.setJti(crypto.randomUUID())
		.setIssuedAt()
		.setExpirationTime(`${SESSION_MAX_AGE_SECONDS}s`)
		.sign(key);
}

export async function verifySessionToken(token: string | undefined, key: Uint8Array): Promise<boolean> {
	if (!token) return false;
	try {
		await jwtVerify(token, key);
		return true;
	} catch {
		return false;
	}
}
