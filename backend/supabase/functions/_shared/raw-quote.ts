// 결 (Gyeol) — raw quote detector
// 매칭알고리즘 v7 §2.2 + AI프롬프트 v7 §1.3
// 3중 방어선 중 2차 (정규화 레이어). 1차는 LLM 자체, 3차는 매트릭스 엔진.

const QUOTE_PATTERNS: RegExp[] = [
  /(['"][^'"]{5,}['"])/u, // "..." 또는 '...' 5자 이상
  /([「『].{4,}?[」』])/u, // 한국 따옴표
  /(<<.{4,}?>>)/u,
];

/** n-gram (substring) overlap 검사 — 8자 이상 연속 일치
 *  단순한 sliding window. 운영 단계에서 normalize(공백, 조사, 대소문자) 보강 필요.
 */
function ngramOverlap(text: string, source: string, minLength = 8): boolean {
  if (text.length < minLength || source.length < minLength) return false;
  const t = text.replace(/\s+/g, " ");
  const s = source.replace(/\s+/g, " ");
  for (let i = 0; i + minLength <= t.length; i++) {
    const slice = t.slice(i, i + minLength);
    if (s.includes(slice)) return true;
  }
  return false;
}

export interface RawQuoteCheckResult {
  detected: boolean;
  reason?: "quote_pattern" | "ngram_overlap";
  matchedPattern?: string;
}

/** summary 텍스트에 raw quote가 포함되었는지 검사.
 *  rawAnswers는 현재 사용자가 영역에 작성한 모든 raw 답변 합본.
 */
export function detectRawQuoteInSummary(
  summary: string,
  rawAnswers: string,
  options: { ngramMinLength?: number } = {},
): RawQuoteCheckResult {
  const minLen = options.ngramMinLength ?? 8;

  for (const pat of QUOTE_PATTERNS) {
    const m = summary.match(pat);
    if (m) {
      return { detected: true, reason: "quote_pattern", matchedPattern: m[0] };
    }
  }
  if (ngramOverlap(summary, rawAnswers, minLen)) {
    return { detected: true, reason: "ngram_overlap" };
  }
  return { detected: false };
}

/** 분석 객체의 모든 public_safe 필드를 일괄 검사 */
export function detectRawQuoteInAnalysis(
  fields: { where: string; why: string; how: string; tensionText?: string },
  rawAnswers: string,
): RawQuoteCheckResult {
  for (const [key, value] of Object.entries(fields)) {
    if (!value) continue;
    const r = detectRawQuoteInSummary(value, rawAnswers);
    if (r.detected) {
      return {
        ...r,
        matchedPattern: `${key}: ${r.matchedPattern ?? "(ngram)"}`,
      };
    }
  }
  return { detected: false };
}
