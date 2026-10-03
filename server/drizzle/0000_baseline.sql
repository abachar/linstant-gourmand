-- Baseline: the production database predates migrations, so every statement is
-- idempotent (IF NOT EXISTS) and this file is a no-op on an existing database.
CREATE TABLE IF NOT EXISTS "products" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"product_name" text NOT NULL,
	"quantity" integer DEFAULT 0 NOT NULL,
	"expiration_date" timestamp with time zone,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "purchases" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"date" timestamp with time zone NOT NULL,
	"amount" numeric(10, 2) NOT NULL,
	"description" text,
	"import_ref" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "purchases_import_ref_unique" UNIQUE("import_ref")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "sale_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"sale_id" uuid NOT NULL,
	"description" text NOT NULL,
	"unit_price" numeric(10, 2) NOT NULL,
	"quantity" integer NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "sales" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"client_name" text NOT NULL,
	"delivery_datetime" timestamp with time zone NOT NULL,
	"delivery_address" text,
	"description" text,
	"amount" numeric(10, 2) NOT NULL,
	"deposit" numeric(10, 2) NOT NULL,
	"deposit_payment_method" text NOT NULL,
	"remaining" numeric(10, 2) NOT NULL,
	"remaining_payment_method" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
	IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = '"sale_items"'::regclass AND contype = 'f') THEN
		ALTER TABLE "sale_items" ADD CONSTRAINT "sale_items_sale_id_sales_id_fk" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id") ON DELETE cascade ON UPDATE no action;
	END IF;
END $$;--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_products_product_name" ON "products" USING btree ("product_name");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_purchases_date" ON "purchases" USING btree ("date");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_sale_items_sale_id" ON "sale_items" USING btree ("sale_id");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_sales_delivery_datetime" ON "sales" USING btree ("delivery_datetime");