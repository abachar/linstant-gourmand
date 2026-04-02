import { scrypt, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { cookies, headers } from "next/headers";
import { RateLimiterMemory } from "rate-limiter-flexible";
import { createSessionToken, SESSION_MAX_AGE_SECONDS, verifySessionToken } from "./session";

const rateLimiter = new RateLimiterMemory({ points: 5, duration: 15 * 60 });
const scryptAsync = promisify(scrypt);
const COOKIE_NAME = "auth_session";

function getSessionKey(): Uint8Array {
	const secretHex = process.env.SESSION_SECRET_HEX;
	if (!secretHex) throw new Error("SESSION_SECRET_HEX is not set");
	return Buffer.from(secretHex, "hex");
}

function getStoredPassword() {
	const adminPasswordHex = process.env.APP_ADMIN_PASSWORD_HEX;
	if (!adminPasswordHex) throw new Error("APP_ADMIN_PASSWORD_HEX is not set");

	const [salt, storedHash] = adminPasswordHex.split(":");
	if (!salt || !storedHash) throw new Error("APP_ADMIN_PASSWORD_HEX has invalide format");

	return [salt, storedHash];
}

function verifyEmail(email: string) {
	const adminEmail = process.env.APP_ADMIN_EMAIL;
	if (!adminEmail) throw new Error("APP_ADMIN_EMAIL is not set");
	return email === adminEmail;
}

async function verifyPassword(password: string) {
	const [salt, storedHash] = getStoredPassword();
	const derivedKey = (await scryptAsync(password, salt, 64)) as Buffer;
	const storedKey = Buffer.from(storedHash, "hex");

	return timingSafeEqual(derivedKey, storedKey);
}

async function getRequestIP(): Promise<string> {
	const h = await headers();
	return h.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
}

export async function login(email: string, password: string) {
	const ip = await getRequestIP();

	try {
		await rateLimiter.consume(ip);
	} catch (e: unknown) {
		const msBeforeNext = (e as { msBeforeNext?: number }).msBeforeNext ?? 0;
		const remainingMin = Math.ceil(msBeforeNext / 60000);
		throw new Error(`Trop de tentatives. Réessayez dans ${remainingMin} minute${remainingMin > 1 ? "s" : ""}.`);
	}

	const emailValid = verifyEmail(email);
	const passwordValid = emailValid && (await verifyPassword(password));

	if (!emailValid || !passwordValid) {
		throw new Error("Email ou mot de passe incorrect.");
	}

	await rateLimiter.delete(ip);

	const key = getSessionKey();
	const token = await createSessionToken(key);
	const cookieStore = await cookies();
	cookieStore.set(COOKIE_NAME, token, {
		httpOnly: true,
		sameSite: "lax",
		path: "/",
		maxAge: SESSION_MAX_AGE_SECONDS,
		secure: process.env.NODE_ENV === "production",
	});
}

export async function getSession() {
	try {
		const cookieStore = await cookies();
		const token = cookieStore.get(COOKIE_NAME)?.value;
		const key = getSessionKey();
		return { authenticated: await verifySessionToken(token, key) };
	} catch (e) {
		console.error(e);
		return { authenticated: false };
	}
}
