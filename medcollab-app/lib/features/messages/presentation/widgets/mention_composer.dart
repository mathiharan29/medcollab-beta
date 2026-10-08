import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/utils/mention_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';

/// Message composer with @mention autocomplete for clinical teams.
class MentionAwareComposer extends StatefulWidget {
  const MentionAwareComposer({
    required this.controller,
    required this.onSend,
    required this.mentionCandidates,
    this.excludeSelfId,
    this.focusNode,
    this.onPickGallery,
    this.onPickCamera,
    this.onPickDocument,
    this.isBusy = false,
    this.showTopBorder = true,
    super.key,
  });

  final TextEditingController controller;
  final void Function(String text, List<String> mentionIds) onSend;
  final List<UserModel> mentionCandidates;
  /// Current user — excluded from mention suggestions and mention payloads.
  final String? excludeSelfId;
  final FocusNode? focusNode;
  final VoidCallback? onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final bool isBusy;
  final bool showTopBorder;

  @override
  State<MentionAwareComposer> createState() => _MentionAwareComposerState();
}

class _MentionAwareComposerState extends State<MentionAwareComposer> {
  List<UserModel> _suggestions = const [];
  /// IDs chosen from the autocomplete list — authoritative for send payload.
  final Set<String> _pickedMentionIds = {};
  String _prevText = '';
  bool _handlingAtomicDelete = false;

  void _onTextChanged() {
    if (_handlingAtomicDelete) return;
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;

    // Backspace inside `@Name` removes the whole mention token at once.
    if (_prevText.length == text.length + 1 && cursor >= 0) {
      final deletedAt = cursor;
      final atomic = MentionUtils.deleteMentionTokenAt(_prevText, deletedAt);
      if (atomic != null && atomic != text) {
        _handlingAtomicDelete = true;
        _prevText = atomic;
        widget.controller.value = TextEditingValue(
          text: atomic,
          selection: TextSelection.collapsed(
            offset: atomic.length < cursor ? atomic.length : cursor,
          ),
        );
        _handlingAtomicDelete = false;
        _prunePickedMentions();
        setState(() => _suggestions = const []);
        return;
      }
    }
    _prevText = text;

    _prunePickedMentions();
    final query = MentionUtils.activeMentionQuery(
      text,
      cursor < 0 ? text.length : cursor,
    );
    if (query == null) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    final q = query.toLowerCase().trim();
    final selfId = widget.excludeSelfId;
    final matches = widget.mentionCandidates
        .where((u) {
          if (u.id.isEmpty) return false;
          if (selfId != null && selfId.isNotEmpty && u.id == selfId) {
            return false;
          }
          if (q.isEmpty) return true;
          final name = u.name?.toLowerCase() ?? '';
          final display = u.displayName.toLowerCase();
          return name.contains(q) || display.contains(q);
        })
        .take(6)
        .toList();
    setState(() => _suggestions = matches);
  }

  /// Drop picked IDs whose `@name` token was deleted from the composer.
  void _prunePickedMentions() {
    if (_pickedMentionIds.isEmpty) return;
    final text = widget.controller.text;
    final stillPresent = <String>{};
    for (final id in _pickedMentionIds) {
      UserModel? user;
      for (final c in widget.mentionCandidates) {
        if (c.id == id) {
          user = c;
          break;
        }
      }
      if (user == null) continue;
      final token = (user.name != null && user.name!.trim().isNotEmpty)
          ? user.name!.trim()
          : user.displayName.trim();
      if (token.isEmpty) continue;
      final pattern = RegExp(
        '@${RegExp.escape(token)}(?=\\s|\$|[.,!?])',
        caseSensitive: false,
      );
      if (pattern.hasMatch(text)) stillPresent.add(id);
    }
    _pickedMentionIds
      ..clear()
      ..addAll(stillPresent);
  }

  void _insertMention(UserModel user) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final updated = MentionUtils.insertMention(text, cursor, user);
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
    if (user.id.isNotEmpty && user.id != widget.excludeSelfId) {
      _pickedMentionIds.add(user.id);
    }
    setState(() => _suggestions = const []);
  }

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    // Prefer IDs the doctor explicitly picked from suggestions.
    final fromPicks = _pickedMentionIds.toList();
    final fromText = MentionUtils.extractMentionedUserIds(
      text,
      widget.mentionCandidates,
      excludeUserId: widget.excludeSelfId,
    );

    final merged = <String>{
      ...fromPicks,
      ...fromText,
    };
    if (widget.excludeSelfId != null && widget.excludeSelfId!.isNotEmpty) {
      merged.remove(widget.excludeSelfId);
    }

    widget.onSend(text, merged.toList());
    _pickedMentionIds.clear();
  }

  @override
  void initState() {
    super.initState();
    _prevText = widget.controller.text;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant MentionAwareComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mentionCandidates != widget.mentionCandidates) {
      _onTextChanged();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 2,
            color: AppColors.surface,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final user = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text(
                      (user.name ?? 'D').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(user.displayName),
                  onTap: () => _insertMention(user),
                );
              },
            ),
          ),
        MessageComposer(
          controller: widget.controller,
          focusNode: widget.focusNode,
          isBusy: widget.isBusy,
          showTopBorder: widget.showTopBorder,
          onSend: (_) => _send(),
          onPickGallery: widget.onPickGallery,
          onPickCamera: widget.onPickCamera,
          onPickDocument: widget.onPickDocument,
          hintText: 'Message… @ to mention',
        ),
      ],
    );
  }
}
