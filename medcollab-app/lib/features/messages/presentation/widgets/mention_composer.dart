import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/utils/mention_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';

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
    this.onRecordVoice,
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

  /// Voice note (REQ 12): mic shows when the box is empty.
  final VoidCallback? onRecordVoice;
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
    setState(() {
      _query = query.trim();
      _suggestions = rankMentionCandidates(
        widget.mentionCandidates,
        _query,
        excludeSelfId: widget.excludeSelfId,
      );
    });
  }

  String _query = '';

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

    // Two doctors can share a name ("@Asha Rao"): when one of them was
    // picked from the list, the text match must not also notify the other.
    String token(UserModel u) =>
        ((u.name ?? '').trim().isNotEmpty ? u.name! : u.displayName)
            .trim()
            .toLowerCase();
    final pickedTokens = {
      for (final c in widget.mentionCandidates)
        if (fromPicks.contains(c.id)) token(c),
    };
    final merged = <String>{
      ...fromPicks,
      for (final id in fromText)
        if (!pickedTokens.contains(token(widget.mentionCandidates
            .firstWhere((c) => c.id == id, orElse: () => UserModel(id: id)))))
          id,
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
          MentionSuggestionPanel(
            users: _suggestions,
            query: _query,
            onPick: _insertMention,
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
          onRecordVoice: widget.onRecordVoice,
          hintText: 'Message',
        ),
      ],
    );
  }
}

/// Mention suggestions for [query] (text after `@`), best first:
/// name / @username starting with it, then a later word starting with it,
/// then anything containing it. One row per person; self excluded.
List<UserModel> rankMentionCandidates(
  List<UserModel> candidates,
  String query, {
  String? excludeSelfId,
  int limit = 8,
}) {
  final q = query.toLowerCase().trim();
  final seen = <String>{};
  final scored = <(int, String, UserModel)>[];
  for (final u in candidates) {
    if (u.id.isEmpty || !seen.add(u.id)) continue;
    if (excludeSelfId != null && excludeSelfId.isNotEmpty && u.id == excludeSelfId) {
      continue;
    }
    final name = (u.name ?? '').toLowerCase();
    final display = u.displayName.toLowerCase();
    final handle = (u.vocleUsername ?? '').toLowerCase();
    int? score;
    if (q.isEmpty) {
      score = 3;
    } else if (name.startsWith(q) || display.startsWith(q) || handle.startsWith(q)) {
      score = 0;
    } else if (RegExp('(^|\\s)${RegExp.escape(q)}').hasMatch(display)) {
      score = 1;
    } else if (display.contains(q) || handle.contains(q)) {
      score = 2;
    }
    if (score != null) scored.add((score, display, u));
  }
  scored.sort((a, b) {
    final s = a.$1.compareTo(b.$1);
    return s != 0 ? s : a.$2.compareTo(b.$2);
  });
  return [for (final s in scored.take(limit)) s.$3];
}

/// Second line under a suggestion: "@asharao · Cardiology · PG Resident".
String mentionSubtitle(UserModel u) {
  final parts = <String>[
    if ((u.vocleUsername ?? '').trim().isNotEmpty) '@${u.vocleUsername!.trim()}',
    if ((u.speciality ?? '').trim().isNotEmpty) u.speciality!.trim(),
    if (u.role != UserRole.other) u.role.label,
  ];
  return parts.join(' · ');
}

/// Stable, distinct avatar colour per person (same doctor = same colour
/// everywhere), from a palette readable with white initials in both themes.
Color mentionAvatarColor(String userId) {
  const palette = <Color>[
    Color(0xFF0E7C6B), Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFDB2777),
    Color(0xFFEA580C), Color(0xFF0891B2), Color(0xFF4D7C0F), Color(0xFFB45309),
  ];
  var h = 0;
  for (final c in userId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

/// Floating card above the composer listing people to @mention
/// (beta 11-14, issue 9): photo / coloured initials, name with the typed
/// part highlighted, and @username · speciality · role so two doctors
/// with the same name are easy to tell apart.
class MentionSuggestionPanel extends StatelessWidget {
  const MentionSuggestionPanel({
    required this.users,
    required this.query,
    required this.onPick,
    super.key,
  });

  final List<UserModel> users;
  final String query;
  final ValueChanged<UserModel> onPick;

  static const rowHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final maxRows = users.length.clamp(1, 4);
    return Padding(
      key: const Key('mention-suggestions'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Material(
        color: AppColors.surfaceCard,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: AppColors.isDark ? 0.6 : 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.borderDefault, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                'MENTION SOMEONE',
                style: AppTextStyles.sectionLabel,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: rowHeight * maxRows + 4),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 4),
                itemCount: users.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 62,
                  color: AppColors.borderLight,
                ),
                itemBuilder: (context, i) => _MentionRow(
                  user: users[i],
                  query: query,
                  onTap: () => onPick(users[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MentionRow extends StatelessWidget {
  const _MentionRow({required this.user, required this.query, required this.onTap});

  final UserModel user;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = mentionSubtitle(user);
    final name = user.displayName;
    final base = AppTextStyles.cardTitle.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final spans = <TextSpan>[];
    final q = query.trim().toLowerCase();
    final at = q.isEmpty ? -1 : name.toLowerCase().indexOf(q);
    if (at < 0) {
      spans.add(TextSpan(text: name));
    } else {
      spans
        ..add(TextSpan(text: name.substring(0, at)))
        ..add(TextSpan(
          text: name.substring(at, at + q.length),
          style: const TextStyle(color: AppColors.tealDark),
        ))
        ..add(TextSpan(text: name.substring(at + q.length)));
    }
    return InkWell(
      key: Key('mention-row-${user.id}'),
      onTap: onTap,
      child: SizedBox(
        height: MentionSuggestionPanel.rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              AppAvatar(
                name: name,
                imageUrl: user.avatarUrl,
                size: 36,
                backgroundColor: mentionAvatarColor(user.id),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: spans),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.alternate_email_rounded, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
