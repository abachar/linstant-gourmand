/**
 * Optimistic locking rules shared by every offline-editable entity (see docs/api.md, "Écriture").
 * The row must be read with FOR UPDATE in the same transaction as the write.
 */
type Versioned = { version: number; deletedAt: Date | null };

export function decideWrite(
	existing: Versioned | undefined,
	baseVersion: number | null,
): "create" | "update" | "conflict" {
	if (!existing) return baseVersion === null ? "create" : "conflict";
	if (existing.deletedAt) return "conflict";
	// baseVersion null on an existing row: replay of a creation whose response was lost, valid while untouched.
	const expected = baseVersion ?? 1;
	return existing.version === expected ? "update" : "conflict";
}

export function decideDelete(
	existing: Versioned | undefined,
	baseVersion: number,
): "delete" | "noop" | "conflict" | "not_found" {
	if (!existing) return "not_found";
	if (existing.deletedAt) return "noop";
	return existing.version === baseVersion ? "delete" : "conflict";
}
