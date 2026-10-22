const groups = [
  ['authentication-and-profiles', 7, [
    'otp-verification-creates-user-and-tokens', 'returning-login-preserves-identity', 'incorrect-otp-fails-then-correct-works', 'consumed-otp-cannot-be-reused', 'onboarding-and-profile-persist', 'refresh-session-and-missing-refresh-fails', 'device-deduplication-and-logout-removal',
  ]],
  ['spaces-and-invitations', 5, [
    'space-creation-default-channels', 'invitation-preview-join-and-membership', 'duplicate-space-join-conflict', 'rename-and-regenerate-invitation', 'member-leave-owner-removal-and-owner-leave-rejection',
  ]],
  ['channels', 3, [
    'public-channel-create-read-update-and-duplicate-rejection', 'private-channel-creator-access', 'archive-custom-channel-retains-messages-and-protects-defaults',
  ]],
  ['messaging-and-needl', 7, [
    'text-message-sender-and-sidebar-preview', 'root-pagination-order-without-overlap', 'quoted-message-retains-metadata', 'thread-reply-needl-and-preview', 'edit-soft-delete-and-socket-events', 'reaction-and-pin-persistence', 'empty-text-rejection-and-emergency-priority',
  ]],
  ['message-requests', 3, [
    'eligible-peer-request-lists-count-and-notification', 'accept-request-dm-and-notification', 'decline-request-and-terminal-transition-rejection',
  ]],
  ['direct-and-group-conversations', 5, [
    'accepted-dm-reopens-to-same-id', 'dm-message-peer-details-and-preview', 'read-receipt-deduplication-and-preference', 'notes-self-and-group-membership-rename', 'conversation-expansion-none-and-all',
  ]],
  ['handoffs', 5, [
    'handoff-draft-create-edit-read', 'empty-draft-rejection-and-disposable-delete', 'submit-handoff-inbox-history-notification-event', 'acknowledge-handoff-and-duplicate-rejection', 'writeback-reassign-reset-and-new-assignee-acknowledge',
  ]],
  ['media', 3, [
    'png-upload-download-delete', 'pdf-upload-and-handoff-attachment', 'inert-image-ecg-document-message-metadata',
  ]],
  ['notifications', 3, [
    'ordinary-message-inbox-count-metadata-socket', 'mention-and-emergency-notification-types', 'notification-read-unread-channel-read-all-delete',
  ]],
  ['realtime-and-availability', 3, [
    'socket-auth-join-message-reconnect', 'typing-start-stop-peer-delivery', 'availability-persistence-broadcast-room-sync-presence',
  ]],
  ['search', 2, [
    'known-user-search-and-phone-lookup', 'global-search-and-empty-query-result',
  ]],
  ['support', 1, ['bug-report-persistence-and-required-title']],
  ['startup', 1, ['health-connected-test-and-disabled-providers']],
];

export const scenarioGroups = Object.freeze(groups.map(([id, expected, groupScenarios]) => {
  const scenarios = Object.freeze(groupScenarios.map((name, index) => Object.freeze({
    id: `${id}-${String(index + 1).padStart(2, '0')}`,
    name,
    status: 'planned',
  })));
  return Object.freeze({ id, expected, scenarios });
}));

export const scenarios = Object.freeze(scenarioGroups.flatMap((group) => group.scenarios));
export const expectedScenarioCount = 48;

export function validateScenarioRegistry() {
  const failures = [];
  const ids = scenarios.map(({ id }) => id);
  if (scenarios.length !== expectedScenarioCount) failures.push(`Expected ${expectedScenarioCount} scenarios but found ${scenarios.length}.`);
  if (new Set(ids).size !== ids.length) failures.push('Scenario IDs must be unique.');
  for (const group of scenarioGroups) {
    if (group.scenarios.length !== group.expected) failures.push(`${group.id} expected ${group.expected} scenarios but has ${group.scenarios.length}.`);
  }
  if (scenarioGroups.reduce((count, group) => count + group.expected, 0) !== expectedScenarioCount) failures.push(`Journey totals do not equal ${expectedScenarioCount}.`);
  return failures;
}
