import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';
import 'package:medcollab_app/features/spaces/data/repositories/space_repository.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

/// The server's Claude half of the hybrid voice bot (issue 14).
class AssistantRepository extends BaseRepository {
  AssistantRepository({required super.apiClient});

  bool? _llm;

  /// Whether the server has the AI half configured (cached per session).
  Future<bool> llmAvailable() async {
    final known = _llm;
    if (known != null) return known;
    try {
      final ok = await execute(
        () => apiClient.get(
          '/api/assistant/capabilities',
          parser: (json) => json['llm'] == true,
        ),
      );
      return _llm = ok;
    } catch (_) {
      return false; // never cache a failure
    }
  }

  /// Sentence → proposed actions (validated server-side against the
  /// doctor's own circle). Never executes anything.
  Future<List<VoiceAction>> interpret(String text) {
    return execute(
      () => apiClient.post(
        '/api/assistant/interpret',
        data: {'text': text},
        parser: (json) => [
          for (final a in (json['actions'] as List? ?? const []))
            if (a is Map) VoiceAction.fromJson(Map<String, dynamic>.from(a)),
        ].whereType<VoiceAction>().toList(),
      ),
    );
  }
}

/// Builds the doctor's own circle for the on-device parser.
class VoiceDirectoryLoader {
  VoiceDirectoryLoader({
    required ChannelRepository channels,
    required SpaceRepository spaces,
    required MemberRepository members,
  })  : _channels = channels,
        _spaces = spaces,
        _members = members;

  final ChannelRepository _channels;
  final SpaceRepository _spaces;
  final MemberRepository _members;

  /// Person id → groups shared with them (a voice handoff needs one).
  final Map<String, List<({String spaceId, String channelId, String name})>> sharedGroups = {};

  Future<VoiceDirectory> load(String selfId) async {
    final dms = await _channels.getMyDMs();
    final spaces = await _spaces.getMySpaces();
    final people = <String, VoiceTarget>{};
    final chats = <VoiceTarget>[];

    void addPerson(String id, String name, {String? username, String? speciality}) {
      if (id.isEmpty || id == selfId) return;
      people.putIfAbsent(
        id,
        () => VoiceTarget(id: 'p:$id', name: name, username: username, speciality: speciality),
      );
    }

    for (final dm in dms) {
      for (final m in dm.members) {
        addPerson(m.id, m.displayName, username: m.vocleUsername, speciality: m.speciality);
      }
      if (dm.isGroupDm) {
        chats.add(VoiceTarget(id: 'c:${dm.id}', name: dm.displayName, kind: 'needl'));
      }
    }
    sharedGroups.clear();
    for (final s in spaces) {
      final general = s.channels.where((c) => c.type == ChannelType.general).firstOrNull ??
          s.channels.firstOrNull;
      for (final c in s.channels) {
        chats.add(VoiceTarget(id: 'c:${c.id}', name: '${s.name} #${c.name}', kind: 'group', spaceId: s.id));
      }
      try {
        final members = await _members.getSpaceMembers(s.id);
        for (final m in members) {
          addPerson(m.user.id, m.user.displayName,
              username: m.user.vocleUsername, speciality: m.user.speciality);
          if (general != null && m.user.id != selfId) {
            (sharedGroups[m.user.id] ??= []).add((spaceId: s.id, channelId: general.id, name: s.name));
          }
        }
      } catch (_) {
        // A group we can't list right now: its chats are still reachable.
      }
    }
    return VoiceDirectory(people: people.values.toList(), chats: chats);
  }
}
