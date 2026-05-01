// 결 (Gyeol) — MVP ciphertext scaffold
//
// This is not production KMS encryption. It gives every Edge Function one
// bytea-compatible representation while the MVP flow is being closed.

const encoder = new TextEncoder();
const decoder = new TextDecoder();

export function encodeMvpCiphertext(plaintext: string): string {
  const bytes = encoder.encode(plaintext);
  return `\\x${
    Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("")
  }`;
}

export function decodeMvpCiphertext(value: unknown): string {
  if (typeof value === "string") {
    if (value.startsWith("\\x")) {
      return decoder.decode(hexToBytes(value.slice(2)));
    }
    return value;
  }
  if (value instanceof Uint8Array) {
    return decoder.decode(value);
  }
  if (value instanceof ArrayBuffer) {
    return decoder.decode(new Uint8Array(value));
  }
  if (Array.isArray(value) && value.every((item) => typeof item === "number")) {
    return decoder.decode(new Uint8Array(value));
  }
  return "";
}

function hexToBytes(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) return new Uint8Array();
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    out[i / 2] = Number.parseInt(hex.slice(i, i + 2), 16);
  }
  return out;
}
