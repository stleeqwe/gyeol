// 결 (Gyeol) — 구조화 로거 (Edge Functions 공통)
//
// 정책 (PIPA 23조 정합):
// - 절대 금지: raw 답변, summary 텍스트, raw_user_text, polished narrative, evidence quote, LLM input/output text
// - 허용: ID(user_id, match_id, analysis_id), version, count, duration_ms, status, qualitative_label, alignment_level, principle_id, target_id
// - LLM 호출 통계: model, prompt_version, input_tokens, output_tokens, latency_ms (텍스트는 X)
//
// Supabase Edge Runtime은 console.log 출력을 자동 수집 → JSON 한 줄로 출력하면 supabase logs 검색 가능.

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogContext {
  fn: string; // function name (e.g., "matching-algorithm")
  request_id?: string; // 요청 단위 correlation id
  user_id?: string; // 사용자 trace (PII로 간주, 운영 모니터링 외 사용 금지)
  match_id?: string;
  domain_id?: string;
}

export interface LogFields {
  [key: string]: unknown;
}

const LEVEL_RANK: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

function currentLevel(): LogLevel {
  const env = (Deno.env.get("LOG_LEVEL") ?? "info").toLowerCase();
  if (["debug", "info", "warn", "error"].includes(env)) return env as LogLevel;
  return "info";
}

function emit(
  level: LogLevel,
  msg: string,
  ctx: LogContext,
  fields?: LogFields,
): void {
  if (LEVEL_RANK[level] < LEVEL_RANK[currentLevel()]) return;
  const entry = {
    ts: new Date().toISOString(),
    level,
    msg,
    ...ctx,
    ...(fields ?? {}),
  };
  // Supabase는 console.log를 INFO/DEBUG 로그로, console.error를 ERROR 로그로 분류 → level별 분기.
  if (level === "error") {
    console.error(JSON.stringify(entry));
  } else if (level === "warn") {
    console.warn(JSON.stringify(entry));
  } else {
    console.log(JSON.stringify(entry));
  }
}

export class Logger {
  private ctx: LogContext;

  constructor(ctx: LogContext) {
    this.ctx = ctx;
  }

  with(extra: Partial<LogContext>): Logger {
    return new Logger({ ...this.ctx, ...extra });
  }

  debug(msg: string, fields?: LogFields): void {
    emit("debug", msg, this.ctx, fields);
  }
  info(msg: string, fields?: LogFields): void {
    emit("info", msg, this.ctx, fields);
  }
  warn(msg: string, fields?: LogFields): void {
    emit("warn", msg, this.ctx, fields);
  }
  error(msg: string, fields?: LogFields): void {
    emit("error", msg, this.ctx, fields);
  }

  /** boundary 진입 + 종료 stopwatch — duration_ms 자동 측정 */
  async trace<T>(
    action: string,
    fn: () => Promise<T>,
    fields?: LogFields,
  ): Promise<T> {
    const start = performance.now();
    this.info(`${action}.start`, fields);
    try {
      const result = await fn();
      const duration_ms = Math.round(performance.now() - start);
      this.info(`${action}.ok`, { ...fields, duration_ms });
      return result;
    } catch (err) {
      const duration_ms = Math.round(performance.now() - start);
      this.error(`${action}.fail`, {
        ...fields,
        duration_ms,
        error_class: (err as Error).constructor?.name ?? "Error",
        error_message: (err as Error).message,
      });
      throw err;
    }
  }
}

/** request 단위 correlation id 생성 (UUIDv4 단축) */
export function newRequestId(): string {
  return crypto.randomUUID().replace(/-/g, "").slice(0, 12);
}

export function loggerFor(fn: string, ctx?: Partial<LogContext>): Logger {
  return new Logger({ fn, request_id: newRequestId(), ...ctx });
}
