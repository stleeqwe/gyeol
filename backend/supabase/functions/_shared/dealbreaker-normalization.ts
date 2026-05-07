import type { DomainId, Intensity, Scope, Stance } from "./types.ts";

export interface PendingDealbreakerRow {
  id: string;
  domain: DomainId;
  seq: number;
  raw_user_text_ciphertext?: string | null;
}

export interface DealbreakerNormalizationInput {
  input_id: string;
  row: PendingDealbreakerRow;
}

export interface NormalizedDealbreakerItem {
  input_id: string;
  domain_id?: DomainId;
  canonical_target_id: string | null;
  unacceptable_stances: Stance[];
  intensity_min_for_conflict: Intensity;
  scope: Scope;
  confidence?: "high" | "medium" | "low";
  unmapped_reason?: string | null;
}

export interface MappedDealbreakerItem {
  row: PendingDealbreakerRow;
  item: NormalizedDealbreakerItem;
}

export function buildDealbreakerNormalizationInputs(
  rows: readonly PendingDealbreakerRow[],
): DealbreakerNormalizationInput[] {
  return rows.map((row, index) => ({
    input_id: `db_${String(index + 1).padStart(3, "0")}`,
    row,
  }));
}

export function mapNormalizedDealbreakerItems(
  inputs: readonly DealbreakerNormalizationInput[],
  items: readonly NormalizedDealbreakerItem[],
): MappedDealbreakerItem[] {
  if (items.length !== inputs.length) {
    throw new Error("dealbreaker_normalization_count_mismatch");
  }

  const inputById = new Map(inputs.map((input) => [input.input_id, input]));
  const seen = new Set<string>();
  const mapped: MappedDealbreakerItem[] = [];

  for (const item of items) {
    if (seen.has(item.input_id)) {
      throw new Error("dealbreaker_normalization_duplicate_input_id");
    }
    seen.add(item.input_id);

    const input = inputById.get(item.input_id);
    if (!input) {
      throw new Error("dealbreaker_normalization_unknown_input_id");
    }
    mapped.push({ row: input.row, item });
  }

  return mapped;
}
