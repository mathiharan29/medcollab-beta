/// Backend-aligned enums — mirrors `src/constants/index.js`.
library;

enum UserRole {
  intern('intern'),
  pgResident('pg_resident'),
  juniorConsultant('junior_consultant'),
  consultant('consultant'),
  nurse('nurse'),
  other('other');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String? raw) {
    return UserRole.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => UserRole.intern,
    );
  }

  String get label => switch (this) {
        UserRole.intern => 'MBBS Intern',
        UserRole.pgResident => 'PG Resident',
        UserRole.juniorConsultant => 'Junior Consultant',
        UserRole.consultant => 'Consultant',
        UserRole.nurse => 'Nurse',
        UserRole.other => 'Other',
      };
}

enum AvailabilityStatus {
  available('available'),
  onCall('on_call'),
  inOt('in_ot'),
  inIcu('in_icu'),
  onRounds('on_rounds'),
  offDuty('off_duty'),
  doNotDisturb('do_not_disturb');

  const AvailabilityStatus(this.value);
  final String value;

  static AvailabilityStatus fromString(String? raw) {
    return AvailabilityStatus.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => AvailabilityStatus.available,
    );
  }
}

enum SpaceType {
  department('department'),
  college('college'),
  hospital('hospital'),
  community('community');

  const SpaceType(this.value);
  final String value;

  static SpaceType fromString(String? raw) {
    return SpaceType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => SpaceType.department,
    );
  }
}

enum SpaceRole {
  owner('owner'),
  admin('admin'),
  member('member');

  const SpaceRole(this.value);
  final String value;

  static SpaceRole fromString(String? raw) {
    return SpaceRole.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => SpaceRole.member,
    );
  }
}

enum ChannelType {
  general('general'),
  emergency('emergency'),
  academic('academic'),
  announcements('announcements'),
  direct('direct');

  const ChannelType(this.value);
  final String value;

  static ChannelType fromString(String? raw) {
    return ChannelType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => ChannelType.general,
    );
  }
}

enum MessageType {
  text('text'),
  image('image'),
  document('document'),
  ecg('ecg'),
  handoff('handoff'),
  alert('alert');

  const MessageType(this.value);
  final String value;

  static MessageType fromString(String? raw) {
    return MessageType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => MessageType.text,
    );
  }
}

enum MessagePriority {
  normal('normal'),
  urgent('urgent'),
  emergency('emergency');

  const MessagePriority(this.value);
  final String value;

  static MessagePriority fromString(String? raw) {
    return MessagePriority.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => MessagePriority.normal,
    );
  }
}

enum HandoffStatus {
  draft('draft'),
  submitted('submitted'),
  acknowledged('acknowledged');

  const HandoffStatus(this.value);
  final String value;

  static HandoffStatus fromString(String? raw) {
    return HandoffStatus.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => HandoffStatus.draft,
    );
  }
}

enum ShiftType {
  morning('morning'),
  evening('evening'),
  night('night');

  const ShiftType(this.value);
  final String value;

  static ShiftType fromString(String? raw) {
    return ShiftType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => ShiftType.morning,
    );
  }
}

enum PatientStatus {
  stable('stable'),
  monitoring('monitoring'),
  critical('critical'),
  improving('improving'),
  deteriorating('deteriorating');

  const PatientStatus(this.value);
  final String value;

  static PatientStatus fromString(String? raw) {
    return PatientStatus.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => PatientStatus.stable,
    );
  }
}

enum NotificationType {
  newMessage('new_message'),
  mention('mention'),
  threadReply('thread_reply'),
  handoffReceived('handoff_received'),
  handoffAcknowledged('handoff_acknowledged'),
  emergencyAlert('emergency_alert'),
  spaceInvite('space_invite'),
  rosterUpdate('roster_update');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String? raw) {
    return NotificationType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => NotificationType.newMessage,
    );
  }
}
