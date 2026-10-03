"use server";

import { login } from "./api.server";

export async function loginAction(email: string, password: string) {
	await login(email, password);
}
