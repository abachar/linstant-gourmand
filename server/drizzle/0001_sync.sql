CREATE SEQUENCE "public"."sync_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1;--> statement-breakpoint
CREATE TABLE "api_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"token_hash" text NOT NULL,
	"previous_token_hash" text,
	"rotated_at" timestamp with time zone,
	"device_name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_used_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	CONSTRAINT "api_sessions_token_hash_unique" UNIQUE("token_hash")
);
--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "version" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "change_seq" bigint DEFAULT nextval('sync_seq') NOT NULL;--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "deleted_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "purchases" ADD COLUMN "version" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "purchases" ADD COLUMN "change_seq" bigint DEFAULT nextval('sync_seq') NOT NULL;--> statement-breakpoint
ALTER TABLE "purchases" ADD COLUMN "updated_at" timestamp with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "purchases" ADD COLUMN "deleted_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "sales" ADD COLUMN "version" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "sales" ADD COLUMN "change_seq" bigint DEFAULT nextval('sync_seq') NOT NULL;--> statement-breakpoint
ALTER TABLE "sales" ADD COLUMN "updated_at" timestamp with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "sales" ADD COLUMN "deleted_at" timestamp with time zone;--> statement-breakpoint
CREATE INDEX "idx_products_change_seq" ON "products" USING btree ("change_seq");--> statement-breakpoint
CREATE INDEX "idx_purchases_change_seq" ON "purchases" USING btree ("change_seq");--> statement-breakpoint
CREATE INDEX "idx_sales_change_seq" ON "sales" USING btree ("change_seq");--> statement-breakpoint
-- Every UPDATE (web, API, bulk client rename, soft delete) bumps the sync columns, so no write path can forget to.
CREATE OR REPLACE FUNCTION "bump_sync_columns"() RETURNS trigger AS $$
BEGIN
	NEW.version := OLD.version + 1;
	NEW.change_seq := nextval('sync_seq');
	NEW.updated_at := now();
	RETURN NEW;
END
$$ LANGUAGE plpgsql;--> statement-breakpoint
CREATE TRIGGER "sales_bump_sync_columns" BEFORE UPDATE ON "sales" FOR EACH ROW EXECUTE FUNCTION "bump_sync_columns"();--> statement-breakpoint
CREATE TRIGGER "purchases_bump_sync_columns" BEFORE UPDATE ON "purchases" FOR EACH ROW EXECUTE FUNCTION "bump_sync_columns"();--> statement-breakpoint
CREATE TRIGGER "products_bump_sync_columns" BEFORE UPDATE ON "products" FOR EACH ROW EXECUTE FUNCTION "bump_sync_columns"();
