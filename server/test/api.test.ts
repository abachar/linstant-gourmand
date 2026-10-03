import { randomUUID } from "node:crypto";
import { updateSaleAction } from "@features/sales/actions";
import { beforeAll, describe, expect, it } from "vitest";
import * as login from "@/app/api/v1/auth/login/route";
import * as logout from "@/app/api/v1/auth/logout/route";
import * as refresh from "@/app/api/v1/auth/refresh/route";
import * as clients from "@/app/api/v1/clients/route";
import * as dashboard from "@/app/api/v1/dashboard/route";
import * as products from "@/app/api/v1/products/[id]/route";
import * as purchases from "@/app/api/v1/purchases/[id]/route";
import * as purchasesImport from "@/app/api/v1/purchases/import/route";
import * as sales from "@/app/api/v1/sales/[id]/route";
import * as sync from "@/app/api/v1/sync/route";
import { TEST_ADMIN_EMAIL, TEST_ADMIN_PASSWORD } from "./setup";

type Params = Record<string, string>;
// `never` accepts every route handler whatever its params type
type Handler = (request: Request, context: { params: Promise<never> }) => Promise<Response>;

let accessToken = "";

async function call(handler: Handler, method: string, path: string, body?: unknown, params: Params = {}) {
	const request = new Request(`http://localhost/api/v1${path}`, {
		method,
		headers: {
			authorization: `Bearer ${accessToken}`,
			"x-forwarded-for": "10.0.0.1",
			...(body !== undefined && { "content-type": "application/json" }),
		},
		body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body),
	});
	const response = await handler(request, { params: Promise.resolve(params) as Promise<never> });
	const text = await response.text();
	return { status: response.status, json: text ? JSON.parse(text) : null };
}

const saleInput = (overrides: Record<string, unknown> = {}) => ({
	clientName: "Dupont",
	deliveryDatetime: "2026-11-20T10:00:00.000Z",
	deliveryAddress: "1 rue de Paris",
	description: null,
	amount: "120.00",
	deposit: "40.00",
	depositPaymentMethod: "Bank",
	remaining: "80.00",
	remainingPaymentMethod: "Cash",
	items: [{ description: "Mini-quiches", unitPrice: "1.50", quantity: 80 }],
	...overrides,
});

const putSale = (id: string, body: unknown) => call(sales.PUT, "PUT", `/sales/${id}`, body, { id });

describe.skipIf(!process.env.TEST_DATABASE_URL)("API /api/v1", () => {
	beforeAll(async () => {
		const { status, json } = await call(login.POST, "POST", "/auth/login", {
			email: TEST_ADMIN_EMAIL,
			password: TEST_ADMIN_PASSWORD,
			deviceName: "iPhone de test",
		});
		expect(status).toBe(200);
		accessToken = json.accessToken;
	});

	describe("auth", () => {
		it("refuse un mauvais mot de passe", async () => {
			const { status, json } = await call(login.POST, "POST", "/auth/login", {
				email: TEST_ADMIN_EMAIL,
				password: "faux",
				deviceName: "x",
			});
			expect(status).toBe(401);
			expect(json.error.code).toBe("invalid_credentials");
		});

		it("refuse une requête sans token", async () => {
			const saved = accessToken;
			accessToken = "";
			const { status, json } = await call(sync.GET, "GET", "/sync");
			accessToken = saved;
			expect(status).toBe(401);
			expect(json.error.code).toBe("unauthorized");
		});

		it("fait tourner le refresh token, tolère un rejeu puis révoque au logout", async () => {
			const first = await call(login.POST, "POST", "/auth/login", {
				email: TEST_ADMIN_EMAIL,
				password: TEST_ADMIN_PASSWORD,
				deviceName: "iPad",
			});
			const rotated = await call(refresh.POST, "POST", "/auth/refresh", { refreshToken: first.json.refreshToken });
			expect(rotated.status).toBe(200);
			expect(rotated.json.refreshToken).not.toBe(first.json.refreshToken);

			// The response was "lost": the previous token is still accepted during the grace period.
			const replay = await call(refresh.POST, "POST", "/auth/refresh", { refreshToken: first.json.refreshToken });
			expect(replay.status).toBe(200);

			const saved = accessToken;
			accessToken = replay.json.accessToken;
			expect((await call(logout.POST, "POST", "/auth/logout", { refreshToken: replay.json.refreshToken })).status).toBe(
				204,
			);
			const afterLogout = await call(sync.GET, "GET", "/sync");
			accessToken = saved;
			expect(afterLogout.status).toBe(401);

			const refused = await call(refresh.POST, "POST", "/auth/refresh", { refreshToken: replay.json.refreshToken });
			expect(refused.status).toBe(401);
			expect(refused.json.error.code).toBe("invalid_refresh_token");
		});
	});

	describe("ventes", () => {
		it("crée, rejoue la création, met à jour et détecte les conflits", async () => {
			const id = randomUUID();
			const created = await putSale(id, { baseVersion: null, ...saleInput() });
			expect(created.status).toBe(200);
			expect(created.json).toMatchObject({ id, version: 1, amount: "120.00", deletedAt: null });
			expect(created.json.items).toEqual([{ description: "Mini-quiches", unitPrice: "1.50", quantity: 80 }]);

			// Replay of the creation (response lost): accepted while untouched.
			const replay = await putSale(id, { baseVersion: null, ...saleInput() });
			expect(replay.status).toBe(200);
			expect(replay.json.version).toBe(2);

			const updated = await putSale(id, { baseVersion: 2, ...saleInput({ clientName: "Martin" }) });
			expect(updated.json).toMatchObject({ version: 3, clientName: "Martin" });

			const stale = await putSale(id, { baseVersion: 2, ...saleInput({ clientName: "Durand" }) });
			expect(stale.status).toBe(409);
			expect(stale.json.error.code).toBe("conflict");
			expect(stale.json.current).toMatchObject({ id, version: 3, clientName: "Martin" });

			// "Garder la mienne": replay with the server version.
			const overwrite = await putSale(id, { baseVersion: 3, ...saleInput({ clientName: "Durand" }) });
			expect(overwrite.json).toMatchObject({ version: 4, clientName: "Durand" });
		});

		it("répond 409 avec current null pour une vente inconnue avec baseVersion", async () => {
			const { status, json } = await putSale(randomUUID(), { baseVersion: 3, ...saleInput() });
			expect(status).toBe(409);
			expect(json.current).toBeNull();
		});

		it("valide les montants", async () => {
			const { status, json } = await putSale(randomUUID(), { baseVersion: null, ...saleInput({ deposit: "50.00" }) });
			expect(status).toBe(422);
			expect(json.error.fields.remaining).toBeDefined();

			const items = await putSale(randomUUID(), {
				baseVersion: null,
				...saleInput({ amount: "130.00", remaining: "90.00" }),
			});
			expect(items.status).toBe(422);
			expect(items.json.error.fields.amount).toBeDefined();
		});

		it("accepte les anciens libellés de paiement", async () => {
			const { status, json } = await putSale(randomUUID(), {
				baseVersion: null,
				...saleInput({ depositPaymentMethod: "Bancaire", remainingPaymentMethod: "Espèces" }),
			});
			expect(status).toBe(200);
			expect(json).toMatchObject({ depositPaymentMethod: "Bank", remainingPaymentMethod: "Cash" });
		});

		it("supprime logiquement, de façon idempotente, avec contrôle de version", async () => {
			const id = randomUUID();
			await putSale(id, { baseVersion: null, ...saleInput() });

			const stale = await call(sales.DELETE, "DELETE", `/sales/${id}?baseVersion=7`, undefined, { id });
			expect(stale.status).toBe(409);

			const deleted = await call(sales.DELETE, "DELETE", `/sales/${id}?baseVersion=1`, undefined, { id });
			expect(deleted.status).toBe(200);
			expect(deleted.json.deletedAt).not.toBeNull();

			const again = await call(sales.DELETE, "DELETE", `/sales/${id}?baseVersion=1`, undefined, { id });
			expect(again.status).toBe(200);

			const edit = await putSale(id, { baseVersion: deleted.json.version, ...saleInput() });
			expect(edit.status).toBe(409);
			expect(edit.json.current.deletedAt).not.toBeNull();
		});

		it("détecte un conflit côté web (Server Action)", async () => {
			const id = randomUUID();
			await putSale(id, { baseVersion: null, ...saleInput() });
			await putSale(id, { baseVersion: 1, ...saleInput({ clientName: "Depuis l'iPhone" }) });

			const result = await updateSaleAction({ id, version: 1, ...saleInput(), description: undefined } as never);
			expect(result).toMatchObject({ ok: false, code: "conflict" });
		});
	});

	describe("achats et stock", () => {
		it("interdit de modifier un achat importé", async () => {
			const csv = "Type,Date de début,Description,Montant\nPaiement par carte,2026-09-01 10:00:00,Metro,-42.50\n";
			const imported = await call(purchasesImport.POST, "POST", "/purchases/import", csv);
			expect(imported.json).toEqual({ inserted: 1 });

			const { json: feed } = await call(sync.GET, "GET", "/sync?cursor=0");
			const purchase = feed.purchases.find((p: { description: string }) => p.description === "Metro");
			expect(purchase).toMatchObject({ amount: "42.50", isImported: true });

			const edit = await call(
				purchases.PUT,
				"PUT",
				`/purchases/${purchase.id}`,
				{ baseVersion: 1, date: purchase.date, amount: "1.00", description: "x" },
				{ id: purchase.id },
			);
			expect(edit.status).toBe(403);
		});

		it("crée et met à jour un produit", async () => {
			const id = randomUUID();
			const body = {
				baseVersion: null,
				productName: "Beurre",
				quantity: 4,
				expirationDate: "2026-12-01T00:00:00.000Z",
			};
			const created = await call(products.PUT, "PUT", `/products/${id}`, body, { id });
			expect(created.json).toMatchObject({ version: 1, productName: "Beurre", quantity: 4 });

			const invalid = await call(
				products.PUT,
				"PUT",
				`/products/${id}`,
				{ ...body, baseVersion: 1, quantity: -1 },
				{ id },
			);
			expect(invalid.status).toBe(422);
			expect(invalid.json.error.fields.quantity).toBeDefined();
		});
	});

	describe("synchronisation", () => {
		it("renvoie les changements depuis un curseur, suppressions comprises, par pages", async () => {
			const { json: before } = await call(sync.GET, "GET", "/sync?cursor=0&limit=1000");
			expect(before.hasMore).toBe(false);
			expect(before.sales.every((s: { deletedAt: string | null }) => s.deletedAt === null)).toBe(true);

			const kept = randomUUID();
			const removed = randomUUID();
			await putSale(kept, { baseVersion: null, ...saleInput({ clientName: "Sync A" }) });
			await putSale(removed, { baseVersion: null, ...saleInput({ clientName: "Sync B" }) });
			await call(sales.DELETE, "DELETE", `/sales/${removed}?baseVersion=1`, undefined, { id: removed });

			const page1 = await call(sync.GET, "GET", `/sync?cursor=${before.cursor}&limit=1`);
			expect(page1.json.hasMore).toBe(true);
			expect(page1.json.sales.map((s: { id: string }) => s.id)).toEqual([kept]);

			const page2 = await call(sync.GET, "GET", `/sync?cursor=${page1.json.cursor}&limit=10`);
			expect(page2.json.hasMore).toBe(false);
			expect(page2.json.sales).toHaveLength(1);
			expect(page2.json.sales[0]).toMatchObject({ id: removed, version: 2 });
			expect(page2.json.sales[0].deletedAt).not.toBeNull();

			const empty = await call(sync.GET, "GET", `/sync?cursor=${page2.json.cursor}`);
			expect(empty.json).toMatchObject({
				cursor: page2.json.cursor,
				hasMore: false,
				sales: [],
				purchases: [],
				products: [],
			});
		});

		it("propage le renommage d'un client aux ventes concernées", async () => {
			const id = randomUUID();
			await putSale(id, { baseVersion: null, ...saleInput({ clientName: "Ancien Nom", deliveryAddress: null }) });
			const { json: before } = await call(sync.GET, "GET", "/sync?cursor=0&limit=1000");

			const renamed = await call(clients.PUT, "PUT", "/clients", {
				oldClientName: "Ancien Nom",
				oldDeliveryAddress: null,
				newClientName: "Nouveau Nom",
				newDeliveryAddress: "2 rue de Lyon",
			});
			expect(renamed.status).toBe(204);

			const { json: after } = await call(sync.GET, "GET", `/sync?cursor=${before.cursor}`);
			expect(after.sales).toHaveLength(1);
			expect(after.sales[0]).toMatchObject({
				id,
				version: 2,
				clientName: "Nouveau Nom",
				deliveryAddress: "2 rue de Lyon",
			});
		});
	});

	it("exclut les ventes supprimées du tableau de bord", async () => {
		const month = "2031-03";
		const id = randomUUID();
		await putSale(id, { baseVersion: null, ...saleInput({ deliveryDatetime: "2031-03-10T10:00:00.000Z" }) });
		expect((await call(dashboard.GET, "GET", `/dashboard?month=${month}`)).json.currentMonthSales).toBe(120);

		await call(sales.DELETE, "DELETE", `/sales/${id}?baseVersion=1`, undefined, { id });
		expect((await call(dashboard.GET, "GET", `/dashboard?month=${month}`)).json.currentMonthSales).toBe(0);
	});
});
