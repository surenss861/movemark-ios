import { createHash, timingSafeEqual } from "node:crypto";

/**
 * Constant-time comparison for webhook bearer tokens.
 * SHA-256 digests are fixed length (32 bytes), so `timingSafeEqual` does not leak token length
 * the way a naive UTF-8 byte compare would when lengths differ.
 */
export function constantTimeTokenEquals(received: string, expected: string): boolean {
  if (!received || !expected) return false;
  const a = createHash("sha256").update(received, "utf8").digest();
  const b = createHash("sha256").update(expected, "utf8").digest();
  return timingSafeEqual(a, b);
}
