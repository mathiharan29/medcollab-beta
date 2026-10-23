/**
 * PLATFORM ADMIN CONTROLLER
 *
 * Internal ops dashboard APIs — not for space admins or the public site.
 * All routes require protect + requirePlatformAdmin (ADMIN_USER_IDS).
 */

const mongoose = require('mongoose');
const User = require('../users/user.model');
const Space = require('../spaces/space.model');
const Message = require('../messages/message.model');
const Handoff = require('../handoffs/handoff.model');
const { SupportTicket } = require('../support/support.controller');
const { HANDOFF_STATUS } = require('../../constants');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { isCloudinaryConfigured } = require('../../config/cloudinary');

const weekAgo = () => {
  const d = new Date();
  d.setDate(d.getDate() - 7);
  return d;
};

const dormantCutoff = () => {
  const d = new Date();
  d.setDate(d.getDate() - 14);
  return d;
};

/**
 * GET /api/admin/overview
 */
const getOverview = asyncHandler(async (req, res) => {
  const since = weekAgo();
  const dormant = dormantCutoff();

  const [
    totalUsers,
    activeUsers,
    newUsersThisWeek,
    deactivatedUsers,
    dormantUsers,
    pendingVerification,
    verifiedDoctors,
    totalSpaces,
    totalMessages,
    totalHandoffs,
    acknowledgedHandoffs,
    openTickets,
    storageAgg,
  ] = await Promise.all([
    User.countDocuments({}),
    User.countDocuments({ isActive: true, lastSeenAt: { $gte: since } }),
    User.countDocuments({ createdAt: { $gte: since } }),
    User.countDocuments({ isActive: false }),
    User.countDocuments({
      isActive: true,
      $or: [{ lastSeenAt: null }, { lastSeenAt: { $lt: dormant } }],
    }),
    User.countDocuments({ isActive: true, isVerifiedDoctor: false }),
    User.countDocuments({ isVerifiedDoctor: true }),
    Space.countDocuments({ isActive: true }),
    Message.countDocuments({ deletedAt: null }),
    Handoff.countDocuments({ status: { $ne: HANDOFF_STATUS.DRAFT } }),
    Handoff.countDocuments({ status: HANDOFF_STATUS.ACKNOWLEDGED }),
    SupportTicket.countDocuments({ status: { $ne: 'closed' } }).catch(() => 0),
    User.aggregate([
      { $group: { _id: null, bytes: { $sum: '$storageUsedBytes' } } },
    ]),
  ]);

  const storageUsedBytes = storageAgg[0]?.bytes || 0;
  const ackRate =
    totalHandoffs > 0
      ? Math.round((acknowledgedHandoffs / totalHandoffs) * 100)
      : 0;

  return respond.ok(res, 'Admin overview', {
    users: {
      total: totalUsers,
      activeThisWeek: activeUsers,
      newThisWeek: newUsersThisWeek,
      deactivated: deactivatedUsers,
      dormant14d: dormantUsers,
      pendingVerification,
      verifiedDoctors,
    },
    spaces: { total: totalSpaces },
    messages: { total: totalMessages },
    handoffs: {
      total: totalHandoffs,
      acknowledged: acknowledgedHandoffs,
      ackRatePercent: ackRate,
    },
    support: { openTickets },
    infrastructure: {
      storageUsedBytes,
      storageUsedMb: Math.round((storageUsedBytes / (1024 * 1024)) * 100) / 100,
      cloudinaryConfigured: isCloudinaryConfigured(),
      database: mongoose.connection.readyState === 1 ? 'connected' : 'unknown',
      note:
        'Per-user media bytes tracked on upload. Cloudinary/Atlas billable usage still comes from their consoles.',
    },
  });
});

/**
 * GET /api/admin/users
 * Query: q, verified (true|false|pending), active (true|false), limit, page
 */
const listUsers = asyncHandler(async (req, res) => {
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 50));
  const skip = (page - 1) * limit;
  const q = String(req.query.q || '').trim();
  const verified = String(req.query.verified || '').toLowerCase();
  const active = String(req.query.active || '').toLowerCase();

  const filter = {};
  if (q) {
    const safe = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    filter.$or = [
      { name: { $regex: safe, $options: 'i' } },
      { phone: { $regex: safe, $options: 'i' } },
      { institution: { $regex: safe, $options: 'i' } },
    ];
  }
  if (verified === 'true' || verified === 'verified') {
    filter.isVerifiedDoctor = true;
  } else if (
    verified === 'false' ||
    verified === 'pending' ||
    verified === 'unverified'
  ) {
    filter.isVerifiedDoctor = false;
  }
  if (active === 'true') filter.isActive = true;
  if (active === 'false') filter.isActive = false;

  const [users, total] = await Promise.all([
    User.find(filter)
      .select(
        'name phone displayTitle role speciality institution city avatarUrl ' +
          'isVerified isVerifiedDoctor verifiedAt verifiedBy isOnboarded isActive ' +
          'joinedVia storageUsedBytes lastSeenAt createdAt updatedAt'
      )
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    User.countDocuments(filter),
  ]);

  const userIds = users.map((u) => u._id);

  const [messageCounts, handoffCounts] = await Promise.all([
    Message.aggregate([
      { $match: { senderId: { $in: userIds }, deletedAt: null } },
      { $group: { _id: '$senderId', count: { $sum: 1 } } },
    ]),
    Handoff.aggregate([
      {
        $match: {
          fromUserId: { $in: userIds },
          status: { $ne: HANDOFF_STATUS.DRAFT },
        },
      },
      { $group: { _id: '$fromUserId', count: { $sum: 1 } } },
    ]),
  ]);

  const msgMap = Object.fromEntries(
    messageCounts.map((r) => [r._id.toString(), r.count])
  );
  const handoffMap = Object.fromEntries(
    handoffCounts.map((r) => [r._id.toString(), r.count])
  );

  const rows = users.map((u) => {
    const id = u._id.toString();
    return {
      ...u,
      id,
      messageCount: msgMap[id] || 0,
      handoffCount: handoffMap[id] || 0,
      storageUsedMb:
        Math.round(((u.storageUsedBytes || 0) / (1024 * 1024)) * 100) / 100,
    };
  });

  return respond.ok(res, 'Admin users', {
    users: rows,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  });
});

/**
 * GET /api/admin/users/:id
 */
const getUser = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id)
    .select('-fcmTokens -__v')
    .lean();

  if (!user) return respond.notFound(res, 'User not found');

  const [messageCount, handoffCount, spaces] = await Promise.all([
    Message.countDocuments({ senderId: user._id, deletedAt: null }),
    Handoff.countDocuments({
      fromUserId: user._id,
      status: { $ne: HANDOFF_STATUS.DRAFT },
    }),
    Space.find({ 'members.userId': user._id })
      .select('name type inviteCode isActive members')
      .lean(),
  ]);

  const spaceSummaries = (spaces || []).map((s) => {
    const member = (s.members || []).find(
      (m) => m.userId.toString() === user._id.toString()
    );
    return {
      id: s._id,
      name: s.name,
      type: s.type,
      isActive: s.isActive,
      spaceRole: member?.role || null,
      joinedAt: member?.joinedAt || null,
    };
  });

  return respond.ok(res, 'Admin user detail', {
    user: {
      ...user,
      id: user._id.toString(),
      messageCount,
      handoffCount,
      storageUsedMb:
        Math.round(((user.storageUsedBytes || 0) / (1024 * 1024)) * 100) / 100,
      spaces: spaceSummaries,
    },
  });
});

/**
 * PUT /api/admin/users/:id/verify
 * Body: { verified: true|false }
 */
const setDoctorVerification = asyncHandler(async (req, res) => {
  const verified = req.body.verified !== false && req.body.verified !== 'false';
  const user = await User.findById(req.params.id);
  if (!user) return respond.notFound(res, 'User not found');

  user.isVerifiedDoctor = Boolean(verified);
  user.verifiedAt = verified ? new Date() : null;
  user.verifiedBy = verified ? req.user._id : null;
  await user.save();

  return respond.ok(
    res,
    verified ? 'Marked as verified doctor' : 'Verification removed',
    {
      id: user._id.toString(),
      isVerifiedDoctor: user.isVerifiedDoctor,
      verifiedAt: user.verifiedAt,
      verifiedBy: user.verifiedBy,
    }
  );
});

/**
 * PUT /api/admin/users/:id/deactivate
 * Body: { active: false } to deactivate, { active: true } to restore
 */
const setUserActive = asyncHandler(async (req, res) => {
  const active = req.body.active !== false && req.body.active !== 'false';
  const user = await User.findById(req.params.id);
  if (!user) return respond.notFound(res, 'User not found');

  if (user._id.toString() === req.user._id.toString() && !active) {
    return respond.badRequest(res, 'You cannot deactivate your own admin account');
  }

  user.isActive = Boolean(active);
  await user.save();

  return respond.ok(
    res,
    active ? 'User reactivated' : 'User deactivated',
    {
      id: user._id.toString(),
      isActive: user.isActive,
    }
  );
});

/**
 * GET /api/admin/me — confirm portal session is platform-admin
 */
const getAdminMe = asyncHandler(async (req, res) => {
  return respond.ok(res, 'Platform admin session', {
    id: req.user._id.toString(),
    name: req.user.name,
    phone: req.user.phone,
    role: req.user.role,
    isVerifiedDoctor: req.user.isVerifiedDoctor,
  });
});

/**
 * GET /api/admin/growth
 * New users / day for the last N days (default 30)
 */
const getGrowth = asyncHandler(async (req, res) => {
  const days = Math.min(90, Math.max(7, parseInt(req.query.days, 10) || 30));
  const since = new Date();
  since.setHours(0, 0, 0, 0);
  since.setDate(since.getDate() - (days - 1));

  const rows = await User.aggregate([
    { $match: { createdAt: { $gte: since } } },
    {
      $group: {
        _id: {
          $dateToString: { format: '%Y-%m-%d', date: '$createdAt' },
        },
        count: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  const byDay = Object.fromEntries(rows.map((r) => [r._id, r.count]));
  const series = [];
  for (let i = 0; i < days; i += 1) {
    const d = new Date(since);
    d.setDate(since.getDate() + i);
    const key = d.toISOString().slice(0, 10);
    series.push({ date: key, newUsers: byDay[key] || 0 });
  }

  const totalNew = series.reduce((sum, r) => sum + r.newUsers, 0);

  return respond.ok(res, 'Growth series', {
    days,
    totalNew,
    series,
  });
});

/**
 * GET /api/admin/retention
 * Simple D1 / D7 / D30: among users who joined ≥ N days ago, % with lastSeenAt
 * at least N days after createdAt (or still active recently).
 */
const getRetention = asyncHandler(async (req, res) => {
  const now = Date.now();
  const dayMs = 24 * 60 * 60 * 1000;

  const compute = async (n) => {
    const cohortEnd = new Date(now - n * dayMs);
    const cohort = await User.find({
      createdAt: { $lte: cohortEnd },
      isActive: true,
    })
      .select('createdAt lastSeenAt')
      .lean();

    if (cohort.length === 0) {
      return { cohortSize: 0, retained: 0, ratePercent: null };
    }

    let retained = 0;
    for (const u of cohort) {
      if (!u.lastSeenAt) continue;
      const created = new Date(u.createdAt).getTime();
      const seen = new Date(u.lastSeenAt).getTime();
      if (seen - created >= n * dayMs) retained += 1;
    }

    return {
      cohortSize: cohort.length,
      retained,
      ratePercent: Math.round((retained / cohort.length) * 100),
    };
  };

  const [d1, d7, d30] = await Promise.all([
    compute(1),
    compute(7),
    compute(30),
  ]);

  const dormant = dormantCutoff();
  const churnRisk = await User.countDocuments({
    isActive: true,
    isOnboarded: true,
    $or: [{ lastSeenAt: null }, { lastSeenAt: { $lt: dormant } }],
  });

  return respond.ok(res, 'Retention snapshot', {
    d1,
    d7,
    d30,
    churnRisk14d: churnRisk,
    note: 'Retained = lastSeenAt at least N days after signup. Fine for <300 users.',
  });
});

/**
 * GET /api/admin/infrastructure
 * Estimated usage from our DB counters + free-tier headroom hints.
 * Live Cloudinary/Atlas billing still comes from their consoles.
 */
const getInfrastructure = asyncHandler(async (req, res) => {
  const [userCount, messageCount, storageAgg, mediaMessageBytes] =
    await Promise.all([
      User.countDocuments({ isActive: true }),
      Message.countDocuments({ deletedAt: null }),
      User.aggregate([
        { $group: { _id: null, bytes: { $sum: '$storageUsedBytes' } } },
      ]),
      Message.aggregate([
        {
          $match: {
            deletedAt: null,
            'content.fileSize': { $gt: 0 },
          },
        },
        {
          $group: {
            _id: null,
            bytes: { $sum: '$content.fileSize' },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

  const trackedUploadBytes = storageAgg[0]?.bytes || 0;
  const messageMediaBytes = mediaMessageBytes[0]?.bytes || 0;
  const mediaMessageCount = mediaMessageBytes[0]?.count || 0;
  const storageBytes = Math.max(trackedUploadBytes, messageMediaBytes);

  const atlasFreeMb = 512;
  const cloudinaryFreeGb = 25;
  const storageMb = storageBytes / (1024 * 1024);
  const storageGb = storageBytes / (1024 * 1024 * 1024);

  // Rough Hobby framing — not a bill
  const railwayMonthlyUsd = 5;
  const costPerActiveUserInr =
    userCount > 0
      ? Math.round(((railwayMonthlyUsd * 83) / userCount) * 100) / 100
      : null;

  const alerts = [];
  if (storageMb > atlasFreeMb * 0.7) {
    alerts.push({
      level: 'warn',
      source: 'mongodb',
      message: `Tracked media ~${storageMb.toFixed(1)} MB approaching Atlas M0 ${atlasFreeMb} MB disk (docs are separate — check Atlas console).`,
    });
  }
  if (storageGb > cloudinaryFreeGb * 0.7) {
    alerts.push({
      level: 'warn',
      source: 'cloudinary',
      message: `Tracked media ~${storageGb.toFixed(2)} GB approaching Cloudinary free ${cloudinaryFreeGb} GB.`,
    });
  }
  if (userCount >= 400) {
    alerts.push({
      level: 'info',
      source: 'scale',
      message: 'Approaching 500-user scale — enable stricter ADMIN_USER_IDS and billing alerts.',
    });
  }

  return respond.ok(res, 'Infrastructure estimate', {
    usersActive: userCount,
    messages: messageCount,
    mediaMessages: mediaMessageCount,
    storage: {
      trackedUploadBytes,
      messageMediaBytes,
      usedBytes: storageBytes,
      usedMb: Math.round(storageMb * 100) / 100,
      usedGb: Math.round(storageGb * 1000) / 1000,
    },
    headroom: {
      atlasM0DiskMb: atlasFreeMb,
      cloudinaryFreeGb,
      railwayPlan: 'Hobby (~$5/mo flat when used)',
    },
    costEstimate: {
      railwayMonthlyUsd,
      costPerActiveUserInr,
      currencyNote: 'INR estimate uses ~83 INR/USD; media tiers are free until limits.',
    },
    cloudinaryConfigured: isCloudinaryConfigured(),
    database: mongoose.connection.readyState === 1 ? 'connected' : 'unknown',
    dbName: mongoose.connection.name || null,
    alerts,
  });
});

/**
 * GET /api/admin/support
 * In-app bug / feature / feedback tickets, newest first (max 100).
 */
const listSupportTickets = asyncHandler(async (req, res) => {
  const tickets = await SupportTicket.find({})
    .select('type title description status userName userPhone createdAt')
    .sort({ createdAt: -1 })
    .limit(100)
    .lean();

  const rows = tickets.map((t) => ({ ...t, id: t._id.toString() }));

  return respond.ok(res, 'Support tickets', { tickets: rows });
});

module.exports = {
  listSupportTickets,
  getOverview,
  listUsers,
  getUser,
  setDoctorVerification,
  setUserActive,
  getAdminMe,
  getGrowth,
  getRetention,
  getInfrastructure,
};
