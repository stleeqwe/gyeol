// 결 (Gyeol) — Gemini API 호출 (Google AI Studio 직접)
// 환경변수: GEMINI_API_KEY 한 줄.
//
// 운영 단계에 PIPA 한국 거주가 hard requirement가 되면 Vertex AI Seoul로 교체.
// 본 모듈명은 vertex.ts 그대로 유지 (import 경로 호환).

const API_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

export type GeminiModel = "gemini-3-flash" | "gemini-3.1-flash-lite";

// AI Studio에서 사용 가능한 모델 ID로 매핑.
// 운영 단계에 모델이 GA되면 본 표만 갱신.
const MODEL_ID_MAP: Record<GeminiModel, string> = {
  "gemini-3-flash": Deno.env.get("GEMINI_FLASH_MODEL") ?? "gemini-2.5-flash",
  "gemini-3.1-flash-lite": Deno.env.get("GEMINI_LITE_MODEL") ??
    "gemini-2.5-flash-lite",
};

/**
 * Gemini 3 thinking_level. See ADR-016 (LLM Call Parameter Policy — Quality First)
 * and RUNBOOK §1.2. All 5 LLM functions explicitly set this; defaults are not relied
 * upon (Gemini 3 Flash defaults to "high (dynamic)", 3.1 Flash-Lite to "minimal").
 * Legacy `thinkingBudget` is forbidden on Gemini 3 (unexpected behavior per Google docs).
 */
export type ThinkingLevel = "minimal" | "low" | "medium" | "high";

export interface GeminiRequest {
  model: GeminiModel;
  systemPrompt: string;
  userPrompt: string;
  jsonSchema?: object;
  temperature?: number;
  maxOutputTokens?: number;
  thinkingLevel?: ThinkingLevel;
}

export interface GeminiUsage {
  inputTokens: number;
  outputTokens: number;
  thinkingTokens: number;
}

export interface GeminiResponse {
  text: string;
  usage?: GeminiUsage;
  /**
   * Gemini 3 thought summary. Populated only when LLM_TRACE_MODE=full
   * triggers `thinkingConfig.includeThoughts: true`. Stored to
   * `public.llm_call_traces.thinking_summary` per ADR-017.
   */
  thinkingSummary?: string;
}

export interface GeminiJsonResult<T> {
  data: T;
  usage?: GeminiUsage;
  thinkingSummary?: string;
}

function getApiKey(): string {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("GEMINI_API_KEY missing");
  return key;
}

export async function callGemini(req: GeminiRequest): Promise<GeminiResponse> {
  const key = getApiKey();
  const modelId = MODEL_ID_MAP[req.model];
  const url = `${API_BASE}/${modelId}:generateContent?key=${
    encodeURIComponent(key)
  }`;

  // Per ADR-017: include thought summaries in the response when trace mode is on.
  // No effect on production (default LLM_TRACE_MODE=none).
  const includeThoughts = Deno.env.get("LLM_TRACE_MODE") === "full";
  const generationConfig: Record<string, unknown> = {
    temperature: req.temperature ?? 0.4,
    maxOutputTokens: req.maxOutputTokens ?? 2048,
  };
  if (req.thinkingLevel) {
    const thinkingConfig: Record<string, unknown> = {
      thinkingLevel: req.thinkingLevel,
    };
    if (includeThoughts) thinkingConfig.includeThoughts = true;
    generationConfig.thinkingConfig = thinkingConfig;
  }
  if (req.jsonSchema) {
    generationConfig.responseMimeType = "application/json";
    generationConfig.responseSchema = req.jsonSchema;
  }
  const body: Record<string, unknown> = {
    systemInstruction: { parts: [{ text: req.systemPrompt }] },
    contents: [{ role: "user", parts: [{ text: req.userPrompt }] }],
    generationConfig,
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`gemini_${resp.status}: ${text}`);
  }
  const json = await resp.json();
  // When includeThoughts=true, parts[] interleaves thought summaries (thought:true)
  // and the actual response (thought:false/absent). Split them.
  const parts: Array<{ text?: string; thought?: boolean }> =
    json?.candidates?.[0]?.content?.parts ?? [];
  const responseChunks: string[] = [];
  const thoughtChunks: string[] = [];
  for (const p of parts) {
    if (p?.thought === true) thoughtChunks.push(p.text ?? "");
    else responseChunks.push(p?.text ?? "");
  }
  const text = responseChunks.join("");
  const thinkingSummary = thoughtChunks.length > 0
    ? thoughtChunks.join("\n")
    : undefined;
  return {
    text,
    thinkingSummary,
    usage: json?.usageMetadata
      ? {
        inputTokens: json.usageMetadata.promptTokenCount ?? 0,
        outputTokens: json.usageMetadata.candidatesTokenCount ?? 0,
        thinkingTokens: json.usageMetadata.thoughtsTokenCount ?? 0,
      }
      : undefined,
  };
}

export async function callGeminiJson<T>(
  req: GeminiRequest,
): Promise<GeminiJsonResult<T>> {
  const r = await callGemini(req);
  try {
    return {
      data: JSON.parse(r.text) as T,
      usage: r.usage,
      thinkingSummary: r.thinkingSummary,
    };
  } catch (err) {
    throw new Error(`gemini_json_parse: ${(err as Error).message}\n${r.text}`);
  }
}
