/**
 * VOICE BOT — server half (beta 11-14, issue 14).
 *
 * Architecture (human-in-the-loop, propose-only):
 *   phone: on-device speech → built-in command parser → (only if it can't
 *   understand) POST /api/assistant/interpret → Claude turns the sentence
 *   into PROPOSED actions → the phone shows a confirm card → the doctor
 *   taps Send / Hand off → the phone calls the normal, permission-checked
 *   APIs. This endpoint never sends, hands off or changes anything.
 *
 * Privacy:
 *   - Claude only sees the sentence and a directory of the caller's OWN
 *     colleagues/chats (names, @username, speciality) — no phone numbers,
 *     no message history.
 *   - Every id Claude returns is checked against that directory; anything
 *     else is dropped (no reaching people outside the doctor's circle).
 *   - Request text is never logged or stored.
 *   - Disabled unless ANTHROPIC_API_KEY is configured.
 */
const Anthropic = require('@anthropic-ai/sdk');
const Channel = require('../channels/channel.model');
const Space = require('../spaces/space.model');
const User = require('../users/user.model');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../utils/logger');

const MODEL = process.env.ASSISTANT_MODEL || 'claude-opus-5-5';
const MAX_PEOPLE = 200;
const MAX_CHATS = 120;

let client = null;
const enabled = () => Boolean(process.env.ANTHROPIC_API_KEY);
const getClient = () => {
  if (!client) client = new Anthropic({ timeout: 20_000, maxRetries: 1 });
  return client;
};

// ── Tools Claude may PROPOSE (strict schemas; the phone executes) ─────────
const ID = { type: 'string', description: 'An id copied exactly from the directory' };
const TOOLS = [
  {
    name: 'send_message',
    description: 'Propose sending a text message to one person or one existing chat from the directory.',
    strict: true,
    input_schema: {
      type: 'object',
      properties: {
        to: ID,
        text: { type: 'string', description: 'The message, as the doctor said it (lightly cleaned up, no new clinical content)' },
      },
      required: ['to', 'text'],
      additionalProperties: false,
    },
  },
  {
    name: 'open_chat',
    description: 'Propose opening a chat with a person or an existing chat from the directory.',
    strict: true,
    input_schema: {
      type: 'object',
      properties: { to: ID },
      required: ['to'],
      additionalProperties: false,
    },
  },
  {
    name: 'create_handoff',
    description: 'Propose a draft shift handoff to one person (the doctor reviews and sends it).',
    strict: true,
    input_schema: {
      type: 'object',
      properties: {
        to: ID,
        shift: { type: 'string', enum: ['morning', 'evening', 'night'] },
        summary: { type: 'string' },
        patients: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              bed: { type: 'string' },
              alias: { type: 'string', description: 'Short clinical alias, never a patient name' },
              notes: { type: 'string' },
              tasks: { type: 'array', items: { type: 'string' } },
            },
            required: ['bed', 'alias', 'notes', 'tasks'],
            additionalProperties: false,
          },
        },
      },
      required: ['to', 'shift', 'summary', 'patients'],
      additionalProperties: false,
    },
  },
  {
    name: 'mark_alerts_read',
    description: 'Propose marking all alerts as read.',
    strict: true,
    input_schema: { type: 'object', properties: {}, required: [], additionalProperties: false },
  },
  {
    name: 'set_availability',
    description: "Propose changing the doctor's availability status.",
    strict: true,
    input_schema: {
      type: 'object',
      properties: {
        status: {
          type: 'string',
          enum: ['available', 'on_call', 'in_ot', 'in_icu', 'on_rounds', 'off_duty', 'do_not_disturb'],
        },
      },
      required: ['status'],
      additionalProperties: false,
    },
  },
  {
    name: 'search',
    description: 'Propose a search across messages, people and handoffs.',
    strict: true,
    input_schema: {
      type: 'object',
      properties: { query: { type: 'string' } },
      required: ['query'],
      additionalProperties: false,
    },
  },
  {
    name: 'reply',
    description: 'Answer the doctor directly: a general question (about Vocle, medicine or anything else), small talk, or a follow-up about the conversation so far. Nothing happens in the app.',
    strict: true,
    input_schema: {
      type: 'object',
      properties: {
        text: { type: 'string', description: '1-4 short sentences, plain words, suitable for reading aloud' },
      },
      required: ['text'],
      additionalProperties: false,
    },
  },
  {
    name: 'ask_clarification',
    description: 'Ask the doctor one short question when the request is ambiguous (e.g. two people match) or not something Vocle can do.',
    strict: true,
    input_schema: {
      type: 'object',
      properties: { question: { type: 'string' } },
      required: ['question'],
      additionalProperties: false,
    },
  },
];

// Stable system prompt (cache-friendly: nothing per-request in here).
const SYSTEM = [
  'You are the Vocle voice assistant for doctors in Indian hospitals.',
  'Turn what the doctor said into tool calls that PROPOSE actions in the Vocle app; the doctor confirms each one before anything happens.',
  'Use only ids that appear in the directory you are given. Match spoken names loosely (titles, first names, nicknames, @usernames, speciality hints like "the cardiology Asha").',
  'If more than one person or chat could match, or nobody does, call ask_clarification instead of guessing.',
  'Keep message text faithful to what was said; never add clinical facts, doses or advice.',
  'Patients are identified by bed and a short clinical alias, never by name.',
  'If the doctor asks a question or talks to you rather than asking for an app action, answer with the reply tool: brief, plain, friendly.',
  'For clinical questions give general reference information only (typical ranges, common definitions, guideline-level facts), say when it should be checked against local protocol or a senior, and never invent patient-specific facts.',
  'The earlier turns of this conversation are given to you: use them to resolve "that", "him", "the same", "again", "also" and follow-up questions.',
  'You are told which screen the doctor is on; "this chat" means that chat.',
  'You may call several tools when the doctor asked for several things.',
].join('\n');

const MAX_TURNS = 8;
/** Earlier turns from the phone: [{ role: 'user'|'assistant', text }]. */
function cleanHistory(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((t) => t && (t.role === 'user' || t.role === 'assistant') && typeof t.text === 'string' && t.text.trim())
    .slice(-MAX_TURNS)
    .map((t) => ({ role: t.role, text: t.text.trim().slice(0, 600) }));
}

/** Which screen the doctor is on (route + chat title only). */
function cleanContext(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const screen = typeof raw.screen === 'string' ? raw.screen.slice(0, 40) : null;
  const chat = typeof raw.chat === 'string' ? raw.chat.slice(0, 120) : null;
  const chatId = typeof raw.chatId === 'string' && /^c:[a-f0-9]{24}$/i.test(raw.chatId) ? raw.chatId : null;
  return screen || chat ? { screen, chat, chatId } : null;
}

/** The caller's own circle: people they chat with or share a group with, and their chats. */
async function buildDirectory(userId) {
  const me = String(userId);
  const [dms, spaces] = await Promise.all([
    Channel.find({ type: 'direct', members: userId, isArchived: false })
      .select('_id name members')
      .sort({ 'lastMessage.sentAt': -1 })
      .limit(MAX_CHATS)
      .lean(),
    Space.find({ 'members.userId': userId, isActive: true }).select('_id name members').lean(),
  ]);
  const spaceIds = spaces.map((s) => s._id);
  const channels = await Channel.find({
    spaceId: { $in: spaceIds },
    isArchived: false,
    $or: [{ isPrivate: false }, { members: userId }],
  })
    .select('_id name spaceId')
    .lean();

  const peopleIds = new Set();
  for (const dm of dms) for (const m of dm.members || []) peopleIds.add(String(m));
  for (const s of spaces) for (const m of s.members || []) peopleIds.add(String(m.userId));
  peopleIds.delete(me);
  const users = await User.find({ _id: { $in: [...peopleIds].slice(0, MAX_PEOPLE * 2) }, isActive: { $ne: false } })
    .select('_id name displayTitle vocleUsername speciality role')
    .lean();
  const people = users.slice(0, MAX_PEOPLE).map((u) => ({
    id: `p:${u._id}`,
    name: [u.displayTitle, u.name].filter(Boolean).join(' ').trim() || 'Doctor',
    username: u.vocleUsername || null,
    speciality: u.speciality || null,
  }));
  const nameOf = new Map(users.map((u) => [String(u._id), u.name || 'Doctor']));
  const spaceName = new Map(spaces.map((s) => [String(s._id), s.name]));
  const chats = [
    ...dms
      .filter((d) => (d.members || []).length > 2)
      .map((d) => ({
        id: `c:${d._id}`,
        name: d.name || (d.members || []).filter((m) => String(m) !== me).map((m) => nameOf.get(String(m)) || '').join(', '),
        kind: 'needl',
      })),
    ...channels.map((c) => ({
      id: `c:${c._id}`,
      name: `${spaceName.get(String(c.spaceId)) || 'Group'} #${c.name}`,
      kind: 'group',
      spaceId: String(c.spaceId),
    })),
  ].slice(0, MAX_CHATS);
  return { people, chats };
}

/** Keep only actions whose ids exist in the directory; attach display names. */
function validateActions(blocks, directory) {
  const people = new Map(directory.people.map((p) => [p.id, p]));
  const chats = new Map(directory.chats.map((c) => [c.id, c]));
  const target = (id) => people.get(id) || chats.get(id) || null;
  const actions = [];
  for (const b of blocks) {
    if (b.type !== 'tool_use') continue;
    const input = b.input || {};
    switch (b.name) {
      case 'send_message':
      case 'open_chat': {
        const t = target(input.to);
        if (!t) continue;
        if (b.name === 'send_message' && !String(input.text || '').trim()) continue;
        actions.push({
          type: b.name,
          to: { id: input.to, name: t.name, kind: t.kind || 'person', spaceId: t.spaceId || null },
          ...(b.name === 'send_message' ? { text: String(input.text).trim().slice(0, 4000) } : {}),
        });
        break;
      }
      case 'create_handoff': {
        const p = people.get(input.to);
        if (!p) continue;
        actions.push({
          type: 'create_handoff',
          to: { id: input.to, name: p.name, kind: 'person' },
          shift: input.shift,
          summary: String(input.summary || '').slice(0, 2000),
          patients: (input.patients || []).slice(0, 20).map((x) => ({
            bed: String(x.bed || '').slice(0, 20),
            alias: String(x.alias || '').slice(0, 100),
            notes: String(x.notes || '').slice(0, 2000),
            tasks: (x.tasks || []).slice(0, 20).map((t) => String(t).slice(0, 200)),
          })),
        });
        break;
      }
      case 'mark_alerts_read':
        actions.push({ type: 'mark_alerts_read' });
        break;
      case 'set_availability':
        actions.push({ type: 'set_availability', status: input.status });
        break;
      case 'search':
        if (String(input.query || '').trim()) {
          actions.push({ type: 'search', query: String(input.query).trim().slice(0, 200) });
        }
        break;
      case 'ask_clarification':
        actions.push({ type: 'ask_clarification', question: String(input.question || '').slice(0, 300) });
        break;
      case 'reply':
        if (String(input.text || '').trim()) {
          actions.push({ type: 'reply', text: String(input.text).trim().slice(0, 1200) });
        }
        break;
      default:
        break;
    }
  }
  return actions;
}

// Small per-user rate limit (voice requests are human-paced).
const recent = new Map();
const LIMIT_PER_MIN = 20;
function allow(userId) {
  const now = Date.now();
  const key = String(userId);
  const list = (recent.get(key) || []).filter((t) => now - t < 60_000);
  if (list.length >= LIMIT_PER_MIN) {
    recent.set(key, list);
    return false;
  }
  list.push(now);
  recent.set(key, list);
  return true;
}

/** GET /api/assistant/capabilities */
const capabilities = asyncHandler(async (req, res) =>
  respond.ok(res, 'Assistant capabilities', { llm: enabled(), model: enabled() ? MODEL : null })
);

/** POST /api/assistant/interpret { text } */
const interpret = asyncHandler(async (req, res) => {
  const text = String(req.body?.text || '').trim();
  if (!text) return respond.badRequest(res, 'Say what you want Vocle to do');
  if (text.length > 1000) return respond.badRequest(res, 'Please keep the request under 1000 characters');
  if (!enabled()) {
    return respond.ok(res, 'Assistant AI is not configured', { llm: false, actions: [] });
  }
  if (!allow(req.user._id)) return respond.tooManyRequests(res, 'Too many voice requests — try again in a minute');

  const directory = await buildDirectory(req.user._id);
  const history = cleanHistory(req.body?.history);
  const context = cleanContext(req.body?.context);
  const userContent = [
    'Directory (JSON):',
    JSON.stringify({ people: directory.people, chats: directory.chats }),
    '',
    ...(context ? [`Current screen: ${JSON.stringify(context)}`, ''] : []),
    ...(history.length
      ? ['Conversation so far:', ...history.map((t) => `${t.role === 'user' ? 'Doctor' : 'Assistant'}: ${t.text}`), '']
      : []),
    `The doctor said: "${text}"`,
  ].join('\n');

  let response;
  try {
    response = await getClient().beta.messages.create({
      model: MODEL,
      max_tokens: 4000,
      // Voice needs a quick answer; this is extraction, not deep reasoning.
      output_config: { effort: 'low' },
      // Server-side refusal fallback: a declined request is re-run on a
      // fallback model instead of failing the doctor's request.
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      system: [{ type: 'text', text: SYSTEM, cache_control: { type: 'ephemeral' } }],
      tools: TOOLS,
      messages: [{ role: 'user', content: userContent }],
    });
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) {
      return respond.tooManyRequests(res, 'Assistant is busy — try again shortly');
    }
    if (err instanceof Anthropic.APIError) {
      logger.warn(`Assistant API error ${err.status}`);
      return res.status(502).json({ success: false, message: 'Assistant is unavailable right now', data: null });
    }
    throw err;
  }

  if (response.stop_reason === 'refusal') {
    return respond.ok(res, 'Assistant declined', {
      llm: true,
      actions: [{ type: 'ask_clarification', question: "Sorry, I can't help with that request." }],
    });
  }
  const actions = validateActions(response.content, directory);
  const say = response.content
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join(' ')
    .trim()
    .slice(0, 500);
  return respond.ok(res, 'Interpreted', {
    llm: true,
    actions: actions.length
      ? actions
      : say
        ? [{ type: 'reply', text: say }]
        : [{ type: 'ask_clarification', question: 'Sorry, I did not get that. Could you say it again?' }],
  });
});

module.exports = { capabilities, interpret, _test: { validateActions, buildDirectory, cleanHistory, cleanContext, TOOLS } };
