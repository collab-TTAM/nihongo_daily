export const MAX_QUIZ_REPORT_BYTES = 16_384;

interface StrictJsonOptions {
  integerNumbersOnly?: boolean;
  maxDepth?: number;
  maxTokens?: number;
}

const invalidJson = (): Error => new Error("Invalid JSON body");
const invalidQuizBody = (): Error => new Error("Invalid quiz request body");

function isDigit(value: string | undefined): boolean {
  return value !== undefined && value >= "0" && value <= "9";
}

export function parseStrictJson(
  text: string,
  options: StrictJsonOptions = {},
): unknown {
  const maxDepth = options.maxDepth ?? 64;
  const maxTokens = options.maxTokens ?? 32_768;
  if (
    typeof text !== "string" ||
    !Number.isSafeInteger(maxDepth) ||
    maxDepth < 1 ||
    maxDepth > 256 ||
    !Number.isSafeInteger(maxTokens) ||
    maxTokens < 1 ||
    maxTokens > 1_000_000
  ) {
    throw invalidJson();
  }

  let index = 0;
  let tokens = 0;

  const skipWhitespace = (): void => {
    while ([0x20, 0x09, 0x0a, 0x0d].includes(text.charCodeAt(index))) {
      index++;
    }
  };

  const scanString = (): string => {
    const start = index;
    if (text.charCodeAt(index) !== 0x22) throw invalidJson();
    index++;
    while (index < text.length) {
      const code = text.charCodeAt(index);
      if (code === 0x22) {
        index++;
        return text.slice(start, index);
      }
      if (code === 0x5c) {
        index++;
        const escaped = text.charCodeAt(index);
        if (escaped === 0x75) {
          index++;
          for (let digit = 0; digit < 4; digit++) {
            const hex = text[index];
            if (hex === undefined || !/[0-9a-fA-F]/.test(hex)) {
              throw invalidJson();
            }
            index++;
          }
        } else {
          if (![0x22, 0x5c, 0x2f, 0x62, 0x66, 0x6e, 0x72, 0x74].includes(escaped)) {
            throw invalidJson();
          }
          index++;
        }
        continue;
      }
      if (code < 0x20) throw invalidJson();
      index++;
    }
    throw invalidJson();
  };

  const scanNumber = (): void => {
    const start = index;
    if (text[index] === "-") index++;
    if (text[index] === "0") {
      index++;
      if (isDigit(text[index])) throw invalidJson();
    } else {
      const first = text[index];
      if (first === undefined || first < "1" || first > "9") {
        throw invalidJson();
      }
      while (isDigit(text[index])) index++;
    }

    let hasFraction = false;
    let hasExponent = false;
    if (text[index] === ".") {
      hasFraction = true;
      index++;
      if (!isDigit(text[index])) throw invalidJson();
      while (isDigit(text[index])) index++;
    }
    if (text[index] === "e" || text[index] === "E") {
      hasExponent = true;
      index++;
      if (text[index] === "+" || text[index] === "-") index++;
      if (!isDigit(text[index])) throw invalidJson();
      while (isDigit(text[index])) index++;
    }

    const value = Number(text.slice(start, index));
    if (!Number.isFinite(value)) throw invalidJson();
    if (
      options.integerNumbersOnly &&
      (hasFraction || hasExponent || !Number.isSafeInteger(value))
    ) {
      throw invalidJson();
    }
  };

  const scanLiteral = (literal: "true" | "false" | "null"): void => {
    if (!text.startsWith(literal, index)) throw invalidJson();
    index += literal.length;
  };

  const scanValue = (depth: number): void => {
    if (depth > maxDepth || ++tokens > maxTokens) throw invalidJson();
    skipWhitespace();
    const character = text[index];
    if (character === '"') {
      scanString();
    } else if (character === "{") {
      index++;
      skipWhitespace();
      if (text[index] === "}") {
        index++;
        return;
      }
      const keys = new Set<string>();
      while (true) {
        const keyToken = scanString();
        const key = JSON.parse(keyToken) as unknown;
        if (typeof key !== "string" || keys.has(key)) throw invalidJson();
        keys.add(key);
        skipWhitespace();
        if (text[index] !== ":") throw invalidJson();
        index++;
        scanValue(depth + 1);
        skipWhitespace();
        if (text[index] === "}") {
          index++;
          return;
        }
        if (text[index] !== ",") throw invalidJson();
        index++;
        skipWhitespace();
      }
    } else if (character === "[") {
      index++;
      skipWhitespace();
      if (text[index] === "]") {
        index++;
        return;
      }
      while (true) {
        scanValue(depth + 1);
        skipWhitespace();
        if (text[index] === "]") {
          index++;
          return;
        }
        if (text[index] !== ",") throw invalidJson();
        index++;
        skipWhitespace();
      }
    } else if (character === "t") {
      scanLiteral("true");
    } else if (character === "f") {
      scanLiteral("false");
    } else if (character === "n") {
      scanLiteral("null");
    } else if (character === "-" || isDigit(character)) {
      scanNumber();
    } else {
      throw invalidJson();
    }
  };

  try {
    scanValue(0);
    skipWhitespace();
    if (index !== text.length) throw invalidJson();
    return JSON.parse(text) as unknown;
  } catch {
    throw invalidJson();
  }
}

export function parseQuizReportJsonBody(
  raw: Uint8Array,
): Record<string, unknown> {
  if (!(raw instanceof Uint8Array) || raw.byteLength > MAX_QUIZ_REPORT_BYTES) {
    throw invalidQuizBody();
  }
  try {
    const text = new TextDecoder("utf-8", {
      fatal: true,
      ignoreBOM: true,
    }).decode(raw);
    const value = parseStrictJson(text, {
      integerNumbersOnly: true,
      maxDepth: 16,
      maxTokens: 2_048,
    });
    if (typeof value !== "object" || value === null || Array.isArray(value)) {
      throw invalidQuizBody();
    }
    return value as Record<string, unknown>;
  } catch {
    throw invalidQuizBody();
  }
}
