# Vocle regression report

Artifact: **Vocle report artifact**. Download and extract it, then open `vocle-regression-dashboard.html` locally.

Suite: developer; scope: needl-functional-subset; original gate: **FAIL**.

Source: `4765df8b89912dcb48f377fc184f83041f0decc0`; harness: `4765df8b89912dcb48f377fc184f83041f0decc0`.

| PASS | FAIL | ERROR | BLOCKED | NEEDS_DECISION | SKIP |
| --- | --- | --- | --- | --- | --- |
| 48 | 5 | 0 | 0 | 1 | 0 |

Functional catalog: 241 total / 233 hosted / 8 LOCAL_ONLY.



Android local availability: FR-MED-08 — LOCAL_ONLY; executed false; SKIP; FR-PUSH-05 — LOCAL_ONLY; executed false; SKIP; FR-PUSH-06 — LOCAL_ONLY; executed false; SKIP; FR-NAV-04 — LOCAL_ONLY; executed false; SKIP; FR-NAV-05 — LOCAL_ONLY; executed false; SKIP; FR-LINK-04 — LOCAL_ONLY; executed false; SKIP; FR-JRN-05 — LOCAL_ONLY; executed false; SKIP; FR-JRN-06 — LOCAL_ONLY; executed false; SKIP.

Selected 54; recorded rows 54; attempted 54. Missing evidence never means PASS.





historical comparison: UNAVAILABLE
reason: No compatible baseline was supplied.

Reporting does not change test exit codes, success-history evidence, assertions or original classifications. Definition/procedure text is not a per-step execution trace. Ownership requires an approved mapping. Procedure metadata was read from the reporter checkout 4765df8b89912dcb48f377fc184f83041f0decc0; recorded execution revisions remain separate. Older evidence does not prove newly changed definitions passed.

## FR-NDL-01 — Create separate Needls with overlapping member sets

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 1529 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Create separate Needls with overlapping member sets.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Create separate Needls with overlapping member sets
   Expected: Different exact member sets return distinct IDs; repeating either intent reuses only its own group; DB memberships remain exact

### Expected and observed results

Contract: Different exact member sets return distinct IDs; repeating either intent reuses only its own group; DB memberships remain exact

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:109; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-01&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const x = await f.create(),
        y = await f.create([&quot;B&quot;, &quot;D&quot;]);
      assert.notEqual(x._id, y._id);
      for (const [ls, id] of [
        [[&quot;B&quot;, &quot;C&quot;], x._id],
        [[&quot;D&quot;, &quot;B&quot;], y._id],
      ]) {
        const again = await f.create(ls);
        assert.equal(again._id, id);
        assert.deepEqual(
          members(again),
          new Set([f.people.A.userId, ...ls.map((l) =&gt; f.people[l].userId)]),
        );
      }
      assert.deepEqual(
        new Set((await stored(c, x._id)).members.map(String)),
        members(x),
      );
    },
  },
  {</pre>

## FR-NDL-02 — Reject malformed group creation on both route aliases

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 978 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Reject malformed group creation on both route aliases.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Reject malformed group creation on both route aliases
   Expected: Missing, empty, nonarray, malformed or object-shaped user IDs return validation errors without channel creation

### Expected and observed results

Contract: Missing, empty, nonarray, malformed or object-shaped user IDs return validation errors without channel creation

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:133; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-02&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const before = await snapshot(c);
      for (const path of [groupPath, &quot;/api/channels/group-dm&quot;])
        for (const body of [
          {},
          { userIds: [] },
          { userIds: &quot;B&quot; },
          { userIds: [&quot;invalid&quot;] },
          { userIds: [{}] },
        ])
          await denied(
            c,
            path,
            { method: &quot;POST&quot;, token: [REDACTED], body },
            400,
            before,
          );
    },
  },
  {</pre>

## FR-NDL-03 — Reject nonexistent participant without partial Needl

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 512 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Reject nonexistent participant without partial Needl.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Reject nonexistent participant without partial Needl
   Expected: 404 and unchanged channels/messages; previously valid participants do not create a partial group

### Expected and observed results

Contract: 404 and unchanged channels/messages; previously valid participants do not create a partial group

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:155; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-03&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      await denied(
        c,
        groupPath,
        {
          method: &quot;POST&quot;,
          token: [REDACTED],
          body: { userIds: [f.people.B.userId, &quot;6ac000000000000000000099&quot;] },
        },
        404,
        await snapshot(c),
      );
    },
  },
  {</pre>

## FR-NDL-04 — Respect unrelated colleague request opt-out

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 452 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Respect unrelated colleague request opt-out.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Respect unrelated colleague request opt-out
   Expected: 403 and no new group when any selected outsider disallows message requests

### Expected and observed results

Contract: 403 and no new group when any selected outsider disallows message requests

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:172; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-04&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c, [&quot;A&quot;, &quot;B&quot;]);
      const outsider = await c.identity(&quot;E&quot;);
      await c.request(&quot;/api/users/me&quot;, {
        method: &quot;PUT&quot;,
        token: [REDACTED],
        body: { notifications: { allowMessageRequestsFromAnyone: false } },
      });
      await denied(
        c,
        groupPath,
        {
          method: &quot;POST&quot;,
          token: [REDACTED],
          body: { userIds: [f.people.B.userId, outsider.userId] },
        },
        403,
        await snapshot(c),
      );
    },
  },
  {</pre>

## FR-NDL-05 — List Needls for every member and exclude outsiders

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 549 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: List Needls for every member and exclude outsiders.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. List Needls for every member and exclude outsiders
   Expected: All members independently retrieve the same ID and exact membership; unrelated doctor never lists it

### Expected and observed results

Contract: All members independently retrieve the same ID and exact membership; unrelated doctor never lists it

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:195; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-05&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      for (const l of [&quot;A&quot;, &quot;B&quot;, &quot;C&quot;, &quot;D&quot;]) {
        const list = (
          await c.request(&quot;/api/channels/dm&quot;, { token: [REDACTED] })
        ).data.channels;
        const found = list.find((ch) =&gt; ch._id === g._id);
        if (l === &quot;D&quot;) assert.equal(found, undefined);
        else {
          assert.equal(found.isNeedl, true);
          assert.equal(found.isSelfNotes, false);
          assert.deepEqual(members(found), members(g));
        }
      }
    },
  },
  {</pre>

## FR-NDL-06 — Deny outsider detail and members access

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 590 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Deny outsider detail and members access.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Deny outsider detail and members access
   Expected: Detail and member endpoints deny nonmembers without exposing group data or changing persistence

### Expected and observed results

Contract: Detail and member endpoints deny nonmembers without exposing group data or changing persistence

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:214; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-06&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        before = await snapshot(c);
      for (const suffix of [&quot;&quot;, &quot;/members&quot;])
        await denied(
          c,
          `/api/channels/${g._id}${suffix}`,
          { token: [REDACTED] },
          403,
          before,
        );
    },
  },
  {</pre>

## FR-NDL-07 — Deny outsider rename without changing name

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 560 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Deny outsider rename without changing name.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Deny outsider rename without changing name
   Expected: 403; all members and DB retain prior title and membership

### Expected and observed results

Contract: 403; all members and DB retain prior title and membership

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:230; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-07&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        before = await stored(c, g._id);
      await c.request(`/api/channels/${g._id}`, {
        method: &quot;PUT&quot;,
        token: [REDACTED],
        body: { name: &quot;Unauthorized&quot; },
        expectedStatus: 403,
      });
      assert.deepEqual(await stored(c, g._id), before);
      for (const l of [&quot;A&quot;, &quot;B&quot;, &quot;C&quot;])
        assert.equal(
          (
            await c.request(`/api/channels/${g._id}`, {
              token: [REDACTED],
            })
          ).data.channel.name,
          g.name,
        );
    },
  },
  {</pre>

## FR-NDL-08 — Ignore membership and identity mass assignment on rename

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 557 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Ignore membership and identity mass assignment on rename.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Ignore membership and identity mass assignment on rename
   Expected: Only name changes; members, type, owner, pair key and space binding remain unchanged

### Expected and observed results

Contract: Only name changes; members, type, owner, pair key and space binding remain unchanged

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:254; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-08&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        before = await stored(c, g._id);
      await c.request(`/api/channels/${g._id}`, {
        method: &quot;PUT&quot;,
        token: [REDACTED],
        body: {
          name: &quot;Synthetic named Needl&quot;,
          members: [f.people.D.userId],
          spaceId: f.space._id,
          type: &quot;public&quot;,
          createdBy: f.people.D.userId,
          memberPairKey: &quot;forged&quot;,
        },
      });
      const after = await stored(c, g._id);
      assert.equal(after.name, &quot;Synthetic named Needl&quot;);
      for (const k of [
        &quot;members&quot;,
        &quot;spaceId&quot;,
        &quot;type&quot;,
        &quot;createdBy&quot;,
        &quot;memberPairKey&quot;,
      ])
        assert.deepEqual(after[k], before[k]);
    },
  },
  {</pre>

## FR-NDL-09 — Project group members without private credential fields

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 527 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Project group members without private credential fields.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Project group members without private credential fields
   Expected: Exact IDs and public profile fields; no phone, OTP, refresh or device credentials returned

### Expected and observed results

Contract: Exact IDs and public profile fields; no phone, OTP, refresh or device credentials returned

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:284; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-09&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      const list = (
        await c.request(`/api/channels/${g._id}/members`, {
          token: [REDACTED],
        })
      ).data.members;
      assert.deepEqual(new Set(list.map((u) =&gt; u._id)), members(g));
      for (const u of list) {
        assert.ok(u.name);
        for (const k of [
          &quot;phone&quot;,
          &quot;fcmTokens&quot;,
          &quot;refreshToken&quot;,
          &quot;otp&quot;,
          &quot;otpHash&quot;,
        ])
          assert.equal(u[k], undefined, k + &quot; must not leak&quot;);
      }
    },
  },
  {</pre>

## FR-NDL-10 — Verify archived Needl read-only behavior and record expansion policy

**NEEDS_DECISION**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 594 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Verify archived Needl read-only behavior and record expansion policy.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Verify archived Needl read-only behavior and record expansion policy
   Expected: Archived groups disappear from lists; authorized historical detail is readable and message sends denied; whether expansion is permitted requires NDL-D1

### Expected and observed results

Contract: Archived groups disappear from lists; authorized historical detail is readable and message sends denied; whether expansion is permitted requires NDL-D1

Observed: NDL-D1: archived Needl expansion policy requires product decision; observed HTTP 200

Failing step: Exact step index not captured by the original runner; inspect diagnostic and definition.

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: UNRESOLVED\_PRODUCT\_DECISION

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The full expectation is undecided. Only explicitly recorded safe subassertions receive credit; the disputed expectation has not passed.

Inferred consequence, not an observed production/UI incident: the described Needl group conversations scenario is not fully verified. The intended user-visible contract requires product agreement.

Explicit subassertion evidence: \[&quot;Archived group excluded from active list&quot;,&quot;Authorized historical detail remains readable by explicit allowArchived:true&quot;,&quot;Message writes denied and persisted source remains archived&quot;\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: NDL-D1

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>NDL-D1: archived Needl expansion policy requires product decision; observed HTTP 200</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:308; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-10&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      await c.db((db) =&gt;
        db
          .collection(&quot;channels&quot;)
          .updateOne(
            { _id: new db.base.Types.ObjectId(g._id) },
            { $set: { isArchived: true } },
          ),
      );
      assert.ok(
        !(
          await c.request(&quot;/api/channels/dm&quot;, { token: [REDACTED] })
        ).data.channels.some((ch) =&gt; ch._id === g._id),
      );
      const detail=(await c.request(`/api/channels/${g._id}`,{token:[REDACTED]})).data.channel;
      assert.equal(detail.isArchived,true);
      assert.deepEqual(members(detail),members(g));
      await denied(c,`/api/channels/${g._id}/messages`,{method:&#39;POST&#39;,token:[REDACTED],body:{content:{text:&#39;Must not send to archived Needl&#39;}}},403,await snapshot(c));
      let expansionStatus;
      try { expansionStatus=(await expand(c,f,g._id,[&#39;D&#39;],&#39;none&#39;)).status; }
      catch(e) { expansionStatus=e.detail?.status;assert.ok([400,403,404].includes(expansionStatus)); }
      assert.equal((await stored(c,g._id)).isArchived,true);
      throw new DecisionPending(&#39;NDL-D1: archived Needl expansion policy requires product decision; observed HTTP &#39;+expansionStatus,[&#39;Archived group excluded from active list&#39;,&#39;Authorized historical detail remains readable by explicit allowArchived:true&#39;,&#39;Message writes denied and persisted source remains archived&#39;]);
    },
  },
  {</pre>

## FR-NDL-11 — Validate expansion payload before writes

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 615 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Validate expansion payload before writes.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Validate expansion payload before writes
   Expected: Invalid history, IDs, date, offset and empty input rejected; source and destination resources unchanged

### Expected and observed results

Contract: Invalid history, IDs, date, offset and empty input rejected; source and destination resources unchanged

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:337; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-11&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        before = await snapshot(c);
      for (const extra of [
        { userIds: [] },
        { userIds: [&quot;bad&quot;] },
        { history: &quot;unsupported&quot; },
        { todayStart: &quot;yesterday&quot; },
        { timezoneOffsetMinutes: 841 },
        { timezoneOffsetMinutes: &quot;bad&quot; },
      ])
        await denied(
          c,
          `/api/channels/${g._id}/expand`,
          {
            method: &quot;POST&quot;,
            token: [REDACTED],
            body: { userIds: [f.people.D.userId], history: &quot;none&quot;, ...extra },
          },
          400,
          before,
        );
    },
  },
  {</pre>

## FR-NDL-12 — Reject missing or space-channel expansion source

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 538 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Reject missing or space-channel expansion source.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Reject missing or space-channel expansion source
   Expected: Missing source 404; ordinary space channel 400; no hidden direct conversation created

### Expected and observed results

Contract: Missing source 404; ordinary space channel 400; no hidden direct conversation created

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:364; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-12&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c),
        before = await snapshot(c);
      for (const [id, status] of [
        [&quot;6ac000000000000000000099&quot;, 404],
        [f.general, 400],
      ])
        await denied(
          c,
          `/api/channels/${id}/expand`,
          {
            method: &quot;POST&quot;,
            token: [REDACTED],
            body: { userIds: [f.people.B.userId], history: &quot;none&quot; },
          },
          status,
          before,
        );
    },
  },
  {</pre>

## FR-NDL-13 — Deny outsider expansion of a private Needl

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 545 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Deny outsider expansion of a private Needl.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Deny outsider expansion of a private Needl
   Expected: 403 with no source mutation, copied messages or new destination

### Expected and observed results

Contract: 403 with no source mutation, copied messages or new destination

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:386; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-13&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      await denied(
        c,
        `/api/channels/${g._id}/expand`,
        {
          method: &quot;POST&quot;,
          token: [REDACTED],
          body: { userIds: [f.people.D.userId], history: &quot;all&quot; },
        },
        403,
        await snapshot(c),
      );
    },
  },
  {</pre>

## FR-NDL-14 — Reject additions containing only existing participants

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 559 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Reject additions containing only existing participants.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Reject additions containing only existing participants
   Expected: 400 for self or existing-only selection; duplicates do not produce an empty or duplicate expansion

### Expected and observed results

Contract: 400 for self or existing-only selection; duplicates do not produce an empty or duplicate expansion

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:404; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-14&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        before = await snapshot(c);
      for (const ls of [[&quot;A&quot;], [&quot;B&quot;, &quot;C&quot;, &quot;B&quot;]])
        await denied(
          c,
          `/api/channels/${g._id}/expand`,
          {
            method: &quot;POST&quot;,
            token: [REDACTED],
            body: {
              userIds: ls.map((l) =&gt; f.people[l].userId),
              history: &quot;all&quot;,
            },
          },
          400,
          before,
        );
    },
  },
  {</pre>

## FR-NDL-15 — Reject nonexistent or ineligible new participant atomically

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 700 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Reject nonexistent or ineligible new participant atomically.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Reject nonexistent or ineligible new participant atomically
   Expected: 404/403 before destination or history writes; source membership/content preserved

### Expected and observed results

Contract: 404/403 before destination or history writes; source membership/content preserved

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:427; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-15&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      const e = await c.identity(&quot;E&quot;);
      await c.request(&quot;/api/users/me&quot;, {
        method: &quot;PUT&quot;,
        token: [REDACTED],
        body: { notifications: { allowMessageRequestsFromAnyone: false } },
      });
      for (const [id, status] of [
        [&quot;6ac000000000000000000099&quot;, 404],
        [e.userId, 403],
      ])
        await denied(
          c,
          `/api/channels/${g._id}/expand`,
          {
            method: &quot;POST&quot;,
            token: [REDACTED],
            body: { userIds: [f.people.D.userId, id], history: &quot;all&quot; },
          },
          status,
          await snapshot(c),
        );
    },
  },
  {</pre>

## FR-NDL-16 — Normalize mixed existing and duplicate new participants

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 562 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Normalize mixed existing and duplicate new participants.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Normalize mixed existing and duplicate new participants
   Expected: Destination contains each old/new person once; source remains separate and unchanged

### Expected and observed results

Contract: Destination contains each old/new person once; source remains separate and unchanged

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:455; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-16&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        before = await stored(c, g._id);
      const next = (await expand(c, f, g._id, [&quot;B&quot;, &quot;D&quot;, &quot;D&quot;, &quot;A&quot;])).data
        .channel;
      assert.notEqual(next._id, g._id);
      assert.deepEqual(
        members(next),
        new Set(Object.values(f.people).map((p) =&gt; p.userId)),
      );
      assert.deepEqual(await stored(c, g._id), before);
    },
  },
  {</pre>

## FR-NDL-17 — Enforce expansion nine-person boundary

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 1239 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Enforce expansion nine-person boundary.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Enforce expansion nine-person boundary
   Expected: Expansion to nine succeeds; tenth rejected without partial group or source membership changes

### Expected and observed results

Contract: Expansion to nine succeeds; tenth rejected without partial group or source membership changes

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:471; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-17&quot;,
    timeoutMs: 60000,
    run: async (c) =&gt; {
      const f = await fixture(c, [
        &quot;A&quot;,
        &quot;B&quot;,
        &quot;C&quot;,
        &quot;D&quot;,
        &quot;E&quot;,
        &quot;F&quot;,
        &quot;G&quot;,
        &quot;H&quot;,
        &quot;I&quot;,
        &quot;J&quot;,
      ]);
      const g = await f.create();
      const next = (await expand(c, f, g._id, [&quot;D&quot;, &quot;E&quot;, &quot;F&quot;, &quot;G&quot;, &quot;H&quot;, &quot;I&quot;]))
        .data.channel;
      assert.equal(members(next).size, 9);
      await denied(
        c,
        `/api/channels/${next._id}/expand`,
        {
          method: &quot;POST&quot;,
          token: [REDACTED],
          body: { userIds: [f.people.J.userId], history: &quot;none&quot; },
        },
        400,
        await snapshot(c),
      );
      assert.deepEqual(
        members(
          (
            await c.request(`/api/channels/${g._id}`, {
              token: [REDACTED],
            })
          ).data.channel,
        ),
        members(g),
      );
    },
  },
  {</pre>

## FR-NDL-18 — Omitted history creates a fresh conversation

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 611 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Omitted history creates a fresh conversation.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Omitted history creates a fresh conversation
   Expected: No source messages copied when history omitted; new destination accepts independent subsequent messages

### Expected and observed results

Contract: No source messages copied when history omitted; new destination accepts independent subsequent messages

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:514; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-18&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      await seed(c, g._id, f.people.A, [{}]);
      const next = (
        await c.request(`/api/channels/${g._id}/expand`, {
          method: &quot;POST&quot;,
          token: [REDACTED],
          body: { userIds: [f.people.D.userId] },
        })
      ).data.channel;
      assert.equal((await rows(c, next._id)).length, 0);
      await send(c, f, next._id);
      assert.equal((await rows(c, g._id)).length, 1);
      assert.equal((await rows(c, next._id)).length, 1);
    },
  },
  {</pre>

## FR-NDL-19 — Copy today using explicit phone-local midnight

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 579 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Copy today using explicit phone-local midnight.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Copy today using explicit phone-local midnight
   Expected: Before boundary excluded; exact boundary and later timestamps included unchanged; source rows unchanged

### Expected and observed results

Contract: Before boundary excluded; exact boundary and later timestamps included unchanged; source rows unchanged

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:533; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-19&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        boundary = Date.parse(&quot;2026-11-02T18:30:00Z&quot;);
      const source = await seed(
        c,
        g._id,
        f.people.A,
        [-1, 0, 1].map((d, i) =&gt; ({
          content: { text: &quot;Boundary &quot; + i },
          createdAt: new Date(boundary + d),
        })),
      );
      const next = (
        await expand(c, f, g._id, [&quot;D&quot;], &quot;today&quot;, {
          todayStart: new Date(boundary).toISOString(),
        })
      ).data.channel;
      const copies = await rows(c, next._id);
      assert.deepEqual(
        copies.map((m) =&gt; m.content.text),
        [&quot;Boundary 1&quot;, &quot;Boundary 2&quot;],
      );
      assert.deepEqual(
        copies.map((m) =&gt; +m.createdAt),
        source.slice(1).map((m) =&gt; +m.createdAt),
      );
      assert.deepEqual(
        (await rows(c, g._id)).map((m) =&gt; String(m._id)),
        source.map((m) =&gt; String(m._id)),
      );
    },
  },
  {</pre>

## FR-NDL-20 — Handle today with no qualifying messages

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 619 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Handle today with no qualifying messages.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Handle today with no qualifying messages
   Expected: Empty destination and absent preview; source history preserved; sending after expansion works

### Expected and observed results

Contract: Empty destination and absent preview; source history preserved; sending after expansion works

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:568; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-20&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      await seed(c, g._id, f.people.A, [{}]);
      const next = (
        await expand(c, f, g._id, [&quot;D&quot;], &quot;today&quot;, {
          todayStart: &quot;2026-11-03T00:00:00Z&quot;,
        })
      ).data.channel;
      assert.equal((await rows(c, next._id)).length, 0);
      assert.equal(next.lastMessage?.messageId || null, null);
      await send(c, f, next._id);
      assert.equal((await rows(c, next._id)).length, 1);
      assert.equal((await rows(c, g._id)).length, 1);
    },
  },
  {</pre>

## FR-NDL-21 — Copy heterogeneous history and deletion state

**PASS**; module NDL; tier B; priority P1; owner UNASSIGNED; attempted true; duration 589 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Copy heterogeneous history and deletion state.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Copy heterogeneous history and deletion state
   Expected: Text/media/mentions/priority/sender/timestamps and deleted placeholders copied with new IDs; source untouched

### Expected and observed results

Contract: Text/media/mentions/priority/sender/timestamps and deleted placeholders copied with new IDs; source untouched

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:586; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-21&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      const source = await seed(c, g._id, f.people.A, [
        { content: { text: &quot;Synthetic urgent&quot; }, priority: &quot;urgent&quot; },
        {
          type: &quot;image&quot;,
          content: {
            mediaUrl: &quot;https://synthetic.invalid/image.png&quot;,
            mimeType: &quot;image/png&quot;,
          },
        },
        {
          type: &quot;document&quot;,
          content: {
            mediaUrl: &quot;https://synthetic.invalid/note.pdf&quot;,
            fileName: &quot;synthetic.pdf&quot;,
          },
        },
        {
          isDeleted: true,
          deletedAt: new Date(&quot;2026-11-02T00:00:00Z&quot;),
          content: { text: &quot;This message was deleted&quot; },
        },
      ]);
      const next = (await expand(c, f, g._id, [&quot;D&quot;], &quot;all&quot;)).data.channel;
      const copies = await rows(c, next._id);
      assert.equal(copies.length, source.length);
      for (let i = 0; i &lt; source.length; i++) {
        assert.notEqual(String(copies[i]._id), String(source[i]._id));
        for (const k of [
          &quot;senderId&quot;,
          &quot;type&quot;,
          &quot;priority&quot;,
          &quot;createdAt&quot;,
          &quot;isDeleted&quot;,
        ])
          assert.deepEqual(copies[i][k], source[i][k]);
        for (const [key, value] of Object.entries(source[i].content))
          assert.deepEqual(copies[i].content[key], value);
      }
      assert.equal(next.lastMessage.text, &quot;This message was deleted&quot;);
      assert.deepEqual(
        (await rows(c, g._id)).map((m) =&gt; String(m._id)),
        source.map((m) =&gt; String(m._id)),
      );
    },
  },
  {</pre>

## FR-NDL-22 — Deliver Needl messages to all participants

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 625 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Deliver Needl messages to all participants.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Deliver Needl messages to all participants
   Expected: Subscribe before send; each participant receives correlated message ID; DB and independent reads agree

### Expected and observed results

Contract: Subscribe before send; each participant receives correlated message ID; DB and independent reads agree

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:636; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-22&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      const sockets = await Promise.all(
        [&quot;A&quot;, &quot;B&quot;, &quot;C&quot;].map((l) =&gt;
          connectSocket(null, c.origin, f.people[l].token),
        ),
      );
      try {
        const waiting = sockets.map((s) =&gt;
          waitFor(
            s,
            &quot;new_message&quot;,
            (p) =&gt; (p.message || p).channelId === g._id,
          ),
        );
        waiting.forEach((p) =&gt; p.catch(() =&gt; {}));
        const sent = await send(c, f, g._id);
        for (const p of waiting) {
          const event = await p;
          assert.equal((event.message || event)._id, sent._id);
        }
        assert.equal((await rows(c, g._id)).length, 1);
        for (const l of [&quot;A&quot;, &quot;B&quot;, &quot;C&quot;])
          assert.ok(
            (
              await c.request(`/api/channels/${g._id}/messages`, {
                token: [REDACTED],
              })
            ).data.messages.some((m) =&gt; m._id === sent._id),
          );
      } finally {
        sockets.forEach((s) =&gt; s.disconnect());
      }
    },
  },
  {</pre>

## FR-NDL-23 — Keep expanded conversation traffic out of original and outsider audiences

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 681 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Keep expanded conversation traffic out of original and outsider audiences.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Keep expanded conversation traffic out of original and outsider audiences
   Expected: New member receives destination message; notifications belong only to destination participants; source history and outsider inbox unchanged

### Expected and observed results

Contract: New member receives destination message; notifications belong only to destination participants; source history and outsider inbox unchanged

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:674; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-23&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c, [&quot;A&quot;, &quot;B&quot;, &quot;C&quot;, &quot;D&quot;, &quot;E&quot;]);
      const g = await f.create(),
        next = (await expand(c, f, g._id, [&quot;D&quot;])).data.channel;
      const sockets = await Promise.all(
        [&quot;D&quot;, &quot;E&quot;].map((l) =&gt; connectSocket(null, c.origin, f.people[l].token)),
      );
      const outsider = [];
      sockets[1].on(&quot;new_message&quot;, (p) =&gt; outsider.push(p));
      try {
        const event = waitFor(
          sockets[0],
          &quot;new_message&quot;,
          (p) =&gt; (p.message || p).channelId === next._id,
        );
        event.catch(() =&gt; {});
        const message = await send(c, f, next._id);
        assert.equal(((await event).message || (await event))._id, message._id);
        assert.equal(outsider.length, 0);
        assert.equal((await rows(c, g._id)).length, 0);
        assert.equal((await rows(c, next._id)).length, 1);
        const notes = (
          await c.request(&quot;/api/notifications&quot;, { token: [REDACTED] })
        ).data.notifications;
        assert.ok(!notes.some((n) =&gt; n.referenceId === message._id));
      } finally {
        sockets.forEach((s) =&gt; s.disconnect());
      }
    },
  },
  {</pre>

## FR-NDL-24 — Require authentication for all Needl endpoints

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 670 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Require authentication for all Needl endpoints.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Require authentication for all Needl endpoints
   Expected: Create/list/detail/members/rename/expand/message actions reject anonymous requests without writes

### Expected and observed results

Contract: Create/list/detail/members/rename/expand/message actions reject anonymous requests without writes

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:706; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-24&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        before = await snapshot(c);
      for (const [path, method, body] of [
        [
          groupPath,
          &quot;POST&quot;,
          { userIds: [f.people.B.userId, f.people.C.userId] },
        ],
        [&quot;/api/channels/dm&quot;, &quot;GET&quot;],
        [`/api/channels/${g._id}`, &quot;GET&quot;],
        [`/api/channels/${g._id}/members`, &quot;GET&quot;],
        [`/api/channels/${g._id}`, &quot;PUT&quot;, { name: &quot;No auth&quot; }],
        [
          `/api/channels/${g._id}/expand`,
          &quot;POST&quot;,
          { userIds: [f.people.D.userId] },
        ],
        [
          `/api/channels/${g._id}/messages`,
          &quot;POST&quot;,
          { content: { text: &quot;anonymous&quot; } },
        ],
      ])
        await denied(c, path, { method, body }, 401, before);
    },
  },
  {</pre>

## FR-NDL-25 — Edit and delete Needl messages with independent reload

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 617 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Edit and delete Needl messages with independent reload.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Edit and delete Needl messages with independent reload
   Expected: Edited content and tombstone persist in the correct group; unrelated group messages remain intact

### Expected and observed results

Contract: Edited content and tombstone persist in the correct group; unrelated group messages remain intact

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:736; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-25&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        other = await f.create([&quot;B&quot;, &quot;D&quot;]);
      const sent = await send(c, f, g._id);
      await send(c, f, other._id, &quot;Other group survives&quot;);
      await c.request(`/api/channels/${g._id}/messages/${sent._id}`, {
        method: &quot;PUT&quot;,
        token: [REDACTED],
        body: { content: { text: &quot;Edited Needl note&quot; } },
      });
      assert.equal((await rows(c, g._id))[0].content.text, &quot;Edited Needl note&quot;);
      await c.request(`/api/channels/${g._id}/messages/${sent._id}`, {
        method: &quot;DELETE&quot;,
        token: [REDACTED],
      });
      const saved = (await rows(c, g._id))[0];
      assert.equal(saved.isDeleted, true);
      assert.equal(saved.content.text, &quot;This message was deleted&quot;);
      assert.equal(
        (await rows(c, other._id))[0].content.text,
        &quot;Other group survives&quot;,
      );
    },
  },
  {</pre>

## FR-NDL-26 — Persist group pins and per-member receipts

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 606 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Persist group pins and per-member receipts.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Persist group pins and per-member receipts
   Expected: Group member pin/unpin and read receipts persist; outsider actions denied; exact referenced message retained

### Expected and observed results

Contract: Group member pin/unpin and read receipts persist; outsider actions denied; exact referenced message retained

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:763; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-26&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create(),
        m = await send(c, f, g._id);
      await c.request(`/api/channels/${g._id}/pin/${m._id}`, {
        method: &quot;POST&quot;,
        token: [REDACTED],
      });
      const detail = (
        await c.request(`/api/channels/${g._id}`, { token: [REDACTED] })
      ).data.channel;
      assert.ok(
        detail.pinnedMessages.some(
          (p) =&gt; (p.messageId?._id || p.messageId) === m._id,
        ),
      );
      await c.request(`/api/channels/${g._id}/pin/${m._id}`, {
        method: &quot;DELETE&quot;,
        token: [REDACTED],
      });
      assert.equal((await stored(c, g._id)).pinnedMessages.length, 0);
      await c.request(`/api/channels/${g._id}/messages/read`, {
        method: &quot;POST&quot;,
        token: [REDACTED],
        body: { messageIds: [m._id] },
      });
      assert.ok(
        (await rows(c, g._id))[0].readBy.some(
          (r) =&gt; String(r.userId) === f.people.B.userId,
        ),
      );
    },
  },
  {</pre>

## FR-NDL-27 — Restore Needl identity after backend restart

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 1640 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Restore Needl identity after backend restart.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Restore Needl identity after backend restart
   Expected: Same group ID, title, members and message content survive restart against disposable DB

### Expected and observed results

Contract: Same group ID, title, members and message content survive restart against disposable DB

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:798; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-27&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      await c.request(`/api/channels/${g._id}`, {
        method: &quot;PUT&quot;,
        token: [REDACTED],
        body: { name: &quot;Restart Needl&quot; },
      });
      const m = await send(c, f, g._id);
      await c.restartBackend();
      const detail = (
        await c.request(`/api/channels/${g._id}`, { token: [REDACTED] })
      ).data.channel;
      assert.equal(detail.name, &quot;Restart Needl&quot;);
      assert.deepEqual(members(detail), members(g));
      assert.equal((await rows(c, g._id))[0]._id.toString(), m._id);
      assert.ok(
        (
          await c.request(`/api/channels/${g._id}/messages`, {
            token: [REDACTED],
          })
        ).data.messages.some((row) =&gt; row._id === m._id),
      );
    },
  },
  {</pre>

## FR-NDL-28 — Converge concurrent expansion on one destination

**FAIL**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 567 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Converge concurrent expansion on one destination.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Converge concurrent expansion on one destination
   Expected: Concurrent same-membership expansions return one usable destination without duplicates or partial history

### Expected and observed results

Contract: Concurrent same-membership expansions return one usable destination without duplicates or partial history

Observed: Every concurrent expansion must return a usable existing/new destination

Failing step: Exact step index not captured by the original runner; inspect diagnostic and definition.

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: APPLICATION\_DEFECT\_RECORDED

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner recorded a non-passing case. Later actions may not have been reached; diagnostic evidence is shown without changing its classification.

Inferred consequence, not an observed production/UI incident: the described Needl group conversations scenario is not fully verified. The diagnostic identifies the observed failure; its wider impact requires investigation.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>Every concurrent expansion must return a usable existing/new destination</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:825; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-28&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      await seed(c, g._id, f.people.A, [{}]);
      const settled = await Promise.allSettled([
        expand(c, f, g._id, [&quot;D&quot;], &quot;all&quot;),
        expand(c, f, g._id, [&quot;D&quot;], &quot;all&quot;),
      ]);
      assert.ok(
        settled.every((r) =&gt; r.status === &quot;fulfilled&quot;),
        &quot;Every concurrent expansion must return a usable existing/new destination&quot;,
      );
      const ids = settled.map((r) =&gt; r.value.data.channel._id);
      assert.equal(new Set(ids).size, 1);
      assert.equal((await rows(c, ids[0])).length, 1);
      const count = await c.db((db) =&gt;
        db
          .collection(&quot;channels&quot;)
          .countDocuments({
            type: &quot;direct&quot;,
            members: {
              $all: [...members(g), f.people.D.userId].map(
                (id) =&gt; new db.base.Types.ObjectId(id),
              ),
              $size: 4,
            },
          }),
      );
      assert.equal(count, 1);
    },
  },
  {</pre>

## FR-NDL-29 — Recover history copy after a database write failure

**FAIL**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 635 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Recover history copy after a database write failure.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Recover history copy after a database write failure
   Expected: Fault returns bounded error; after fixture fault removed, retry returns complete intended history without duplicates; source unchanged

### Expected and observed results

Contract: Fault returns bounded error; after fixture fault removed, retry returns complete intended history without duplicates; source unchanged

Observed: Retry must recover intended history after the database fault is removed

0 \!== 1


Failing step: Exact step index not captured by the original runner; inspect diagnostic and definition.

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: APPLICATION\_DEFECT\_RECORDED

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner recorded a non-passing case. Later actions may not have been reached; diagnostic evidence is shown without changing its classification.

Inferred consequence, not an observed production/UI incident: the described Needl group conversations scenario is not fully verified. The diagnostic identifies the observed failure; its wider impact requires investigation.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>Retry must recover intended history after the database fault is removed

0 !== 1
</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:858; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-29&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      const g = await f.create();
      const source = await seed(c, g._id, f.people.A, [
        { content: { text: &quot;Synthetic unique copy recovery&quot; } },
      ]);
      await c.db((db) =&gt;
        db
          .collection(&quot;messages&quot;)
          .createIndex(
            { &quot;content.text&quot;: 1 },
            {
              name: &quot;needl_copy_fault&quot;,
              unique: true,
              partialFilterExpression: { &quot;content.text&quot;: { $type: &quot;string&quot; } },
            },
          ),
      );
      let failed = false;
      try {
        await expand(c, f, g._id, [&quot;D&quot;], &quot;all&quot;);
      } catch (e) {
        assert.ok([400, 500].includes(e.detail?.status));
        failed = true;
      } finally {
        await c.db((db) =&gt;
          db.collection(&quot;messages&quot;).dropIndex(&quot;needl_copy_fault&quot;),
        );
      }
      assert.ok(failed, &quot;Fault fixture must interrupt copy&quot;);
      const retry = (await expand(c, f, g._id, [&quot;D&quot;], &quot;all&quot;)).data.channel;
      assert.equal(
        (await rows(c, retry._id)).length,
        source.length,
        &quot;Retry must recover intended history after the database fault is removed&quot;,
      );
      assert.equal((await rows(c, g._id)).length, 1);
    },
  },
  {</pre>

## FR-NDL-30 — Keep group participation distinct from accepted pair consent

**PASS**; module NDL; tier B; priority P0; owner UNASSIGNED; attempted true; duration 544 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Keep group participation distinct from accepted pair consent.

### Prerequisites and reproduction

Use U, default general/emergency/academics channels, public X and private Y \(A only\), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.

API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.

1. Keep group participation distinct from accepted pair consent
   Expected: Group membership alone cannot create an accepted one-to-one DM; no hidden pair channel appears

### Expected and observed results

Contract: Group membership alone cannot create an accepted one-to-one DM; no hidden pair channel appears

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

tests/functional-regression/suites/needl.mjs:899; SHA-256 5edfebe389d7ff43decefa6e442e2f5bc578f9af2bf80e641aa6bf5fae4b1175

<pre>    id: &quot;FR-NDL-30&quot;,
    run: async (c) =&gt; {
      const f = await fixture(c);
      await f.create();
      const before = await snapshot(c);
      const response = await c.request(&quot;/api/channels/dm&quot;, {
        method: &quot;POST&quot;,
        token: [REDACTED],
        body: { userId: f.people.C.userId },
        expectedStatus: 403,
      });
      assert.equal(response.payload.success, false);
      assert.deepEqual(await snapshot(c), before);
    },
  },
];
for (const test of cases)
  await runModule(&quot;needl-&quot; + test.id.slice(-2), [{ ...test, module: &quot;NDL&quot; }]);
</pre>

## FR-NDL-31 — Classify and label Needls consistently

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 30 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Classify and label Needls consistently.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Classify and label Needls consistently
   Expected: 1:1, self notes and space channels excluded; 3+ members or server group flag included; custom names, stale single-peer names and fallback labels correct

### Expected and observed results

Contract: 1:1, self notes and space channels excluded; 3+ members or server group flag included; custom names, stale single-peer names and fallback labels correct

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:286; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  test(&#39;FR-NDL-31 classify and label actual Needl models&#39;, () {
    for (final n in [1, 2])
      expect(
          ChannelModel.fromJson({
            ...group(),
            &#39;isNeedl&#39;: false,
            &#39;members&#39;: List.generate(n, (i) =&gt; user(&#39;$i&#39;))
          }).isGroupDm,
          false);
    expect(ChannelModel.fromJson({...group(), &#39;spaceId&#39;: &#39;space&#39;}).isGroupDm,
        false);
    expect(ChannelModel.fromJson({...group(), &#39;members&#39;: []}).isGroupDm, true);
    expect(ChannelModel.fromJson(group()).displayName, &#39;Night Team&#39;);
    final stale = ChannelModel.fromJson({...group(), &#39;name&#39;: &#39;Doctor B&#39;});
    expect(stale.displayName, contains(&#39;Doctor C&#39;));
    expect(stale.displayName, isNot(&#39;Doctor B&#39;));
    expect(
        ChannelModel.fromJson({...group(), &#39;name&#39;: &#39;channel&#39;, &#39;members&#39;: []})
            .displayName,
        &#39;Needl&#39;);
    expect(stale.copyWith(name: &#39;Custom&#39;).displayName, &#39;Custom&#39;);
    expect(stale.copyWith(name: &#39;Custom&#39;).members, stale.members);
  });</pre>

## FR-NDL-32 — Create group through real client repository

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 10 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Create group through real client repository.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Create group through real client repository
   Expected: Exact primary endpoint/body and parsed group identity/members; no fake server correctness claim

### Expected and observed results

Contract: Exact primary endpoint/body and parsed group identity/members; no fake server correctness claim

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:309; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  test(&#39;FR-NDL-32 create group repository contract&#39;, () async {
    final result = await channels.createGroupDm([&#39;B&#39;, &#39;C&#39;]);
    expect(result.id, &#39;created&#39;);
    expect(result.isGroupDm, true);
    expect(creates().single.data, {
      &#39;userIds&#39;: [&#39;B&#39;, &#39;C&#39;]
    });
    expect(result.members.map((u) =&gt; u.id), [&#39;A&#39;, &#39;B&#39;, &#39;C&#39;]);
  });</pre>

## FR-NDL-33 — Use legacy creation alias only for not-found

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 21 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Use legacy creation alias only for not-found.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Use legacy creation alias only for not-found
   Expected: 404 triggers exactly one alias call; validation/forbidden/server failures propagate without fallback mutations

### Expected and observed results

Contract: 404 triggers exactly one alias call; validation/forbidden/server failures propagate without fallback mutations

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:318; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  test(&#39;FR-NDL-33 alias only on 404, no retry for other failures&#39;, () async {
    transport.handler =
        (r) =&gt; r.path.endsWith(&#39;/dm/group&#39;) ? reply({}, status: 404) : null;
    expect((await channels.createGroupDm([&#39;B&#39;, &#39;C&#39;])).id, &#39;created&#39;);
    expect(creates().map((r) =&gt; r.path.split(&#39;/&#39;).last), [&#39;group&#39;, &#39;group-dm&#39;]);
    for (final status in [400, 403, 500]) {
      transport.calls.clear();
      transport.handler = (r) =&gt; reply({}, status: status);
      await expectLater(
          channels.createGroupDm([&#39;B&#39;, &#39;C&#39;]), throwsA(isA&lt;AppException&gt;()));
      expect(creates().length, 1);
    }
  });</pre>

## FR-NDL-34 — Serialize all history modes and device midnight

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 19 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Serialize all history modes and device midnight.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Serialize all history modes and device midnight
   Expected: All/today/none payloads preserved; only today includes UTC ISO representing local midnight; returned group parsed

### Expected and observed results

Contract: All/today/none payloads preserved; only today includes UTC ISO representing local midnight; returned group parsed

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:331; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  test(&#39;FR-NDL-34 serialize history and phone midnight&#39;, () async {
    for (final mode in [&#39;all&#39;, &#39;today&#39;, &#39;none&#39;]) {
      final before = DateTime.now();
      final result = await channels.expandDm(
          channelId: &#39;g1&#39;, userIds: [&#39;D&#39;], history: mode);
      final after = DateTime.now();
      final payload = expands().last.data as Map;
      expect(payload[&#39;userIds&#39;], [&#39;D&#39;]);
      expect(payload[&#39;history&#39;], mode);
      expect(result.id, &#39;created&#39;);
      if (mode == &#39;today&#39;) {
        final start = DateTime.parse(payload[&#39;todayStart&#39;] as String);
        expect(start.isUtc, true);
        expect([
          DateTime(before.year, before.month, before.day).toUtc(),
          DateTime(after.year, after.month, after.day).toUtc()
        ], contains(start));
      } else
        expect(payload.containsKey(&#39;todayStart&#39;), false);
    }
  });</pre>

## FR-NDL-35 — Parse list detail member and rename contracts

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 16 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Parse list detail member and rename contracts.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Parse list detail member and rename contracts
   Expected: Correct routes/bodies and typed results; malformed data raises a client error, never fabricated empty success

### Expected and observed results

Contract: Correct routes/bodies and typed results; malformed data raises a client error, never fabricated empty success

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:352; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  test(&#39;FR-NDL-35 list detail members rename and malformed response&#39;, () async {
    expect((await channels.getMyDMs()).single.id, &#39;g1&#39;);
    expect((await channels.getChannelMembers(&#39;g1&#39;)).map((u) =&gt; u.id),
        [&#39;A&#39;, &#39;B&#39;, &#39;C&#39;]);
    expect((await channels.renameChannel(&#39;g1&#39;, &#39;Renamed&#39;)).name, &#39;Renamed&#39;);
    expect(transport.calls.last.method, &#39;PUT&#39;);
    expect(transport.calls.last.data, {&#39;name&#39;: &#39;Renamed&#39;});
    await channels.getChannelById(&#39;g1&#39;);
    transport.handler = (r) =&gt; reply({&#39;channel&#39;: null});
    await expectLater(
        channels.getChannelById(&#39;g1&#39;), throwsA(isA&lt;AppException&gt;()));
  });</pre>

## FR-NDL-36 — Separate Needl tab from Direct and space channels

**PASS**; module NDL; tier F; priority P0; owner UNASSIGNED; attempted true; duration 873 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Separate Needl tab from Direct and space channels.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Separate Needl tab from Direct and space channels
   Expected: Only group DMs rendered under Needl with correct group identity, member count, draft preview and per-conversation unread badge; 1:1 stays Direct

### Expected and observed results

Contract: Only group DMs rendered under Needl with correct group identity, member count, draft preview and per-conversation unread badge; 1:1 stays Direct

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:364; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-36 Needl tab excludes pair notes and space channels&#39;,
      (t) async {
    transport.dms = [
      group(),
      {
        ...group(&#39;pair&#39;, [&#39;A&#39;, &#39;B&#39;]),
        &#39;isNeedl&#39;: false,
        &#39;name&#39;: &#39;Pair only&#39;
      },
      {
        ...group(&#39;notes&#39;, [&#39;A&#39;]),
        &#39;isNeedl&#39;: false,
        &#39;name&#39;: &#39;Personal notes&#39;
      },
      {...group(&#39;space&#39;), &#39;spaceId&#39;: &#39;s&#39;, &#39;name&#39;: &#39;Space channel&#39;}
    ];
    transport.handler = (r) =&gt; r.path.endsWith(&#39;/notifications&#39;)
        ? reply({
            &#39;notifications&#39;: [
              for (var i = 0; i &lt; 2; i++)
                {
                  &#39;_id&#39;: &#39;needl-notification-$i&#39;,
                  &#39;type&#39;: &#39;new_message&#39;,
                  &#39;read&#39;: false,
                  &#39;metadata&#39;: {&#39;channelId&#39;: &#39;g1&#39;}
                },
              {
                &#39;_id&#39;: &#39;other-chat&#39;,
                &#39;type&#39;: &#39;new_message&#39;,
                &#39;read&#39;: false,
                &#39;metadata&#39;: {&#39;channelId&#39;: &#39;pair&#39;}
              }
            ],
            &#39;hasMore&#39;: false,
            &#39;unreadCount&#39;: 3
          })
        : null;
    await AppDependencies.instance.draftMessageService
        .saveDraft(&#39;g1&#39;, &#39;Synthetic draft&#39;);
    await mount(t, const MessagesHubPage());
    await t.tap(find.text(&#39;Needl&#39;));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey(&#39;needl-g1&#39;)), findsOneWidget);
    for (final id in [&#39;pair&#39;, &#39;notes&#39;, &#39;space&#39;])
      expect(find.byKey(ValueKey(&#39;needl-$id&#39;)), findsNothing);
    expect(find.textContaining(&#39;3 people&#39;), findsOneWidget);
    expect(find.textContaining(&#39;Draft&#39;), findsWidgets);
    expect(
        t.widget&lt;DMRow&gt;(find.byKey(const ValueKey(&#39;needl-g1&#39;))).unreadCount, 2);
  });</pre>

## FR-NDL-37 — Show Needl empty and error states with recovery

**PASS**; module NDL; tier F; priority P0; owner UNASSIGNED; attempted true; duration 730 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Show Needl empty and error states with recovery.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Show Needl empty and error states with recovery
   Expected: Empty create CTA navigates to Start DM; repository failure shows error; refresh success restores correct group

### Expected and observed results

Contract: Empty create CTA navigates to Start DM; repository failure shows error; refresh success restores correct group

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:414; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-37 empty Needl create and failed load recovery&#39;,
      (t) async {
    transport.dms = [];
    await mount(t, const MessagesHubPage());
    await t.tap(find.text(&#39;Needl&#39;));
    await t.pumpAndSettle();
    expect(find.text(&#39;No Needls yet&#39;), findsOneWidget);
    await t.tap(find.text(&#39;Start a Needl&#39;));
    await t.pumpAndSettle();
    expect(find.byType(StartDmPage), findsOneWidget);
    transport.handler =
        (r) =&gt; r.path.endsWith(&#39;/channels/dm&#39;) ? reply({}, status: 500) : null;
    await mount(t, const MessagesHubPage());
    await t.tap(find.text(&#39;Needl&#39;));
    await t.pumpAndSettle();
    expect(find.text(&#39;Could not load Needls&#39;), findsOneWidget);
    transport.handler = null;
    transport.dms = [group()];
    await mount(t, const MessagesHubPage());
    await t.tap(find.text(&#39;Needl&#39;));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey(&#39;needl-g1&#39;)), findsOneWidget);
  });</pre>

## FR-NDL-38 — Preload only distinct Vocle colleague suggestions

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 128 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Preload only distinct Vocle colleague suggestions.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Preload only distinct Vocle colleague suggestions
   Expected: Self/empty IDs excluded; repeated colleagues deduplicated; no device address-book dependency

### Expected and observed results

Contract: Self/empty IDs excluded; repeated colleagues deduplicated; no device address-book dependency

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:437; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-38 colleague preload excludes self and duplicates&#39;,
      (t) async {
    transport.dms = [
      group(&#39;g1&#39;, [&#39;A&#39;, &#39;B&#39;, &#39;B&#39;, &#39;C&#39;]),
      group(&#39;g2&#39;, [&#39;A&#39;, &#39;C&#39;, &#39;D&#39;])
    ];
    await mount(t, const StartDmPage());
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text(&#39;Doctor A&#39;), findsNothing);
    expect(find.text(&#39;Doctor B&#39;), findsOneWidget);
    expect(find.text(&#39;Doctor C&#39;), findsOneWidget);
    expect(transport.calls.any((r) =&gt; r.path.contains(&#39;contacts&#39;)), false);
  });</pre>

## FR-NDL-39 — Debounce name search and discard stale responses

**FAIL**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 489 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Debounce name search and discard stale responses.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Debounce name search and discard stale responses
   Expected: Two-character Start DM query executes after controlled debounce; newer query results survive older response completion

### Expected and observed results

Contract: Two-character Start DM query executes after controlled debounce; newer query results survive older response completion

Observed: ══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: \_TextWidgetFinder:&lt;Found 0 widgets with text &quot;Doctor Z&quot;: \[\]&gt;
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
\#4      main.&lt;anonymous closure&gt; \(file:///C:/Users/delll/AndroidStudioProjects/Vocle/vocle-needl-regression/medcollab-app/test/functional\_regression/needl\_test.dart:479:5\)
&lt;asynchronous suspension&gt;
\#5      testWidgets.&lt;anonymous closure&gt;.&lt;anonymous closure&gt; \(package:flutter\_test/src/widget\_tester.dart:193:15\)
&lt;asynchronous suspension&gt;
\#6      TestWidgetsFlutterBinding.\_runTestBody \(package:flutter\_test/src/binding.dart:1064:5\)
&lt;asynchronous suspension&gt;
&lt;asynchronous suspension&gt;
\(elided one frame from package:stack\_trace\)

This was caught by the test expectation on the following line:
  file:///C:/Users/delll/AndroidStudioProjects/Vocle/vocle-needl-regression/medcollab-app/test/functional\_regression/needl\_test.dart line 479
The test description was:
  FR-NDL-39 Start DM debounce and stale response ordering
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: FR-NDL-39 Start DM debounce and stale response ordering

Failing step: Exact step index not captured by the original runner; inspect diagnostic and definition.

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: APPLICATION\_DEFECT\_RECORDED

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner recorded a non-passing case. Later actions may not have been reached; diagnostic evidence is shown without changing its classification.

Inferred consequence, not an observed production/UI incident: the described Needl group conversations scenario is not fully verified. The diagnostic identifies the observed failure; its wider impact requires investigation.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:&lt;Found 0 widgets with text &quot;Doctor Z&quot;: []&gt;
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.&lt;anonymous closure&gt; (file:///C:/Users/delll/AndroidStudioProjects/Vocle/vocle-needl-regression/medcollab-app/test/functional_regression/needl_test.dart:479:5)
&lt;asynchronous suspension&gt;
#5      testWidgets.&lt;anonymous closure&gt;.&lt;anonymous closure&gt; (package:flutter_test/src/widget_tester.dart:193:15)
&lt;asynchronous suspension&gt;
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1064:5)
&lt;asynchronous suspension&gt;
&lt;asynchronous suspension&gt;
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///C:/Users/delll/AndroidStudioProjects/Vocle/vocle-needl-regression/medcollab-app/test/functional_regression/needl_test.dart line 479
The test description was:
  FR-NDL-39 Start DM debounce and stale response ordering
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: FR-NDL-39 Start DM debounce and stale response ordering</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:450; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-39 Start DM debounce and stale response ordering&#39;,
      (t) async {
    final old = Completer&lt;ResponseBody&gt;();
    transport.handler = (r) {
      if (r.path.endsWith(&#39;/users/search&#39;))
        return r.queryParameters[&#39;q&#39;] == &#39;Be&#39;
            ? old.future
            : reply({
                &#39;users&#39;: [user(&#39;Z&#39;)]
              });
      return null;
    };
    await mount(t, const StartDmPage());
    final input = find.byType(TextField).first;
    await t.enterText(input, &#39;Be&#39;);
    await t.pump(const Duration(milliseconds: 199));
    expect(transport.calls.where((r) =&gt; r.path.endsWith(&#39;/users/search&#39;)),
        isEmpty);
    await t.pump(const Duration(milliseconds: 2));
    await t.enterText(input, &#39;Ze&#39;);
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.text(&#39;Doctor Z&#39;), findsOneWidget,
        reason:
            &#39;New query must already be displayed before completing the older response&#39;);
    old.complete(reply({
      &#39;users&#39;: [user(&#39;B&#39;)]
    }));
    await t.pumpAndSettle();
    expect(find.text(&#39;Doctor Z&#39;), findsOneWidget);
    expect(find.text(&#39;Doctor B&#39;), findsNothing);
  });</pre>

## FR-NDL-40 — Distinguish search failure and restore suggestions

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 258 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Distinguish search failure and restore suggestions.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Distinguish search failure and restore suggestions
   Expected: Visible error on failure; clearing search restores known colleagues rather than stale failed results

### Expected and observed results

Contract: Visible error on failure; clearing search restores known colleagues rather than stale failed results

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:482; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-40 name search error and clear restore colleagues&#39;,
      (t) async {
    transport.handler =
        (r) =&gt; r.path.endsWith(&#39;/users/search&#39;) ? reply({}, status: 500) : null;
    await mount(t, const StartDmPage());
    await t.enterText(find.byType(TextField).first, &#39;failed&#39;);
    await t.pump(const Duration(milliseconds: 250));
    await t.pumpAndSettle();
    expect(find.text(&#39;Could not search colleagues&#39;), findsOneWidget);
    await t.enterText(find.byType(TextField).first, &#39;&#39;);
    await t.pumpAndSettle();
    expect(find.text(&#39;Your Vocle colleagues&#39;), findsOneWidget);
    expect(find.text(&#39;Could not search colleagues&#39;), findsNothing);
  });</pre>

## FR-NDL-41 — Create Needl from exact selected colleagues

**PASS**; module NDL; tier F; priority P0; owner UNASSIGNED; attempted true; duration 710 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Create Needl from exact selected colleagues.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Create Needl from exact selected colleagues
   Expected: Two selected colleague IDs submitted once; resulting group route uses returned ID; stale 1:1 response cannot navigate as Needl

### Expected and observed results

Contract: Two selected colleague IDs submitted once; resulting group route uses returned ID; stale 1:1 response cannot navigate as Needl

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:496; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-41 exact selection and stale pair navigation guard&#39;,
      (t) async {
    await mount(t, const StartDmPage());
    await chooseTwo(t);
    transport.handler = (r) =&gt; r.path.endsWith(&#39;/dm/group&#39;)
        ? reply({
            &#39;channel&#39;: {
              ...group(&#39;stale&#39;, [&#39;A&#39;, &#39;B&#39;]),
              &#39;isNeedl&#39;: false
            }
          })
        : null;
    await t.tap(find.text(&#39;Create Needl&#39;).last);
    await t.pumpAndSettle();
    expect(creates().single.data, {
      &#39;userIds&#39;: [&#39;B&#39;, &#39;C&#39;]
    });
    expect(find.textContaining(&#39;at least 2 other people&#39;), findsOneWidget);
    expect(find.text(&#39;Opened stale&#39;), findsNothing);
    transport.handler = null;
    await t.tap(find.text(&#39;Create Needl&#39;).last);
    await t.pumpAndSettle();
    expect(find.text(&#39;Opened created&#39;), findsOneWidget);
  });</pre>

## FR-NDL-42 — Retain selected colleagues after create failure

**PASS**; module NDL; tier F; priority P0; owner UNASSIGNED; attempted true; duration 437 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Retain selected colleagues after create failure.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Retain selected colleagues after create failure
   Expected: Error visible; selected identities retained; retry succeeds; duplicate in-flight taps do not create extra requests

### Expected and observed results

Contract: Error visible; selected identities retained; retry succeeds; duplicate in-flight taps do not create extra requests

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:520; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-42 create failure retains selection then retry once&#39;,
      (t) async {
    var fail = true;
    transport.handler = (r) =&gt;
        r.path.endsWith(&#39;/dm/group&#39;) &amp;&amp; fail ? reply({}, status: 500) : null;
    await mount(t, const StartDmPage());
    await chooseTwo(t);
    await t.tap(find.text(&#39;Create Needl&#39;).last);
    await t.pumpAndSettle();
    expect(
        find
            .byType(Checkbox)
            .evaluate()
            .where((e) =&gt; (e.widget as Checkbox).value == true)
            .length,
        2);
    fail = false;
    await t.tap(find.text(&#39;Create Needl&#39;).last);
    await t.pumpAndSettle();
    expect(creates().length, 2);
    expect(find.text(&#39;Opened created&#39;), findsOneWidget);
  });</pre>

## FR-NDL-43 — Create multiple Needls without selection leakage

**PASS**; module NDL; tier F; priority P0; owner UNASSIGNED; attempted true; duration 466 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Create multiple Needls without selection leakage.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Create multiple Needls without selection leakage
   Expected: Fresh creation screen starts unselected; second selection submits a distinct exact set and opens its own returned group

### Expected and observed results

Contract: Fresh creation screen starts unselected; second selection submits a distinct exact set and opens its own returned group

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:542; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-43 second creation has fresh selection&#39;, (t) async {
    var creation = 0;
    transport.handler = (r) =&gt; r.path.endsWith(&#39;/dm/group&#39;)
        ? reply({&#39;channel&#39;: group(++creation == 1 ? &#39;first&#39; : &#39;second&#39;)})
        : null;
    final router = await mount(t, const StartDmPage());
    await chooseTwo(t);
    await t.tap(find.text(&#39;Create Needl&#39;).last);
    await t.pumpAndSettle();
    expect(find.text(&#39;Opened first&#39;), findsOneWidget);
    router.go(AppRoutes.startDm);
    await t.pumpAndSettle();
    expect(
        find
            .byType(Checkbox)
            .evaluate()
            .every((e) =&gt; (e.widget as Checkbox).value == false),
        true);
    await t.tap(find.byType(Checkbox).at(1));
    await t.pump();
    await t.tap(find.byType(Checkbox).at(2));
    await t.pump();
    await t.tap(find.text(&#39;Create Needl&#39;).last);
    await t.pumpAndSettle();
    expect(creates().last.data, {
      &#39;userIds&#39;: [&#39;C&#39;, &#39;D&#39;]
    });
    expect(creates().first.data, {
      &#39;userIds&#39;: [&#39;B&#39;, &#39;C&#39;]
    });
    expect(find.text(&#39;Opened second&#39;), findsOneWidget);
  });</pre>

## FR-NDL-44 — Preload add-people suggestions safely

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 172 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Preload add-people suggestions safely.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Preload add-people suggestions safely
   Expected: Sorted distinct colleagues; exclude self/existing/empty IDs; suggestions render without typing

### Expected and observed results

Contract: Sorted distinct colleagues; exclude self/existing/empty IDs; suggestions render without typing

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:574; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-44 add people preload sorted distinct eligible only&#39;,
      (t) async {
    transport.dms = [
      group(&#39;s&#39;, [&#39;E&#39;, &#39;D&#39;, &#39;D&#39;, &#39;A&#39;, &#39;B&#39;])
    ];
    await openAdd(t);
    expect(find.widgetWithText(CheckboxListTile, &#39;Doctor D&#39;), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, &#39;Doctor E&#39;), findsOneWidget);
    for (final id in [&#39;A&#39;, &#39;B&#39;, &#39;C&#39;])
      expect(find.widgetWithText(CheckboxListTile, &#39;Doctor $id&#39;), findsNothing);
    expect(t.getTopLeft(find.text(&#39;Doctor D&#39;)).dy,
        lessThan(t.getTopLeft(find.text(&#39;Doctor E&#39;)).dy));
  });</pre>

## FR-NDL-45 — Discard stale add-people search responses

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 236 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Discard stale add-people search responses.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Discard stale add-people search responses
   Expected: Controlled debounce and out-of-order completions keep only latest query results

### Expected and observed results

Contract: Controlled debounce and out-of-order completions keep only latest query results

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:587; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-45 add people one-character debounce and latest search&#39;,
      (t) async {
    final old = Completer&lt;ResponseBody&gt;();
    transport.handler = (r) =&gt; r.path.endsWith(&#39;/users/search&#39;)
        ? (r.queryParameters[&#39;q&#39;] == &#39;d&#39;
            ? old.future
            : reply({
                &#39;users&#39;: [user(&#39;E&#39;)]
              }))
        : null;
    await openAdd(t);
    final input = find.byType(TextField).first;
    await t.enterText(input, &#39;d&#39;);
    await t.pump(const Duration(milliseconds: 201));
    await t.enterText(input, &#39;e&#39;);
    await t.pump(const Duration(milliseconds: 201));
    await t.pump();
    old.complete(reply({
      &#39;users&#39;: [user(&#39;D&#39;)]
    }));
    await t.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, &#39;Doctor E&#39;), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, &#39;Doctor D&#39;), findsNothing);
  });</pre>

## FR-NDL-46 — Normalize add-people phone lookup and filter forbidden selections

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 234 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Normalize add-people phone lookup and filter forbidden selections.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Normalize add-people phone lookup and filter forbidden selections
   Expected: Phone normalized correctly; self and existing members not selectable; eligible lookup result shown

### Expected and observed results

Contract: Phone normalized correctly; self and existing members not selectable; eligible lookup result shown

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:611; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-46 add people phone normalization and existing exclusion&#39;,
      (t) async {
    await openAdd(t);
    await t.enterText(find.byType(TextField).first, &#39;9000000001&#39;);
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    final lookup =
        transport.calls.singleWhere((r) =&gt; r.path.contains(&#39;lookup&#39;));
    expect(jsonEncode(lookup.queryParameters) + jsonEncode(lookup.data),
        contains(&#39;+919000000001&#39;));
    expect(find.widgetWithText(CheckboxListTile, &#39;Doctor E&#39;), findsOneWidget);
    transport.handler = (r) =&gt; r.path.contains(&#39;lookup&#39;)
        ? reply({
            &#39;user&#39;: user(&#39;B&#39;),
            &#39;canMessage&#39;: true,
            &#39;canRequest&#39;: false,
            &#39;relationship&#39;: &#39;connected&#39;
          })
        : null;
    await t.enterText(find.byType(TextField).first, &#39;9000000002&#39;);
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
  });</pre>

## FR-NDL-47 — Expose add-people search failures and recover

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 219 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Expose add-people search failures and recover.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Expose add-people search failures and recover
   Expected: Failure shown as error, not empty result; subsequent successful query restores choices

### Expected and observed results

Contract: Failure shown as error, not empty result; subsequent successful query restores choices

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:635; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-47 add people search failure is not empty success&#39;,
      (t) async {
    var fail = true;
    transport.handler = (r) =&gt; r.path.endsWith(&#39;/users/search&#39;)
        ? (fail
            ? reply({}, status: 500)
            : reply({
                &#39;users&#39;: [user(&#39;E&#39;)]
              }))
        : null;
    await openAdd(t);
    await t.enterText(find.byType(TextField).first, &#39;e&#39;);
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.text(&#39;Synthetic failure&#39;), findsOneWidget);
    expect(find.text(&#39;No colleagues found&#39;), findsNothing);
    fail = false;
    await t.enterText(find.byType(TextField).first, &#39;el&#39;);
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, &#39;Doctor E&#39;), findsOneWidget);
  });</pre>

## FR-NDL-48 — Maintain selected chips across queries

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 222 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Maintain selected chips across queries.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Maintain selected chips across queries
   Expected: Selections retained while searching; deleting chip removes exact ID; empty selection disables submit

### Expected and observed results

Contract: Selections retained while searching; deleting chip removes exact ID; empty selection disables submit

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:657; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-48 selected chips persist and delete disables submit&#39;,
      (t) async {
    await openAdd(t);
    await t.tap(find.widgetWithText(CheckboxListTile, &#39;Doctor D&#39;));
    await t.pump();
    expect(find.byType(InputChip), findsOneWidget);
    await t.enterText(find.byType(TextField).first, &#39;unknown&#39;);
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.byType(InputChip), findsOneWidget);
    final chip = t.widget&lt;InputChip&gt;(find.byType(InputChip));
    chip.onDeleted!();
    await t.pump();
    expect(find.byType(InputChip), findsNothing);
    expect(
        t
            .widget&lt;FilledButton&gt;(
                find.widgetWithText(FilledButton, &#39;Add to Needl&#39;))
            .onPressed,
        isNull);
  });</pre>

## FR-NDL-49 — Select history options and cancel safely

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 169 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Select history options and cancel safely.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Select history options and cancel safely
   Expected: Default all; today/none map to correct expansion payload; cancel/dispose produces no mutation or dangling timer error

### Expected and observed results

Contract: Default all; today/none map to correct expansion payload; cancel/dispose produces no mutation or dangling timer error

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:678; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-49 history selection and cancellation never submit&#39;,
      (t) async {
    await openAdd(t);
    expect(
        t
            .widget&lt;RadioListTile&lt;String&gt;&gt;(
                find.widgetWithText(RadioListTile&lt;String&gt;, &#39;Entire history&#39;))
            .groupValue,
        &#39;all&#39;);
    await t.tap(find.text(&#39;No history&#39;));
    await t.pump();
    expect(
        t
            .widget&lt;RadioListTile&lt;String&gt;&gt;(
                find.widgetWithText(RadioListTile&lt;String&gt;, &#39;No history&#39;))
            .groupValue,
        &#39;none&#39;);
    await t.tap(find.text(&#39;From today&#39;));
    await t.pump();
    expect(
        t
            .widget&lt;RadioListTile&lt;String&gt;&gt;(
                find.widgetWithText(RadioListTile&lt;String&gt;, &#39;From today&#39;))
            .groupValue,
        &#39;today&#39;);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(expands(), isEmpty);
    expect(t.takeException(), isNull);
  });</pre>

## FR-NDL-50 — Recover add-people submission and block double taps

**FAIL**; module NDL; tier F; priority P0; owner UNASSIGNED; attempted true; duration 406 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Recover add-people submission and block double taps.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Recover add-people submission and block double taps
   Expected: Failed expansion retains sheet/history/selection; pending submission disabled; one successful retry navigates to returned group

### Expected and observed results

Contract: Failed expansion retains sheet/history/selection; pending submission disabled; one successful retry navigates to returned group

Observed: ══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following GoError was thrown running a test:
There is no GoRouterState above the current context. This method should only be called under the sub
tree of a RouteBase.builder.

When the exception was thrown, this was the stack:
\#0      GoRouterState.of \(package:go\_router/src/state.dart:124:9\)
\#1      openDmChat \(package:medcollab\_app/core/router/dm\_navigation.dart:17:33\)
\#2      showAddNeedlPeopleSheet.&lt;anonymous closure&gt;.&lt;anonymous closure&gt;.submit \(package:medcollab\_app/features/messages/presentation/widgets/needl\_manage\_sheets.dart:208:15\)
&lt;asynchronous suspension&gt;

The test description was:
  FR-NDL-50 expansion pending duplicate taps failure and retry
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test \(but after the test had completed\):
Expected: exactly one matching candidate
  Actual: \_TextWidgetFinder:&lt;Found 0 widgets with text &quot;Opened created&quot;: \[\]&gt;
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
\#0      fail \(package:matcher/src/expect/expect.dart:149:31\)
\#1      \_expect \(package:matcher/src/expect/expect.dart:144:3\)
\#2      expect \(package:matcher/src/expect/expect.dart:56:3\)
\#3      expect \(package:flutter\_test/src/widget\_tester.dart:474:18\)
\#4      main.&lt;anonymous closure&gt; \(file:///C:/Users/delll/AndroidStudioProjects/Vocle/vocle-needl-regression/medcollab-app/test/functional\_regression/needl\_test.dart:737:5\)
&lt;asynchronous suspension&gt;
\#5      testWidgets.&lt;anonymous closure&gt;.&lt;anonymous closure&gt; \(package:flutter\_test/src/widget\_tester.dart:193:15\)
&lt;asynchronous suspension&gt;
\#6      TestWidgetsFlutterBinding.\_runTestBody \(package:flutter\_test/src/binding.dart:1064:5\)
&lt;asynchronous suspension&gt;
&lt;asynchronous suspension&gt;
\(elided one frame from package:stack\_trace\)
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: FR-NDL-50 expansion pending duplicate taps failure and retry
Test failed. See exception logs above.
The test description was: FR-NDL-50 expansion pending duplicate taps failure and retry

Failing step: Exact step index not captured by the original runner; inspect diagnostic and definition.

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: APPLICATION\_DEFECT\_RECORDED

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner recorded a non-passing case. Later actions may not have been reached; diagnostic evidence is shown without changing its classification.

Inferred consequence, not an observed production/UI incident: the described Needl group conversations scenario is not fully verified. The diagnostic identifies the observed failure; its wider impact requires investigation.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following GoError was thrown running a test:
There is no GoRouterState above the current context. This method should only be called under the sub
tree of a RouteBase.builder.

When the exception was thrown, this was the stack:
#0      GoRouterState.of (package:go_router/src/state.dart:124:9)
#1      openDmChat (package:medcollab_app/core/router/dm_navigation.dart:17:33)
#2      showAddNeedlPeopleSheet.&lt;anonymous closure&gt;.&lt;anonymous closure&gt;.submit (package:medcollab_app/features/messages/presentation/widgets/needl_manage_sheets.dart:208:15)
&lt;asynchronous suspension&gt;

The test description was:
  FR-NDL-50 expansion pending duplicate taps failure and retry
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test (but after the test had completed):
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:&lt;Found 0 widgets with text &quot;Opened created&quot;: []&gt;
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#0      fail (package:matcher/src/expect/expect.dart:149:31)
#1      _expect (package:matcher/src/expect/expect.dart:144:3)
#2      expect (package:matcher/src/expect/expect.dart:56:3)
#3      expect (package:flutter_test/src/widget_tester.dart:474:18)
#4      main.&lt;anonymous closure&gt; (file:///C:/Users/delll/AndroidStudioProjects/Vocle/vocle-needl-regression/medcollab-app/test/functional_regression/needl_test.dart:737:5)
&lt;asynchronous suspension&gt;
#5      testWidgets.&lt;anonymous closure&gt;.&lt;anonymous closure&gt; (package:flutter_test/src/widget_tester.dart:193:15)
&lt;asynchronous suspension&gt;
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1064:5)
&lt;asynchronous suspension&gt;
&lt;asynchronous suspension&gt;
(elided one frame from package:stack_trace)
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: FR-NDL-50 expansion pending duplicate taps failure and retry
Test failed. See exception logs above.
The test description was: FR-NDL-50 expansion pending duplicate taps failure and retry</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:708; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-50 expansion pending duplicate taps failure and retry&#39;,
      (t) async {
    final pending = Completer&lt;ResponseBody&gt;();
    var first = true;
    transport.handler =
        (r) =&gt; r.path.endsWith(&#39;/expand&#39;) &amp;&amp; first ? pending.future : null;
    await openAdd(t);
    await t.tap(find.widgetWithText(CheckboxListTile, &#39;Doctor D&#39;));
    await t.pump();
    await t.tap(find.text(&#39;No history&#39;));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, &#39;Add to Needl&#39;));
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
    expect(expands().length, 1);
    expect(t.widget&lt;FilledButton&gt;(find.byType(FilledButton).last).onPressed,
        isNull);
    pending.complete(reply({}, status: 500));
    await t.pumpAndSettle();
    expect(find.byType(InputChip), findsOneWidget);
    expect(find.text(&#39;Synthetic failure&#39;), findsOneWidget);
    first = false;
    await t.tap(find.widgetWithText(FilledButton, &#39;Add to Needl&#39;));
    await t.pumpAndSettle();
    expect(expands().length, 2);
    expect((expands().last.data as Map)[&#39;history&#39;], &#39;none&#39;);
    expect(t.takeException(), isNull,
        reason:
            &#39;Successful expansion must navigate using a valid route context&#39;);
    expect(find.text(&#39;Opened created&#39;), findsOneWidget);
  });</pre>

## FR-NDL-51 — Cancel or save rename with bounded trimmed input

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 244 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Cancel or save rename with bounded trimmed input.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Cancel or save rename with bounded trimmed input
   Expected: Cancel no API request; max 80 chars enforced; save trimmed name and correct group ID; success acknowledged

### Expected and observed results

Contract: Cancel no API request; max 80 chars enforced; save trimmed name and correct group ID; success acknowledged

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:739; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-51 rename cancel trimming and 80 character bound&#39;,
      (t) async {
    await mount(t, launcher());
    await t.tap(find.text(&#39;Rename&#39;));
    await t.pumpAndSettle();
    await t.tap(find.text(&#39;Cancel&#39;));
    await t.pumpAndSettle();
    expect(transport.calls.where((r) =&gt; r.method == &#39;PUT&#39;), isEmpty);
    await t.tap(find.text(&#39;Rename&#39;));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), &#39;N&#39; * 81);
    expect(t.widget&lt;TextField&gt;(find.byType(TextField)).controller!.text.length,
        80);
    await t.enterText(find.byType(TextField), &#39;  Updated team  &#39;);
    await t.tap(find.text(&#39;Save&#39;));
    await t.pumpAndSettle();
    expect(transport.calls.singleWhere((r) =&gt; r.method == &#39;PUT&#39;).data,
        {&#39;name&#39;: &#39;Updated team&#39;});
    expect(find.text(&#39;Needl renamed&#39;), findsOneWidget);
  });</pre>

## FR-NDL-52 — Show rename error without claiming success

**PASS**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 115 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Show rename error without claiming success.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Show rename error without claiming success
   Expected: Server error visible; no success snackbar or false local title update; original group identity retained

### Expected and observed results

Contract: Server error visible; no success snackbar or false local title update; original group identity retained

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:759; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-52 rename error never shows success&#39;, (t) async {
    transport.handler =
        (r) =&gt; r.method == &#39;PUT&#39; ? reply({}, status: 500) : null;
    await mount(t, launcher());
    await t.tap(find.text(&#39;Rename&#39;));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), &#39;Failed name&#39;);
    await t.tap(find.text(&#39;Save&#39;));
    await t.pumpAndSettle();
    expect(find.text(&#39;Synthetic failure&#39;), findsOneWidget);
    expect(find.text(&#39;Needl renamed&#39;), findsNothing);
    expect(transport.calls.singleWhere((r) =&gt; r.method == &#39;PUT&#39;).path,
        endsWith(&#39;/g1&#39;));
  });</pre>

## FR-NDL-53 — Display Needl members in stable self-first order

**FAIL**; module NDL; tier F; priority P1; owner UNASSIGNED; attempted true; duration 121 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Display Needl members in stable self-first order.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Display Needl members in stable self-first order
   Expected: Self first then case-insensitive name order; correct count/roles/presence; original members list not mutated

### Expected and observed results

Contract: Self first then case-insensitive name order; correct count/roles/presence; original members list not mutated

Observed: ══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 91 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///C:/Users/delll/AndroidStudioProjects/Vocle/vocle-needl-regression/medcollab-app/lib/features/messages/presentation/widgets/needl\_manage\_sheets.dart:428:18

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor \(e.g. using an Expanded widget\) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex\#94442 relayoutBoundary=up11 OVERFLOWING:
  needs compositing
  creator: Column ← Padding ← MediaQuery ← Padding ← SafeArea ← Padding ← Stack ←
    NotificationListener&lt;DraggableScrollableNotification&gt; ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← \_InkFeatures-\[GlobalKey\#f0f1a ink renderer\] ←
    NotificationListener&lt;LayoutChangedNotification&gt; ← ⋯
  parentData: offset=Offset\(8.0, 0.0\) \(can use size\)
  constraints: BoxConstraints\(0.0&lt;=w&lt;=624.0, 0.0&lt;=h&lt;=948.5\)
  size: Size\(624.0, 948.5\)
  direction: vertical
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: stretch
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: FR-NDL-53 self-first members count roles and presence

Failing step: Exact step index not captured by the original runner; inspect diagnostic and definition.

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: APPLICATION\_DEFECT\_RECORDED

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner recorded a non-passing case. Later actions may not have been reached; diagnostic evidence is shown without changing its classification.

Inferred consequence, not an observed production/UI incident: the described Needl group conversations scenario is not fully verified. The diagnostic identifies the observed failure; its wider impact requires investigation.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 91 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///C:/Users/delll/AndroidStudioProjects/Vocle/vocle-needl-regression/medcollab-app/lib/features/messages/presentation/widgets/needl_manage_sheets.dart:428:18

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#94442 relayoutBoundary=up11 OVERFLOWING:
  needs compositing
  creator: Column ← Padding ← MediaQuery ← Padding ← SafeArea ← Padding ← Stack ←
    NotificationListener&lt;DraggableScrollableNotification&gt; ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#f0f1a ink renderer] ←
    NotificationListener&lt;LayoutChangedNotification&gt; ← ⋯
  parentData: offset=Offset(8.0, 0.0) (can use size)
  constraints: BoxConstraints(0.0&lt;=w&lt;=624.0, 0.0&lt;=h&lt;=948.5)
  size: Size(624.0, 948.5)
  direction: vertical
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: stretch
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
Test failed. See exception logs above.
The test description was: FR-NDL-53 self-first members count roles and presence</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:773; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-53 self-first members count roles and presence&#39;,
      (t) async {
    presence.mergeApiSnapshot({&#39;B&#39;: const PresenceInfo(isOnline: true)});
    await mount(t, launcher());
    await t.tap(find.text(&#39;Members&#39;));
    await t.pumpAndSettle();
    expect(find.text(&#39;Night Team · 3 people&#39;), findsOneWidget);
    expect(t.getTopLeft(find.text(&#39;Doctor A (you)&#39;)).dy,
        lessThan(t.getTopLeft(find.text(&#39;Doctor B&#39;)).dy));
    expect(t.getTopLeft(find.text(&#39;Doctor B&#39;)).dy,
        lessThan(t.getTopLeft(find.text(&#39;Doctor C&#39;)).dy));
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(
        t
            .widget&lt;ListTile&gt;(find.widgetWithText(ListTile, &#39;Doctor A (you)&#39;))
            .onTap,
        isNull);
    expect(
        find
            .byType(AppAvatar)
            .evaluate()
            .map((e) =&gt; e.widget as AppAvatar)
            .any((a) =&gt; a.isOnline),
        true);
  });</pre>

## FR-NDL-54 — Render group chat identity and group-only menu

**PASS**; module NDL; tier F; priority P0; owner UNASSIGNED; attempted true; duration 323 ms.

Source 4765df8b89912dcb48f377fc184f83041f0decc0; harness 4765df8b89912dcb48f377fc184f83041f0decc0.

### Real-life scenario

Doctors create, manage and communicate within a private Needl group conversation. Scenario: Render group chat identity and group-only menu.

### Prerequisites and reproduction

Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.

Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.

1. Render group chat identity and group-only menu
   Expected: Needl title not overwritten by first peer; member count and rename/people options shown; sender identity rendered for group message

### Expected and observed results

Contract: Needl title not overwritten by first peer; member count and rename/people options shown; sender identity rendered for group message

Observed: The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

Failing step: None reported

Assertion expected: Individual assertion expected value not captured; use the case contract and definition.

Assertion actual: Individual actual value not captured beyond the diagnostic above.

Classification: PASS

Root cause: UNKNOWN. This report does not infer a root cause from a status or similar message.

The runner reports that this case completed successfully. The executable checks below define its verified scope; individual intermediate values were not recorded unless shown in the evidence.

This recorded execution protects the described scenario within its stated scope.

Explicit subassertion evidence: \[\]

Scope/limitations: Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.

Product questions: none linked

Evidence files: No additional files available.

### Sanitized diagnostic

<pre>No additional diagnostic recorded.</pre>

### Executable definition (procedure, not execution log)

medcollab-app/test/functional\_regression/needl\_test.dart:798; SHA-256 959a0f827866ab95b419ddaf77fc023b9dfd62bac486f83e6562887116b571a4

<pre>  testWidgets(&#39;FR-NDL-54 chat retains group identity and Needl menu&#39;,
      (t) async {
    await mount(
        t,
        ChannelChatPage(
            channelId: &#39;g1&#39;, channel: ChannelModel.fromJson(group())));
    await t.pumpAndSettle();
    expect(find.text(&#39;Night Team&#39;), findsWidgets);
    expect(find.text(&#39;Synthetic group message&#39;), findsOneWidget);
    expect(find.textContaining(&#39;Doctor B&#39;), findsWidgets);
    await t.tap(find.byType(PopupMenuButton&lt;String&gt;).first);
    await t.pumpAndSettle();
    expect(find.text(&#39;Rename Needl&#39;), findsOneWidget);
    expect(find.text(&#39;People in this Needl&#39;), findsOneWidget);
  });
}
</pre>
