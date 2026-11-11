import assert from "node:assert/strict";
import { DecisionPending } from "../src/runner.mjs";
import { runModule } from "../src/module-runner.mjs";
import { connectSocket, waitFor } from "../src/socket.mjs";

const groupPath = "/api/channels/dm/group";
const members = (channel) =>
  new Set(channel.members.map((m) => String(m._id || m)));
async function fixture(c, labels = ["A", "B", "C", "D"]) {
  const people = Object.fromEntries(
    await Promise.all(labels.map(async (l) => [l, await c.identity(l)])),
  );
  const created = await c.request("/api/spaces", {
    method: "POST",
    token: people.A.token,
    body: { name: "Synthetic Needl regression", type: "department" },
    expectedStatus: 201,
  });
  for (const l of labels.filter((l) => l !== "A"))
    await c.request("/api/spaces/join", {
      method: "POST",
      token: people[l].token,
      body: { inviteCode: created.data.space.inviteCode },
    });
  const create = async (ls = ["B", "C"], alias = groupPath) =>
    (
      await c.request(alias, {
        method: "POST",
        token: people.A.token,
        body: { userIds: ls.map((l) => people[l].userId) },
      })
    ).data.channel;
  return {
    people,
    create,
    space: created.data.space,
    general: created.data.channels.find((ch) => ch.name === "general")._id,
  };
}
async function snapshot(c) {
  return c.db(async (db) => ({
    channels: await db.collection("channels").countDocuments(),
    messages: await db.collection("messages").countDocuments(),
  }));
}
async function stored(c, id) {
  return c.db((db) =>
    db.collection("channels").findOne({ _id: new db.base.Types.ObjectId(id) }),
  );
}
async function rows(c, id) {
  return c.db((db) =>
    db
      .collection("messages")
      .find({ channelId: new db.base.Types.ObjectId(id) })
      .sort({ createdAt: 1 })
      .toArray(),
  );
}
async function seed(c, id, person, samples) {
  return c.db(async (db) => {
    const O = db.base.Types.ObjectId;
    const docs = samples.map((s, i) => ({
      _id: new O(),
      channelId: new O(id),
      spaceId: null,
      senderId: new O(person.userId),
      type: "text",
      content: { text: "Synthetic history " + i },
      priority: "normal",
      isDeleted: false,
      createdAt: new Date(Date.parse("2026-11-01T00:00:00Z") + i * 1000),
      updatedAt: new Date(Date.parse("2026-11-01T00:00:00Z") + i * 1000),
      ...s,
    }));
    await db.collection("messages").insertMany(docs);
    return docs;
  });
}
async function expand(c, f, id, userIds = ["D"], history = "none", extra = {}) {
  return c.request(`/api/channels/${id}/expand`, {
    method: "POST",
    token: f.people.A.token,
    body: {
      userIds: userIds.map((l) => f.people[l]?.userId || l),
      ...(history === undefined ? {} : { history }),
      ...extra,
    },
  });
}
async function denied(c, path, opts, status, before) {
  const r = await c.request(path, { ...opts, expectedStatus: status });
  assert.equal(r.payload.success, false);
  assert.deepEqual(await snapshot(c), before);
}
async function send(c, f, id, text = "Synthetic Needl live message") {
  return (
    await c.request(`/api/channels/${id}/messages`, {
      method: "POST",
      token: f.people.A.token,
      body: { content: { text } },
      expectedStatus: 201,
    })
  ).data.message;
}

const cases = [
  {
    id: "FR-NDL-01",
    run: async (c) => {
      const f = await fixture(c);
      const x = await f.create(),
        y = await f.create(["B", "D"]);
      assert.notEqual(x._id, y._id);
      for (const [ls, id] of [
        [["B", "C"], x._id],
        [["D", "B"], y._id],
      ]) {
        const again = await f.create(ls);
        assert.equal(again._id, id);
        assert.deepEqual(
          members(again),
          new Set([f.people.A.userId, ...ls.map((l) => f.people[l].userId)]),
        );
      }
      assert.deepEqual(
        new Set((await stored(c, x._id)).members.map(String)),
        members(x),
      );
    },
  },
  {
    id: "FR-NDL-02",
    run: async (c) => {
      const f = await fixture(c);
      const before = await snapshot(c);
      for (const path of [groupPath, "/api/channels/group-dm"])
        for (const body of [
          {},
          { userIds: [] },
          { userIds: "B" },
          { userIds: ["invalid"] },
          { userIds: [{}] },
        ])
          await denied(
            c,
            path,
            { method: "POST", token: f.people.A.token, body },
            400,
            before,
          );
    },
  },
  {
    id: "FR-NDL-03",
    run: async (c) => {
      const f = await fixture(c);
      await denied(
        c,
        groupPath,
        {
          method: "POST",
          token: f.people.A.token,
          body: { userIds: [f.people.B.userId, "6ac000000000000000000099"] },
        },
        404,
        await snapshot(c),
      );
    },
  },
  {
    id: "FR-NDL-04",
    run: async (c) => {
      const f = await fixture(c, ["A", "B"]);
      const outsider = await c.identity("E");
      await c.request("/api/users/me", {
        method: "PUT",
        token: outsider.token,
        body: { notifications: { allowMessageRequestsFromAnyone: false } },
      });
      await denied(
        c,
        groupPath,
        {
          method: "POST",
          token: f.people.A.token,
          body: { userIds: [f.people.B.userId, outsider.userId] },
        },
        403,
        await snapshot(c),
      );
    },
  },
  {
    id: "FR-NDL-05",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      for (const l of ["A", "B", "C", "D"]) {
        const list = (
          await c.request("/api/channels/dm", { token: f.people[l].token })
        ).data.channels;
        const found = list.find((ch) => ch._id === g._id);
        if (l === "D") assert.equal(found, undefined);
        else {
          assert.equal(found.isNeedl, true);
          assert.equal(found.isSelfNotes, false);
          assert.deepEqual(members(found), members(g));
        }
      }
    },
  },
  {
    id: "FR-NDL-06",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        before = await snapshot(c);
      for (const suffix of ["", "/members"])
        await denied(
          c,
          `/api/channels/${g._id}${suffix}`,
          { token: f.people.D.token },
          403,
          before,
        );
    },
  },
  {
    id: "FR-NDL-07",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        before = await stored(c, g._id);
      await c.request(`/api/channels/${g._id}`, {
        method: "PUT",
        token: f.people.D.token,
        body: { name: "Unauthorized" },
        expectedStatus: 403,
      });
      assert.deepEqual(await stored(c, g._id), before);
      for (const l of ["A", "B", "C"])
        assert.equal(
          (
            await c.request(`/api/channels/${g._id}`, {
              token: f.people[l].token,
            })
          ).data.channel.name,
          g.name,
        );
    },
  },
  {
    id: "FR-NDL-08",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        before = await stored(c, g._id);
      await c.request(`/api/channels/${g._id}`, {
        method: "PUT",
        token: f.people.B.token,
        body: {
          name: "Synthetic named Needl",
          members: [f.people.D.userId],
          spaceId: f.space._id,
          type: "public",
          createdBy: f.people.D.userId,
          memberPairKey: "forged",
        },
      });
      const after = await stored(c, g._id);
      assert.equal(after.name, "Synthetic named Needl");
      for (const k of [
        "members",
        "spaceId",
        "type",
        "createdBy",
        "memberPairKey",
      ])
        assert.deepEqual(after[k], before[k]);
    },
  },
  {
    id: "FR-NDL-09",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      const list = (
        await c.request(`/api/channels/${g._id}/members`, {
          token: f.people.B.token,
        })
      ).data.members;
      assert.deepEqual(new Set(list.map((u) => u._id)), members(g));
      for (const u of list) {
        assert.ok(u.name);
        for (const k of [
          "phone",
          "fcmTokens",
          "refreshToken",
          "otp",
          "otpHash",
        ])
          assert.equal(u[k], undefined, k + " must not leak");
      }
    },
  },
  {
    id: "FR-NDL-10",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      await c.db((db) =>
        db
          .collection("channels")
          .updateOne(
            { _id: new db.base.Types.ObjectId(g._id) },
            { $set: { isArchived: true } },
          ),
      );
      assert.ok(
        !(
          await c.request("/api/channels/dm", { token: f.people.A.token })
        ).data.channels.some((ch) => ch._id === g._id),
      );
      const detail=(await c.request(`/api/channels/${g._id}`,{token:f.people.A.token})).data.channel;
      assert.equal(detail.isArchived,true);
      assert.deepEqual(members(detail),members(g));
      await denied(c,`/api/channels/${g._id}/messages`,{method:'POST',token:f.people.A.token,body:{content:{text:'Must not send to archived Needl'}}},403,await snapshot(c));
      let expansionStatus;
      try { expansionStatus=(await expand(c,f,g._id,['D'],'none')).status; }
      catch(e) { expansionStatus=e.detail?.status;assert.ok([400,403,404].includes(expansionStatus)); }
      assert.equal((await stored(c,g._id)).isArchived,true);
      throw new DecisionPending('NDL-D1: archived Needl expansion policy requires product decision; observed HTTP '+expansionStatus,['Archived group excluded from active list','Authorized historical detail remains readable by explicit allowArchived:true','Message writes denied and persisted source remains archived']);
    },
  },
  {
    id: "FR-NDL-11",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        before = await snapshot(c);
      for (const extra of [
        { userIds: [] },
        { userIds: ["bad"] },
        { history: "unsupported" },
        { todayStart: "yesterday" },
        { timezoneOffsetMinutes: 841 },
        { timezoneOffsetMinutes: "bad" },
      ])
        await denied(
          c,
          `/api/channels/${g._id}/expand`,
          {
            method: "POST",
            token: f.people.A.token,
            body: { userIds: [f.people.D.userId], history: "none", ...extra },
          },
          400,
          before,
        );
    },
  },
  {
    id: "FR-NDL-12",
    run: async (c) => {
      const f = await fixture(c),
        before = await snapshot(c);
      for (const [id, status] of [
        ["6ac000000000000000000099", 404],
        [f.general, 400],
      ])
        await denied(
          c,
          `/api/channels/${id}/expand`,
          {
            method: "POST",
            token: f.people.A.token,
            body: { userIds: [f.people.B.userId], history: "none" },
          },
          status,
          before,
        );
    },
  },
  {
    id: "FR-NDL-13",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      await denied(
        c,
        `/api/channels/${g._id}/expand`,
        {
          method: "POST",
          token: f.people.D.token,
          body: { userIds: [f.people.D.userId], history: "all" },
        },
        403,
        await snapshot(c),
      );
    },
  },
  {
    id: "FR-NDL-14",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        before = await snapshot(c);
      for (const ls of [["A"], ["B", "C", "B"]])
        await denied(
          c,
          `/api/channels/${g._id}/expand`,
          {
            method: "POST",
            token: f.people.A.token,
            body: {
              userIds: ls.map((l) => f.people[l].userId),
              history: "all",
            },
          },
          400,
          before,
        );
    },
  },
  {
    id: "FR-NDL-15",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      const e = await c.identity("E");
      await c.request("/api/users/me", {
        method: "PUT",
        token: e.token,
        body: { notifications: { allowMessageRequestsFromAnyone: false } },
      });
      for (const [id, status] of [
        ["6ac000000000000000000099", 404],
        [e.userId, 403],
      ])
        await denied(
          c,
          `/api/channels/${g._id}/expand`,
          {
            method: "POST",
            token: f.people.A.token,
            body: { userIds: [f.people.D.userId, id], history: "all" },
          },
          status,
          await snapshot(c),
        );
    },
  },
  {
    id: "FR-NDL-16",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        before = await stored(c, g._id);
      const next = (await expand(c, f, g._id, ["B", "D", "D", "A"])).data
        .channel;
      assert.notEqual(next._id, g._id);
      assert.deepEqual(
        members(next),
        new Set(Object.values(f.people).map((p) => p.userId)),
      );
      assert.deepEqual(await stored(c, g._id), before);
    },
  },
  {
    id: "FR-NDL-17",
    timeoutMs: 60000,
    run: async (c) => {
      const f = await fixture(c, [
        "A",
        "B",
        "C",
        "D",
        "E",
        "F",
        "G",
        "H",
        "I",
        "J",
      ]);
      const g = await f.create();
      const next = (await expand(c, f, g._id, ["D", "E", "F", "G", "H", "I"]))
        .data.channel;
      assert.equal(members(next).size, 9);
      await denied(
        c,
        `/api/channels/${next._id}/expand`,
        {
          method: "POST",
          token: f.people.A.token,
          body: { userIds: [f.people.J.userId], history: "none" },
        },
        400,
        await snapshot(c),
      );
      assert.deepEqual(
        members(
          (
            await c.request(`/api/channels/${g._id}`, {
              token: f.people.A.token,
            })
          ).data.channel,
        ),
        members(g),
      );
    },
  },
  {
    id: "FR-NDL-18",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      await seed(c, g._id, f.people.A, [{}]);
      const next = (
        await c.request(`/api/channels/${g._id}/expand`, {
          method: "POST",
          token: f.people.A.token,
          body: { userIds: [f.people.D.userId] },
        })
      ).data.channel;
      assert.equal((await rows(c, next._id)).length, 0);
      await send(c, f, next._id);
      assert.equal((await rows(c, g._id)).length, 1);
      assert.equal((await rows(c, next._id)).length, 1);
    },
  },
  {
    id: "FR-NDL-19",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        boundary = Date.parse("2026-11-02T18:30:00Z");
      const source = await seed(
        c,
        g._id,
        f.people.A,
        [-1, 0, 1].map((d, i) => ({
          content: { text: "Boundary " + i },
          createdAt: new Date(boundary + d),
        })),
      );
      const next = (
        await expand(c, f, g._id, ["D"], "today", {
          todayStart: new Date(boundary).toISOString(),
        })
      ).data.channel;
      const copies = await rows(c, next._id);
      assert.deepEqual(
        copies.map((m) => m.content.text),
        ["Boundary 1", "Boundary 2"],
      );
      assert.deepEqual(
        copies.map((m) => +m.createdAt),
        source.slice(1).map((m) => +m.createdAt),
      );
      assert.deepEqual(
        (await rows(c, g._id)).map((m) => String(m._id)),
        source.map((m) => String(m._id)),
      );
    },
  },
  {
    id: "FR-NDL-20",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      await seed(c, g._id, f.people.A, [{}]);
      const next = (
        await expand(c, f, g._id, ["D"], "today", {
          todayStart: "2026-11-03T00:00:00Z",
        })
      ).data.channel;
      assert.equal((await rows(c, next._id)).length, 0);
      assert.equal(next.lastMessage?.messageId || null, null);
      await send(c, f, next._id);
      assert.equal((await rows(c, next._id)).length, 1);
      assert.equal((await rows(c, g._id)).length, 1);
    },
  },
  {
    id: "FR-NDL-21",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      const source = await seed(c, g._id, f.people.A, [
        { content: { text: "Synthetic urgent" }, priority: "urgent" },
        {
          type: "image",
          content: {
            mediaUrl: "https://synthetic.invalid/image.png",
            mimeType: "image/png",
          },
        },
        {
          type: "document",
          content: {
            mediaUrl: "https://synthetic.invalid/note.pdf",
            fileName: "synthetic.pdf",
          },
        },
        {
          isDeleted: true,
          deletedAt: new Date("2026-11-02T00:00:00Z"),
          content: { text: "This message was deleted" },
        },
      ]);
      const next = (await expand(c, f, g._id, ["D"], "all")).data.channel;
      const copies = await rows(c, next._id);
      assert.equal(copies.length, source.length);
      for (let i = 0; i < source.length; i++) {
        assert.notEqual(String(copies[i]._id), String(source[i]._id));
        for (const k of [
          "senderId",
          "type",
          "priority",
          "createdAt",
          "isDeleted",
        ])
          assert.deepEqual(copies[i][k], source[i][k]);
        for (const [key, value] of Object.entries(source[i].content))
          assert.deepEqual(copies[i].content[key], value);
      }
      assert.equal(next.lastMessage.text, "This message was deleted");
      assert.deepEqual(
        (await rows(c, g._id)).map((m) => String(m._id)),
        source.map((m) => String(m._id)),
      );
    },
  },
  {
    id: "FR-NDL-22",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      const sockets = await Promise.all(
        ["A", "B", "C"].map((l) =>
          connectSocket(null, c.origin, f.people[l].token),
        ),
      );
      try {
        const waiting = sockets.map((s) =>
          waitFor(
            s,
            "new_message",
            (p) => (p.message || p).channelId === g._id,
          ),
        );
        waiting.forEach((p) => p.catch(() => {}));
        const sent = await send(c, f, g._id);
        for (const p of waiting) {
          const event = await p;
          assert.equal((event.message || event)._id, sent._id);
        }
        assert.equal((await rows(c, g._id)).length, 1);
        for (const l of ["A", "B", "C"])
          assert.ok(
            (
              await c.request(`/api/channels/${g._id}/messages`, {
                token: f.people[l].token,
              })
            ).data.messages.some((m) => m._id === sent._id),
          );
      } finally {
        sockets.forEach((s) => s.disconnect());
      }
    },
  },
  {
    id: "FR-NDL-23",
    run: async (c) => {
      const f = await fixture(c, ["A", "B", "C", "D", "E"]);
      const g = await f.create(),
        next = (await expand(c, f, g._id, ["D"])).data.channel;
      const sockets = await Promise.all(
        ["D", "E"].map((l) => connectSocket(null, c.origin, f.people[l].token)),
      );
      const outsider = [];
      sockets[1].on("new_message", (p) => outsider.push(p));
      try {
        const event = waitFor(
          sockets[0],
          "new_message",
          (p) => (p.message || p).channelId === next._id,
        );
        event.catch(() => {});
        const message = await send(c, f, next._id);
        assert.equal(((await event).message || (await event))._id, message._id);
        assert.equal(outsider.length, 0);
        assert.equal((await rows(c, g._id)).length, 0);
        assert.equal((await rows(c, next._id)).length, 1);
        const notes = (
          await c.request("/api/notifications", { token: f.people.E.token })
        ).data.notifications;
        assert.ok(!notes.some((n) => n.referenceId === message._id));
      } finally {
        sockets.forEach((s) => s.disconnect());
      }
    },
  },
  {
    id: "FR-NDL-24",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        before = await snapshot(c);
      for (const [path, method, body] of [
        [
          groupPath,
          "POST",
          { userIds: [f.people.B.userId, f.people.C.userId] },
        ],
        ["/api/channels/dm", "GET"],
        [`/api/channels/${g._id}`, "GET"],
        [`/api/channels/${g._id}/members`, "GET"],
        [`/api/channels/${g._id}`, "PUT", { name: "No auth" }],
        [
          `/api/channels/${g._id}/expand`,
          "POST",
          { userIds: [f.people.D.userId] },
        ],
        [
          `/api/channels/${g._id}/messages`,
          "POST",
          { content: { text: "anonymous" } },
        ],
      ])
        await denied(c, path, { method, body }, 401, before);
    },
  },
  {
    id: "FR-NDL-25",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        other = await f.create(["B", "D"]);
      const sent = await send(c, f, g._id);
      await send(c, f, other._id, "Other group survives");
      await c.request(`/api/channels/${g._id}/messages/${sent._id}`, {
        method: "PUT",
        token: f.people.A.token,
        body: { content: { text: "Edited Needl note" } },
      });
      assert.equal((await rows(c, g._id))[0].content.text, "Edited Needl note");
      await c.request(`/api/channels/${g._id}/messages/${sent._id}`, {
        method: "DELETE",
        token: f.people.A.token,
      });
      const saved = (await rows(c, g._id))[0];
      assert.equal(saved.isDeleted, true);
      assert.equal(saved.content.text, "This message was deleted");
      assert.equal(
        (await rows(c, other._id))[0].content.text,
        "Other group survives",
      );
    },
  },
  {
    id: "FR-NDL-26",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create(),
        m = await send(c, f, g._id);
      await c.request(`/api/channels/${g._id}/pin/${m._id}`, {
        method: "POST",
        token: f.people.B.token,
      });
      const detail = (
        await c.request(`/api/channels/${g._id}`, { token: f.people.C.token })
      ).data.channel;
      assert.ok(
        detail.pinnedMessages.some(
          (p) => (p.messageId?._id || p.messageId) === m._id,
        ),
      );
      await c.request(`/api/channels/${g._id}/pin/${m._id}`, {
        method: "DELETE",
        token: f.people.C.token,
      });
      assert.equal((await stored(c, g._id)).pinnedMessages.length, 0);
      await c.request(`/api/channels/${g._id}/messages/read`, {
        method: "POST",
        token: f.people.B.token,
        body: { messageIds: [m._id] },
      });
      assert.ok(
        (await rows(c, g._id))[0].readBy.some(
          (r) => String(r.userId) === f.people.B.userId,
        ),
      );
    },
  },
  {
    id: "FR-NDL-27",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      await c.request(`/api/channels/${g._id}`, {
        method: "PUT",
        token: f.people.A.token,
        body: { name: "Restart Needl" },
      });
      const m = await send(c, f, g._id);
      await c.restartBackend();
      const detail = (
        await c.request(`/api/channels/${g._id}`, { token: f.people.B.token })
      ).data.channel;
      assert.equal(detail.name, "Restart Needl");
      assert.deepEqual(members(detail), members(g));
      assert.equal((await rows(c, g._id))[0]._id.toString(), m._id);
      assert.ok(
        (
          await c.request(`/api/channels/${g._id}/messages`, {
            token: f.people.C.token,
          })
        ).data.messages.some((row) => row._id === m._id),
      );
    },
  },
  {
    id: "FR-NDL-28",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      await seed(c, g._id, f.people.A, [{}]);
      const settled = await Promise.allSettled([
        expand(c, f, g._id, ["D"], "all"),
        expand(c, f, g._id, ["D"], "all"),
      ]);
      assert.ok(
        settled.every((r) => r.status === "fulfilled"),
        "Every concurrent expansion must return a usable existing/new destination",
      );
      const ids = settled.map((r) => r.value.data.channel._id);
      assert.equal(new Set(ids).size, 1);
      assert.equal((await rows(c, ids[0])).length, 1);
      const count = await c.db((db) =>
        db
          .collection("channels")
          .countDocuments({
            type: "direct",
            members: {
              $all: [...members(g), f.people.D.userId].map(
                (id) => new db.base.Types.ObjectId(id),
              ),
              $size: 4,
            },
          }),
      );
      assert.equal(count, 1);
    },
  },
  {
    id: "FR-NDL-29",
    run: async (c) => {
      const f = await fixture(c);
      const g = await f.create();
      const source = await seed(c, g._id, f.people.A, [
        { content: { text: "Synthetic unique copy recovery" } },
      ]);
      await c.db((db) =>
        db
          .collection("messages")
          .createIndex(
            { "content.text": 1 },
            {
              name: "needl_copy_fault",
              unique: true,
              partialFilterExpression: { "content.text": { $type: "string" } },
            },
          ),
      );
      let failed = false;
      try {
        await expand(c, f, g._id, ["D"], "all");
      } catch (e) {
        assert.ok([400, 500].includes(e.detail?.status));
        failed = true;
      } finally {
        await c.db((db) =>
          db.collection("messages").dropIndex("needl_copy_fault"),
        );
      }
      assert.ok(failed, "Fault fixture must interrupt copy");
      const retry = (await expand(c, f, g._id, ["D"], "all")).data.channel;
      assert.equal(
        (await rows(c, retry._id)).length,
        source.length,
        "Retry must recover intended history after the database fault is removed",
      );
      assert.equal((await rows(c, g._id)).length, 1);
    },
  },
  {
    id: "FR-NDL-30",
    run: async (c) => {
      const f = await fixture(c);
      await f.create();
      const before = await snapshot(c);
      const response = await c.request("/api/channels/dm", {
        method: "POST",
        token: f.people.B.token,
        body: { userId: f.people.C.userId },
        expectedStatus: 403,
      });
      assert.equal(response.payload.success, false);
      assert.deepEqual(await snapshot(c), before);
    },
  },
];
for (const test of cases)
  await runModule("needl-" + test.id.slice(-2), [{ ...test, module: "NDL" }]);
