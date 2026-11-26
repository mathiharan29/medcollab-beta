import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

/// In-app forward: copy Vocle message link, or send into an existing DM/group chat.
Future<void> showForwardMessageSheet(
  BuildContext context, {
  required MessageModel message,
  required String sourceChannelId,
}) async {
  final body = message.displayText.trim();
  final media = message.content.mediaUrl?.trim();
  if (body.isEmpty && (media == null || media.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to forward from this message')),
    );
    return;
  }

  final link =
      'vocle://c/$sourceChannelId/m/${message.id}';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return _ForwardSheetBody(
        message: message,
        sourceChannelId: sourceChannelId,
        link: link,
        body: body,
        mediaUrl: media,
      );
    },
  );
}

class _ForwardSheetBody extends StatefulWidget {
  const _ForwardSheetBody({
    required this.message,
    required this.sourceChannelId,
    required this.link,
    required this.body,
    this.mediaUrl,
  });

  final MessageModel message;
  final String sourceChannelId;
  final String link;
  final String body;
  final String? mediaUrl;

  @override
  State<_ForwardSheetBody> createState() => _ForwardSheetBodyState();
}

class _ForwardSheetBodyState extends State<_ForwardSheetBody> {
  final _search = TextEditingController();
  List<ChannelModel> _targets = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dms = await AppDependencies.instance.channelRepository.getMyDMs();
      final spaces =
          await AppDependencies.instance.spaceRepository.getMySpaces();
      final groupChannels = <ChannelModel>[];
      for (final space in spaces) {
        for (final ch in space.channels) {
          if (ch.id == widget.sourceChannelId) continue;
          groupChannels.add(ch);
        }
      }
      if (!mounted) return;
      setState(() {
        _targets = [...dms, ...groupChannels];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load chats';
      });
    }
  }

  List<ChannelModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _targets;
    return _targets
        .where((c) => c.displayName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message link copied')),
    );
  }

  /// One key per target: a retry after a failure stores the forward once.
  final Map<String, String> _keys = {};

  Future<void> _forwardTo(ChannelModel channel) async {
    if (_busyId != null) return;
    setState(() => _busyId = channel.id);
    // A real copy of the message — its text, photo or file — tagged
    // "Forwarded from …" (beta 11-26), never a pasted link + storage URL.
    final key = _keys[channel.id] ??=
        'fw-${DateTime.now().microsecondsSinceEpoch}-${channel.id.hashCode.abs()}';
    try {
      await AppDependencies.instance.messageRepository.forwardMessage(
        toChannelId: channel.id,
        source: widget.message,
        sourceChannelId: widget.sourceChannelId,
        clientMessageId: key,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forwarded to ${channel.displayName}')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not forward')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Forward message',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.link),
              label: const Text('Copy message link'),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search DMs and groups',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final ch = _filtered[index];
                      final busy = _busyId == ch.id;
                      return ListTile(
                        title: Text(ch.displayName),
                        subtitle: Text(
                          ch.isDirect ? 'Direct message' : 'Group channel',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        onTap: busy ? null : () => _forwardTo(ch),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
