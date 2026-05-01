// 결 (Gyeol) — polished_output_cache 키 산출 (방향성 분리)
// 매칭알고리즘 v7 §8.4

import type { RecommendationNarrative } from "./types.ts";

const enc = new TextEncoder();

async function sha256(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", enc.encode(input));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function computeDraftHash(
  draft: RecommendationNarrative,
): Promise<string> {
  return await sha256(
    [draft.headline, draft.alignment_narrative, draft.tension_narrative].join(
      "",
    ),
  );
}

/** 매칭알고리즘 v7 §8.4 — viewer_id 명시. A→B와 B→A 분리.
 *  candidate_brief가 viewer 기준이므로 narrative가 viewer마다 다름 → 캐시도 분리.
 */
export async function computePolishCacheKey(input: {
  viewerId: string;
  candidateId: string;
  viewerProfileVersion: string;
  candidateProfileVersion: string;
  assessmentVersion: string;
  templateLibraryVersion: string;
  polishPromptVersion: string;
  draftHash: string;
}): Promise<string> {
  const seed = [
    input.viewerId,
    input.candidateId,
    input.viewerProfileVersion,
    input.candidateProfileVersion,
    input.assessmentVersion,
    input.templateLibraryVersion,
    input.polishPromptVersion,
    input.draftHash,
  ].join("");
  return await sha256(seed);
}
