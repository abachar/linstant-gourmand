import { jwtVerify } from "jose";
import { type NextRequest, NextResponse } from "next/server";

const COOKIE_NAME = "auth_session";

function getSessionKey(): Uint8Array {
	const secretHex = process.env.SESSION_SECRET_HEX;
	if (!secretHex) throw new Error("SESSION_SECRET_HEX is not set");
	return Buffer.from(secretHex, "hex");
}

export async function proxy(request: NextRequest) {
	const { pathname } = request.nextUrl;

	if (pathname === "/login") {
		const token = request.cookies.get(COOKIE_NAME)?.value;
		if (token) {
			try {
				await jwtVerify(token, getSessionKey());
				return NextResponse.redirect(new URL("/", request.url));
			} catch {
				// token invalid, let them see login
			}
		}
		return NextResponse.next();
	}

	const token = request.cookies.get(COOKIE_NAME)?.value;
	if (!token) {
		return NextResponse.redirect(new URL("/login", request.url));
	}

	try {
		await jwtVerify(token, getSessionKey());
		return NextResponse.next();
	} catch {
		return NextResponse.redirect(new URL("/login", request.url));
	}
}

export const config = {
	matcher: ["/((?!_next/static|_next/image|images|favicon.ico).*)"],
};
