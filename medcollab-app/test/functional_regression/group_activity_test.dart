// REQ 2 part 2: group activity lines, Add members, chat wallpaper.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';
import 'package:medcollab_app/features/members/presentation/pages/add_members_page.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/presentation/utils/message_list_utils.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/chat_wallpaper.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/spaces/data/models/last_message_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _asha = UserModel(id: 'u1', name: 'Asha Rao', displayTitle: 'Dr');
const _vik = UserModel(id: 'u2', name: 'Vikram Shah', displayTitle: 'Dr');

void main() {
  test('server "system" type parses; preview reads "Group update" if no text',
      () {
    final m = MessageModel.fromJson({
      '_id': 'm1',
      'channelId': 'c1',
      'type': 'system',
      'senderId': {'_id': 'u1', 'name': 'Asha Rao'},
      'content': {
        'text': 'Dr Asha Rao added Dr Vikram Shah',
        'systemEvent': 'member_added',
      },
    });
    expect(m.type, MessageType.system);
    expect(m.content.text, 'Dr Asha Rao added Dr Vikram Shah');
    expect(
      const LastMessagePreview(type: MessageType.system).previewLabel,
      'Group update',
    );
  });

  test('an activity line breaks sender grouping', () {
    final t = DateTime.now();
    final items = buildMessageListItems(
      currentUserId: 'me',
      messages: [
        MessageModel(id: 'a', channelId: 'c', sender: _vik, createdAt: t),
        MessageModel(
          id: 's',
          channelId: 'c',
          sender: _asha,
          type: MessageType.system,
          createdAt: t,
        ),
        MessageModel(id: 'b', channelId: 'c', sender: _vik, createdAt: t),
      ],
    ).whereType<ChatMessageItem>().toList();
    expect(items.last.showSender, isTrue,
        reason: 'Vikram\'s bubble after "X added Y" shows his name again');
  });

  testWidgets('SystemEventChip is a centred, readable line', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SystemEventChip(text: 'Dr Asha Rao removed Dr Sam Lee'),
      ),
    ));
    expect(find.textContaining('Dr Asha Rao removed Dr Sam Lee'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Group update: Dr Asha Rao removed Dr Sam Lee'),
        findsOneWidget);
  });

  testWidgets('Add members: search, pick, add; existing members hidden',
      (tester) async {
    List<String>? sent;
    await tester.pumpWidget(MaterialApp(
      home: AddMembersPage(
        spaceId: 's1',
        existingMemberIds: const {'u1'},
        suggestions: () async => const [_asha, _vik],
        search: (_) async => const [_asha, _vik],
        submit: (ids) async {
          sent = ids;
          return const AddMembersResult(
            addedNames: ['Dr Vikram Shah'],
            privacySkipped: [],
            alreadyMembers: [],
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    // Asha is already in the group: not offered.
    expect(find.text('Dr Asha Rao'), findsNothing);
    expect(find.text('Dr Vikram Shah'), findsOneWidget);

    await tester.tap(find.text('Dr Vikram Shah'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(sent, ['u2']);
  });

  testWidgets('Add members: privacy-skipped doctors are explained',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddMembersPage(
                  spaceId: 's1',
                  existingMemberIds: const {},
                  suggestions: () async => const [_vik],
                  submit: (_) async => const AddMembersResult(
                    addedNames: [],
                    privacySkipped: ['Dr Vikram Shah'],
                    alreadyMembers: [],
                  ),
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr Vikram Shah'));
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('share the invite link'), findsOneWidget);
  });

  Future<void> openTheme(WidgetTester tester, {String? channelId}) async {
    tester.view.physicalSize = const Size(1080, 2340); // phone, dpr 2.75
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                ChatWallpaperPage.open(context, channelId: channelId),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('chat theme: picking only previews; Save applies to all chats',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ChatWallpaperStore.instance..resetForTest();
    await openTheme(tester);
    expect(find.text('Chat theme'), findsOneWidget);

    await tester.tap(find.text('Mint'));
    await tester.pumpAndSettle();
    expect(store.current.value, ChatWallpaper.doodle,
        reason: 'nothing changes until Save');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.current.value, ChatWallpaper.mint);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chat_wallpaper_v1'), 'mint');
    expect(find.text('Theme saved for all chats'), findsOneWidget);

    // Chat background and own bubbles follow the theme.
    late Color? bubble;
    await tester.pumpWidget(MaterialApp(
      home: ChatWallpaperBackground(
        child: Builder(builder: (c) {
          bubble = ChatThemeScope.mineBubbleOf(c);
          return const SizedBox.expand();
        }),
      ),
    ));
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((box.decoration as BoxDecoration).color, ChatWallpaper.mint.light);
    expect(bubble, ChatWallpaper.mint.bubbleLight);
  });

  testWidgets('chat theme: "This chat only" leaves other chats alone',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ChatWallpaperStore.instance..resetForTest();
    await openTheme(tester, channelId: 'needl-1');
    await tester.tap(find.text('This chat'));
    await tester.tap(find.text('Sky'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.resolve('needl-1'), ChatWallpaper.sky);
    expect(store.resolve('other-chat'), ChatWallpaper.doodle);
    expect(find.text('Theme saved for this chat'), findsOneWidget);

    // Back without saving changes nothing.
    await openTheme(tester, channelId: 'needl-1');
    await tester.tap(find.text('Blush'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.resolve('needl-1'), ChatWallpaper.sky);
  });
}
