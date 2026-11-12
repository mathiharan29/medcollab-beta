import { createHash } from 'node:crypto';
import { performance } from 'node:perf_hooks';

export class HarnessError extends Error {
  constructor(code) { super(code); this.name = 'HarnessError'; this.code = code; }
}
export function requireContract(condition, code) {
  if (!condition) throw new HarnessError(code);
}
export function copyJson(value, depth = 0) {
  requireContract(depth <= 32, 'JSON_DEPTH_LIMIT');
  if (value === null || typeof value === 'boolean' || typeof value === 'string') return value;
  if (typeof value === 'number') {
    requireContract(Number.isFinite(value), 'NONFINITE_VALUE');
    return value;
  }
  requireContract(typeof value === 'object', 'NON_JSON_VALUE');
  requireContract(Array.isArray(value) || Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null, 'NON_PLAIN_OBJECT');
  if (Array.isArray(value)) requireContract(Object.keys(value).length === value.length, 'SPARSE_JSON_ARRAY');
  const result = Array.isArray(value) ? [] : Object.create(null);
  for (const key of Object.keys(value).sort()) {
    requireContract(!['__proto__', 'constructor', 'prototype'].includes(key), 'UNSAFE_JSON_KEY');
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    requireContract(descriptor && 'value' in descriptor, 'JSON_ACCESSOR');
    result[key] = copyJson(descriptor.value, depth + 1);
  }
  return result;
}
export function deepFreeze(value) {
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    Object.values(value).forEach(deepFreeze);
    Object.freeze(value);
  }
  return value;
}
export const immutable = (value) => deepFreeze(copyJson(value));
export const canonical = (value) => JSON.stringify(copyJson(value));
export const digest = (value) => createHash('sha256').update(canonical(value)).digest('hex');
export const identifier = (value) => typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/.test(value);
export const finiteInteger = (value, min = 0, max = Number.MAX_SAFE_INTEGER) => Number.isSafeInteger(value) && value >= min && value <= max;
export const sameSet = (a, b) => Array.isArray(a) && Array.isArray(b) && new Set(a).size === a.length && new Set(b).size === b.length && a.length === b.length && a.every((item) => b.includes(item));
export function createClock(clockDomainId) {
  requireContract(identifier(clockDomainId), 'CLOCK_DOMAIN_REQUIRED');
  return Object.freeze({ clockDomainId, timeOrigin: performance.timeOrigin, monotonicTime: () => performance.now(), wallTime: () => Date.now() });
}

// Closed JSON Schema vocabulary used by this package. No remote refs or coercion.
export function assertSchema(value, schema, root = schema) {
  if (schema.$ref) {
    requireContract(schema.$ref.startsWith('#/'), 'EXTERNAL_SCHEMA_REF');
    const resolved = schema.$ref.slice(2).split('/').reduce((node, key) => node?.[key], root);
    requireContract(resolved, 'UNKNOWN_SCHEMA_REF');
    return assertSchema(value, resolved, root);
  }
  if (schema.anyOf) {
    requireContract(schema.anyOf.some((branch) => {
      try { assertSchema(value, branch, root); return true; } catch (error) {
        if (!(error instanceof HarnessError)) throw error;
        return false;
      }
    }), 'SCHEMA_ANY_OF');
  }
  if ('const' in schema) requireContract(canonical(value) === canonical(schema.const), 'SCHEMA_CONST');
  if (schema.enum) requireContract(schema.enum.some((item) => canonical(item) === canonical(value)), 'SCHEMA_ENUM');
  if (schema.type) {
    const type = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;
    requireContract(schema.type === 'integer' ? finiteInteger(value, Number.MIN_SAFE_INTEGER) : type === schema.type, 'SCHEMA_TYPE');
  }
  if (typeof value === 'number') {
    requireContract(Number.isFinite(value) && (schema.minimum === undefined || value >= schema.minimum) && (schema.maximum === undefined || value <= schema.maximum), 'SCHEMA_NUMBER');
  }
  if (typeof value === 'string') {
    requireContract((schema.minLength === undefined || value.length >= schema.minLength) && (schema.maxLength === undefined || value.length <= schema.maxLength) && (!schema.pattern || new RegExp(schema.pattern).test(value)), 'SCHEMA_STRING');
  }
  if (Array.isArray(value)) {
    requireContract((schema.minItems === undefined || value.length >= schema.minItems) && (schema.maxItems === undefined || value.length <= schema.maxItems), 'SCHEMA_ARRAY_SIZE');
    if (schema.uniqueItems) requireContract(new Set(value.map(canonical)).size === value.length, 'SCHEMA_DUPLICATE');
    if (schema.items) value.forEach((item) => assertSchema(item, schema.items, root));
  } else if (value && typeof value === 'object') {
    for (const key of schema.required ?? []) requireContract(Object.hasOwn(value, key), 'SCHEMA_REQUIRED');
    for (const [key, item] of Object.entries(value)) {
      if (schema.properties?.[key]) assertSchema(item, schema.properties[key], root);
      else requireContract(schema.additionalProperties !== false, 'SCHEMA_UNKNOWN_FIELD');
    }
  }
  return value;
}

// Cooperative cancellation: a timeout remains ambiguous if an adapter ignores it.
// Never retry/delete on the assumption that Promise.race stopped remote work.
export async function withDeadline(operation, milliseconds, parentSignal) {
  requireContract(finiteInteger(milliseconds, 1, 86400000), 'INVALID_DEADLINE');
  requireContract(!parentSignal?.aborted, 'ABORTED');
  const controller = new AbortController();
  let timer;
  let cancel;
  const aborted = new Promise((_, reject) => {
    cancel = () => { controller.abort(); reject(new HarnessError('ABORTED')); };
    parentSignal?.addEventListener('abort', cancel, { once: true });
    timer = setTimeout(() => { controller.abort(); reject(new HarnessError('DEADLINE_EXCEEDED')); }, milliseconds);
    if (parentSignal?.aborted) cancel();
  });
  try { return await Promise.race([Promise.resolve().then(() => { requireContract(!controller.signal.aborted, 'ABORTED'); return operation(controller.signal); }), aborted]); }
  finally { clearTimeout(timer); parentSignal?.removeEventListener('abort', cancel); }
}
