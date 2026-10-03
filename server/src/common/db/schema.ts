import { sql } from "drizzle-orm";
import { bigint, index, integer, numeric, pgSequence, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";

/**
 * Sync columns shared by every entity the iOS app edits offline.
 * - version: optimistic locking, compared against the client's baseVersion.
 * - changeSeq: global sync cursor (GET /api/v1/sync?cursor=).
 * - deletedAt: soft delete, so deletions reach an offline device.
 * The trigger `bump_sync_columns` (drizzle/0001_sync.sql) increments version, changeSeq and
 * updatedAt on every UPDATE: application code never sets them.
 */
export const syncSeq = pgSequence("sync_seq");

const syncColumns = () => ({
	version: integer("version").notNull().default(1),
	changeSeq: bigint("change_seq", { mode: "number" }).notNull().default(sql`nextval('sync_seq')`),
	updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
	deletedAt: timestamp("deleted_at", { withTimezone: true }),
});

export const sales = pgTable(
	"sales",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		clientName: text("client_name").notNull(),
		deliveryDatetime: timestamp("delivery_datetime", {
			withTimezone: true,
		}).notNull(),
		deliveryAddress: text("delivery_address"),
		description: text("description"),
		amount: numeric("amount", { precision: 10, scale: 2 }).notNull(),
		deposit: numeric("deposit", { precision: 10, scale: 2 }).notNull(),
		depositPaymentMethod: text("deposit_payment_method").notNull(),
		remaining: numeric("remaining", { precision: 10, scale: 2 }).notNull(),
		remainingPaymentMethod: text("remaining_payment_method").notNull(),
		createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
		...syncColumns(),
	},
	(t) => [index("idx_sales_delivery_datetime").on(t.deliveryDatetime), index("idx_sales_change_seq").on(t.changeSeq)],
);

export const saleItems = pgTable(
	"sale_items",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		saleId: uuid("sale_id")
			.notNull()
			.references(() => sales.id, { onDelete: "cascade" }),
		description: text("description").notNull(),
		unitPrice: numeric("unit_price", { precision: 10, scale: 2 }).notNull(),
		quantity: integer("quantity").notNull(),
		sortOrder: integer("sort_order").notNull().default(0),
	},
	(t) => [index("idx_sale_items_sale_id").on(t.saleId)],
);

export const purchases = pgTable(
	"purchases",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		date: timestamp("date", { withTimezone: true }).notNull(),
		amount: numeric("amount", { precision: 10, scale: 2 }).notNull(),
		description: text("description"),
		importRef: text("import_ref").unique(),
		createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
		...syncColumns(),
	},
	(t) => [index("idx_purchases_date").on(t.date), index("idx_purchases_change_seq").on(t.changeSeq)],
);

export const products = pgTable(
	"products",
	{
		id: uuid("id").primaryKey().defaultRandom(),
		productName: text("product_name").notNull(),
		quantity: integer("quantity").notNull().default(0),
		expirationDate: timestamp("expiration_date", { withTimezone: true }),
		...syncColumns(),
	},
	(t) => [index("idx_products_product_name").on(t.productName), index("idx_products_change_seq").on(t.changeSeq)],
);

/** Refresh tokens of the native app, one row per device. Only the SHA-256 of each token is stored. */
export const apiSessions = pgTable("api_sessions", {
	id: uuid("id").primaryKey().defaultRandom(),
	tokenHash: text("token_hash").notNull().unique(),
	// The token replaced by the last rotation, still accepted for a short grace period in case the
	// refresh response never reached the device (flaky network).
	previousTokenHash: text("previous_token_hash"),
	rotatedAt: timestamp("rotated_at", { withTimezone: true }),
	deviceName: text("device_name").notNull(),
	createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
	lastUsedAt: timestamp("last_used_at", { withTimezone: true }).defaultNow().notNull(),
	expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
	revokedAt: timestamp("revoked_at", { withTimezone: true }),
});
