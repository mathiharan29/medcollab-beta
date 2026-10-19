#!/usr/bin/env node
'use strict';

// Builds a reviewer-facing inventory from the routes the backend actually mounts.
// It only reads source and the discovery result; it never calls an API or alters data.
const fs = require('node:fs');
const path = require('node:path');

const backendRoot = path.resolve(__dirname, '..');
const sourceRoot = path.join(backendRoot, 'src');
const appPath = path.join(sourceRoot, 'app.js');
const outputDir = path.join(process.env.RUNNER_TEMP || require('node:os').tmpdir(), 'vocle-security-results');

function read(file) { return fs.readFileSync(file, 'utf8'); }
function routeFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return routeFiles(full);
    return entry.name.endsWith('.routes.js') ? [full] : [];
  });
}
function groupFor(file, routerName, base) {
  if (base === '/api/auth') return 'Authentication';
  if (base === '/api/users') return 'Users & Profiles';
  if (base === '/api/spaces') return 'Spaces & Membership';
  if (base === '/api/spaces/:spaceId/channels') return 'Space Channels';
  if (base === '/api/channels') return 'Channels & Direct Messages';
  if (base === '/api/channels/:channelId/messages') return 'Channel Messages';
  if (base === '/api/handoffs') return 'Handoffs';
  if (base === '/api/spaces/:spaceId/handoffs') return 'Space Handoffs';
  if (base === '/api/media') return 'Media';
  if (base === '/api/notifications') return 'Notifications';
  if (base === '/api/search') return 'Search';
  if (base === '/api/message-requests') return 'Message Requests';
  if (base === '/api/support') return 'Support & Feedback';
  if (base === '/api/dev') return 'Development Tools';
  return `Unclassified (${path.basename(path.dirname(file))}${routerName ? ` / ${routerName}` : ''})`;
}
function joinRoute(base, suffix) {
  if (suffix === '/') return base;
  return `${base}${suffix}`.replace(/\/+/g, '/');
}
function markdown(value) { return String(value).replace(/\|/g, '\\|'); }
function loadMounts(appSource) {
  const imports = new Map();
  for (const match of appSource.matchAll(/const\s+(\w+)\s*=\s*require\('([^']+\.routes)'\);/g)) imports.set(match[1], match[2]);
  for (const match of appSource.matchAll(/const\s*\{\s*([^}]+)\s*}\s*=\s*require\('([^']+\.routes)'\);/g)) {
    for (const name of match[1].split(',').map(item => item.trim()).filter(Boolean)) imports.set(name, match[2]);
  }
  const mounts = new Map();
  for (const match of appSource.matchAll(/app\.use\(\s*'([^']+)'\s*,\s*(\w+)\s*\);/g)) {
    const source = imports.get(match[2]);
    if (!source) continue;
    const full = path.resolve(sourceRoot, `${source.slice(2)}.js`);
    const entries = mounts.get(full) || [];
    entries.push({ routerName: match[2], base: match[1] });
    mounts.set(full, entries);
  }
  return mounts;
}
function parseRoutes(file, mounts) {
  const source = read(file);
  const routes = [];
  const allowed = new Map((mounts.get(file) || []).map(entry => [entry.routerName, entry.base]));
  // Most feature files export a local variable literally named `router`; app.js
  // imports it under a feature-specific name such as authRoutes. Resolve that
  // default-export convention while retaining the named-router handling above.
  if (/module\.exports\s*=\s*router\s*;/.test(source) && allowed.size === 1) allowed.set('router', [...allowed.values()][0]);
  for (const match of source.matchAll(/\b(\w+)\.(get|post|put|patch|delete)\(\s*'([^']*)'/g)) {
    const base = allowed.get(match[1]);
    if (!base) continue;
    routes.push({ group: groupFor(file, match[1], base), method: match[2].toUpperCase(), endpoint: joinRoute(base, match[3]), source: path.relative(backendRoot, file) });
  }
  return routes;
}
function routeMatches(template, executedEndpoint) {
  const pathname = new URL(executedEndpoint, 'http://local.invalid').pathname;
  const expression = `^${template.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/:[A-Za-z0-9_]+/g, '[^/]+')}$`;
  return new RegExp(expression).test(pathname);
}
function matchingResults(route, routes, results) {
  // Literal routes such as /users/me take precedence over /users/:id in
  // this backend. Credit each request once, never to both route patterns.
  const specificity = endpoint => endpoint.split('/').filter(part => part && !part.startsWith(':')).length;
  return results.filter(result => {
    const candidates = routes.filter(candidate => candidate.method === result.method && routeMatches(candidate.endpoint, result.endpoint));
    candidates.sort((a, b) => specificity(b.endpoint) - specificity(a.endpoint));
    return candidates[0] === route;
  });
}
function statusFor(route, routes, results, infrastructureFailure) {
  const matching = matchingResults(route, routes, results);
  if (!matching.length) return infrastructureFailure ? 'NOT RUN — discovery infrastructure did not complete' : 'NOT YET EXERCISED';
  const passed = matching.filter(result => result.passed).length;
  const observations = matching.length - passed;
  const modules = Object.entries(matching.reduce((counts, result) => {
    const module = result.module || 'Unlabelled legacy case';
    counts[module] = (counts[module] || 0) + 1;
    return counts;
  }, {})).map(([module, count]) => `${module}: ${count}`).join('; ');
  const outcome = observations ? `EXERCISED — ${passed} pass, ${observations} observation` : `EXERCISED — ${passed} pass`;
  return `${outcome} (${modules})`;
}
function main() {
  fs.mkdirSync(outputDir, { recursive: true });
  const appSource = read(appPath);
  const mounts = loadMounts(appSource);
  const routes = routeFiles(path.join(sourceRoot, 'features')).flatMap(file => parseRoutes(file, mounts));
  for (const match of appSource.matchAll(/app\.(get|post|put|patch|delete)\(\s*'([^']+)'/g)) {
    routes.push({ group: match[2] === '/health' ? 'Platform Health' : 'Platform API', method: match[1].toUpperCase(), endpoint: match[2], source: 'src/app.js' });
  }
  routes.sort((a, b) => a.group.localeCompare(b.group) || a.endpoint.localeCompare(b.endpoint) || a.method.localeCompare(b.method));

  let discovery = { planned: 0, executed: 0, passed: 0, unexpected: 0, infrastructureFailure: 'Discovery results were unavailable.', results: [] };
  const resultPath = path.join(outputDir, 'results.json');
  if (fs.existsSync(resultPath)) discovery = JSON.parse(read(resultPath));
  const exercisedEndpoints = new Set(routes.filter(route => matchingResults(route, routes, discovery.results).length).map(route => `${route.method} ${route.endpoint}`));
  const groups = new Map();
  for (const route of routes) {
    const entries = groups.get(route.group) || [];
    entries.push(route);
    groups.set(route.group, entries);
  }
  const report = [
    '# Vocle API Coverage Report',
    '',
    'This generated inventory is derived from the Express route files and their mounts in `src/app.js`. It shows the security-suite run status for every currently discovered HTTP API. `NOT YET EXERCISED` means the endpoint is known but has not been tested by the current deterministic suite; it does not imply the endpoint is safe or unsafe.',
    '',
    '## Run summary',
    '',
    `- APIs discovered: ${routes.length}`,
    `- API method/path combinations exercised by the discovery suite: ${exercisedEndpoints.size}`,
    `- Discovery cases executed: ${discovery.executed}/${discovery.planned}`,
    `- Discovery cases passed: ${discovery.passed}`,
    `- Discovery observations: ${discovery.unexpected}`,
    `- Discovery infrastructure status: ${discovery.infrastructureFailure || 'healthy'}`,
    '',
    '## API inventory by feature',
    '',
    ...[...groups.entries()].flatMap(([group, entries]) => [
      `### ${group}`,
      '',
      '| Method | API endpoint | This run | Route source |',
      '| --- | --- | --- | --- |',
      ...entries.map(route => `| ${route.method} | \`${route.endpoint}\` | ${markdown(statusFor(route, routes, discovery.results, discovery.infrastructureFailure))} | \`${route.source}\` |`),
      '',
    ]),
    '## Status definitions',
    '',
    '- **EXERCISED**: one or more current security cases called this exact HTTP method and route pattern; the status includes their pass/observation count and module labels, so shared group/DM message routes remain distinguishable.',
    '- **NOT YET EXERCISED**: the route was found in the backend but has no case in the current security suite.',
    '- **NOT RUN**: the discovery suite could not complete, so route-level execution status is unavailable.',
  ].join('\n');
  fs.writeFileSync(path.join(outputDir, 'security-api-coverage-report.md'), report);
  console.log(`API coverage: ${routes.length} APIs discovered; ${exercisedEndpoints.size} exercised by this run.`);
}

if (require.main === module) main();
module.exports = { matchingResults, loadMounts, parseRoutes, routeFiles, routeMatches };
