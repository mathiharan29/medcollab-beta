/**
 * SEARCH CONTROLLER
 * Global search across messages, doctors, channels, and attachments
 * scoped to spaces / DMs the caller can access.
 */

const Message = require('../messages/message.model');
const Channel = require('../channels/channel.model');
const Space = require('../spaces/space.model');
const User = require('../users/user.model');
const Handoff = require('../handoffs/handoff.model');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const escapeRegex = require('../../utils/escapeRegex');
const { CHANNEL_TYPES, MESSAGE_TYPES } = require('../../constants');

/**
 * Resolve channel IDs the user can access (space channels + DMs).
 */
async function accessibleChannelIds(userId) {
  const spaces = await Space.find(
    { 'members.userId': userId, isActive: true },
    { _id: 1 }
  ).lean();
  const spaceIds = spaces.map((s) => s._id);

  const channels = await Channel.find({
    isArchived: false,
    $or: [
      {
        spaceId: { $in: spaceIds },
        $or: [{ isPrivate: false }, { members: userId }],
      },
      { type: CHANNEL_TYPES.DIRECT, members: userId },
    ],
  })
    .select('_id spaceId name type')
    .lean();

  return channels;
}

/**
 * GET /api/search?q=...&type=all|messages|doctors|channels|attachments|handoffs
 */
const globalSearch = asyncHandler(async (req, res) => {
  const q = (req.query.q || '').trim();
  if (q.length < 2) {
    return respond.badRequest(res, 'Search query must be at least 2 characters');
  }

  const type = (req.query.type || 'all').toLowerCase();
  const limit = Math.min(parseInt(req.query.limit, 10) || 20, 50);
  const regex = new RegExp(escapeRegex(q), 'i');
  const userId = req.user._id;

  const channels = await accessibleChannelIds(userId);
  const channelIds = channels.map((c) => c._id);
  const channelById = Object.fromEntries(
    channels.map((c) => [c._id.toString(), c])
  );

  const spaceIds = [
    ...new Set(channels.map((c) => c.spaceId).filter(Boolean).map(String)),
  ];

  const result = {
    messages: [],
    doctors: [],
    channels: [],
    attachments: [],
    handoffs: [],
  };

  const wantMessages = type === 'all' || type === 'messages';
  const wantAttachments = type === 'all' || type === 'attachments';
  const wantDoctors = type === 'all' || type === 'doctors';
  const wantChannels = type === 'all' || type === 'channels';
  const wantHandoffs = type === 'all' || type === 'handoffs';

  if ((wantMessages || wantAttachments) && channelIds.length > 0) {
    if (wantMessages) {
      const messages = await Message.find({
        channelId: { $in: channelIds },
        deletedAt: null,
        'content.text': regex,
      })
        .populate('senderId', 'name displayTitle role avatarUrl')
        .sort({ createdAt: -1 })
        .limit(limit)
        .lean();

      result.messages = messages.map((m) => {
        const ch = channelById[m.channelId.toString()];
        return {
          _id: m._id,
          channelId: m.channelId,
          spaceId: m.spaceId || ch?.spaceId || null,
          text: m.content?.text || '',
          createdAt: m.createdAt,
          sender: m.senderId,
          channelName: ch?.name || null,
          channelType: ch?.type || null,
        };
      });
    }

    if (wantAttachments) {
      const attachments = await Message.find({
        channelId: { $in: channelIds },
        deletedAt: null,
        type: {
          $in: [MESSAGE_TYPES.IMAGE, MESSAGE_TYPES.DOCUMENT, MESSAGE_TYPES.ECG],
        },
        $or: [
          { 'content.fileName': regex },
          { 'content.text': regex },
        ],
      })
        .populate('senderId', 'name displayTitle role avatarUrl')
        .sort({ createdAt: -1 })
        .limit(limit)
        .lean();

      result.attachments = attachments.map((m) => {
        const ch = channelById[m.channelId.toString()];
        return {
          _id: m._id,
          channelId: m.channelId,
          spaceId: m.spaceId || ch?.spaceId || null,
          type: m.type,
          fileName: m.content?.fileName || null,
          mediaUrl: m.content?.mediaUrl || null,
          text: m.content?.text || '',
          createdAt: m.createdAt,
          sender: m.senderId,
          channelName: ch?.name || null,
        };
      });
    }
  }

  if (wantDoctors) {
    const { resolveKnownUserIds } = require('../../utils/knownUsers');
    const knownIds = await resolveKnownUserIds(userId);
    const digitQuery = q.trim().replace(/\D/g, '');
    const orClauses = [
      { name: regex },
      { speciality: regex },
      { displayTitle: regex },
    ];
    if (digitQuery.length >= 4) {
      const phoneRe = new RegExp(escapeRegex(digitQuery));
      orClauses.push({ phone: phoneRe });
    }

    let doctors =
      knownIds.length === 0
        ? []
        : await User.find({
            _id: { $in: knownIds },
            isActive: true,
            isOnboarded: true,
            $or: orClauses,
          })
            .select(
              'name displayTitle role speciality institution avatarUrl availability'
            )
            .limit(limit)
            .lean();

    // Full mobile: also surface onboarded strangers (message-request flow).
    if (digitQuery.length >= 10) {
      const last10 = digitQuery.slice(-10);
      const phoneVariants = [
        ...new Set([
          `+91${last10}`,
          `91${last10}`,
          last10,
          digitQuery.startsWith('+') ? digitQuery : `+${digitQuery}`,
        ]),
      ];
      const byPhone = await User.findOne({
        phone: { $in: phoneVariants },
        isActive: true,
        isOnboarded: true,
      })
        .select(
          'name displayTitle role speciality institution avatarUrl availability'
        )
        .lean();
      if (byPhone) {
        const id = byPhone._id.toString();
        if (!doctors.some((d) => d._id.toString() === id)) {
          doctors = [byPhone, ...doctors].slice(0, limit);
        }
      }
    }

    result.doctors = doctors;
  }

  if (wantChannels) {
    const spaceNameById = {};
    if (spaceIds.length > 0) {
      const spaces = await Space.find({ _id: { $in: spaceIds } })
        .select('name')
        .lean();
      for (const space of spaces) {
        spaceNameById[space._id.toString()] = space.name;
      }
    }

    result.channels = channels
      .filter((c) => {
        if (c.type === CHANNEL_TYPES.DIRECT) return false;
        return c.name && regex.test(c.name);
      })
      .slice(0, limit)
      .map((c) => ({
        _id: c._id,
        name: c.name,
        type: c.type,
        spaceId: c.spaceId || null,
        spaceName: c.spaceId
          ? spaceNameById[c.spaceId.toString()] || null
          : null,
      }));
  }

  if (wantHandoffs) {
    // Prefer membership spaces (not only channels that already exist).
    const memberSpaces = await Space.find(
      { 'members.userId': userId, isActive: true },
      { _id: 1, name: 1 }
    ).lean();
    const handoffSpaceIds = memberSpaces.map((s) => s._id);
    const spaceNameById = Object.fromEntries(
      memberSpaces.map((s) => [s._id.toString(), s.name])
    );

    if (handoffSpaceIds.length > 0) {
      const handoffs = await Handoff.find({
        spaceId: { $in: handoffSpaceIds },
        $or: [
          { shiftSummary: regex },
          { 'patients.clinicalAlias': regex },
          { 'patients.diagnosis': regex },
          { 'patients.notes': regex },
          { 'patients.bedNumber': regex },
          { 'patients.ward': regex },
        ],
      })
        .populate('fromUserId', 'name displayTitle role avatarUrl')
        .populate('toUserId', 'name displayTitle role avatarUrl')
        .sort({ updatedAt: -1 })
        .limit(limit)
        .lean();

      result.handoffs = handoffs.map((h) => {
        const matchedPatient = (h.patients || []).find(
          (p) =>
            regex.test(p.clinicalAlias || '') ||
            regex.test(p.diagnosis || '') ||
            regex.test(p.notes || '') ||
            regex.test(p.bedNumber || '') ||
            regex.test(p.ward || '')
        );
        const title = matchedPatient
          ? [
              matchedPatient.ward,
              matchedPatient.bedNumber
                ? `Bed ${matchedPatient.bedNumber}`
                : null,
              matchedPatient.clinicalAlias,
            ]
              .filter(Boolean)
              .join(' · ')
          : h.shiftSummary || 'Handoff';

        return {
          _id: h._id,
          spaceId: h.spaceId,
          channelId: h.channelId,
          status: h.status,
          title,
          shiftSummary: h.shiftSummary || '',
          spaceName: spaceNameById[h.spaceId?.toString()] || null,
          fromUser: h.fromUserId,
          toUser: h.toUserId,
          shiftDate: h.shiftDate,
          updatedAt: h.updatedAt,
        };
      });
    }
  }

  return respond.ok(res, 'Search results', { query: q, ...result });
});

module.exports = { globalSearch };
