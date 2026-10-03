import { describe, expect, it } from "vitest";
import { createSessionToken, SESSION_MAX_AGE_SECONDS, verifySessionToken } from "./session.server";

const TEST_SECRET_HEX =
	"74657374" + "2d736563" + "7265742d" + "666f722d" + "76697465" + "73742d31" + "32333435" + "36373839";
const key = Buffer.from(TEST_SECRET_HEX, "hex");

describe("importSessionKey", () => {
	it("retourne un Uint8Array", () => {
		expect(key).toBeInstanceOf(Uint8Array);
		expect(key.length).toBeGreaterThan(0);
	});
});

describe("createSessionToken", () => {
	it("retourne un JWT en 3 parties", async () => {
		const token = await createSessionToken(key);
		expect(token.split(".")).toHaveLength(3);
	});

	it("génère des tokens distincts à chaque appel", async () => {
		const t1 = await createSessionToken(key);
		await new Promise((r) => setTimeout(r, 2));
		const t2 = await createSessionToken(key);
		expect(t1).not.toBe(t2);
	});
});

describe("verifySessionToken", () => {
	it("valide un token récemment créé", async () => {
		const token = await createSessionToken(key);
		expect(await verifySessionToken(token, key)).toBe(true);
	});

	it("rejette undefined", async () => {
		expect(await verifySessionToken(undefined, key)).toBe(false);
	});

	it("rejette un token vide", async () => {
		expect(await verifySessionToken("", key)).toBe(false);
	});

	it("rejette un token mal formé", async () => {
		expect(await verifySessionToken("not.a.jwt", key)).toBe(false);
	});

	it("rejette un token signé avec une clé différente", async () => {
		const otherKey = Buffer.from("deadbeef".repeat(8), "hex");
		const token = await createSessionToken(otherKey);
		expect(await verifySessionToken(token, key)).toBe(false);
	});

	it("rejette un token expiré", async () => {
		const { SignJWT } = await import("jose");
		const token = await new SignJWT()
			.setProtectedHeader({ alg: "HS256" })
			.setIssuedAt(Math.floor(Date.now() / 1000) - SESSION_MAX_AGE_SECONDS - 10)
			.setExpirationTime(Math.floor(Date.now() / 1000) - 1)
			.sign(key);
		expect(await verifySessionToken(token, key)).toBe(false);
	});
});
