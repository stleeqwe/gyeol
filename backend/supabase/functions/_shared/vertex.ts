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

export interface GeminiRequest {
  model: GeminiModel;
  systemPrompt: string;
  userPrompt: string;
  jsonSchema?: object;
  temperature?: number;
  maxOutputTokens?: number;
}

export interface GeminiResponse {
  text: string;
  usage?: { inputTokens: number; outputTokens: number };
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

  const body: Record<string, unknown> = {
    systemInstruction: { parts: [{ text: req.systemPrompt }] },
    contents: [{ role: "user", parts: [{ text: req.userPrompt }] }],
    generationConfig: {
      temperature: req.temperature ?? 0.4,
      maxOutputTokens: req.maxOutputTokens ?? 2048,
    },
  };
  if (req.jsonSchema) {
    (body.generationConfig as Record<string, unknown>).responseMimeType =
      "application/json";
    (body.generationConfig as Record<string, unknown>).responseSchema =
      req.jsonSchema;
  }

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
  const text = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  return {
    text,
    usage: json?.usageMetadata
      ? {
        inputTokens: json.usageMetadata.promptTokenCount ?? 0,
        outputTokens: json.usageMetadata.candidatesTokenCount ?? 0,
      }
      : undefined,
  };
}

export async function callGeminiJson<T>(req: GeminiRequest): Promise<T> {
  const r = await callGemini(req);
  try {
    return JSON.parse(r.text) as T;
  } catch (err) {
    throw new Error(`gemini_json_parse: ${(err as Error).message}\n${r.text}`);
  }
}
