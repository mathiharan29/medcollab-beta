part of 'voice_assistant_test.dart';

Future<void> _digital(WidgetTester tester) async {
  await _launch(tester, microphone: false);
  final f = await fixture();
  final entries = (await control('assistant-digital'))['attempts'] as List;
  expect(entries, isNotEmpty);
  var passed = 0;
  for (final entry in entries.cast<Map<String, dynamic>>()) {
    final timer = Stopwatch()..start();
    final native = entry['native'] as Map<String, dynamic>?;
    final mode = entry['action'] as String;
    final label = entry['target'] as String?;
    final target = switch (label) {
      'ward' => f['channelId'] as String,
      'needl' => f['voiceNeedlId'] as String,
      null when mode == 'availability' || mode == 'alerts' => _person(f, 'A'),
      null => null,
      _ => _person(f, label),
    };
    final expectedChoices = [
      for (final choice in entry['choices'] as List? ?? const [])
        _person(f, choice as String),
    ]..sort();
    final row = <String, Object?>{
      'layer': 'AUDIO_TO_ACTION',
      'sample': entry['sample'],
      'attempt': entry['attempt'],
      'sha256': entry['sha256'],
      'pcmSha256': entry['pcmSha256'],
      'intendedCommand': entry['phrase'],
      'expectedIntent': entry['intent'],
      'parsedIntent': null,
      'expectedTarget': target,
      'resolvedTarget': null,
      'expectedChoices': expectedChoices,
      'expectedAction': entry['expectedAction'],
      'actualAction': null,
      'recognizedTranscript': native?['transcript'],
      'recognitionStart': native == null ? 'not_started' : 'android_digital_pcm',
      'recognitionError': native?['error'],
      'recognitionTerminal': native?['terminal'],
      'recognitionDurationMs': native?['durationMs'],
      'delivered': entry['delivered'] == true,
      'recognitionSuccess': mode == 'silence' || native == null
          ? null : entry['recognized'] == true,
      'transcriptMatched': mode == 'silence' ? null : entry['transcriptMatched'],
      'intentCorrect': null,
      'entityCorrect': null,
    };
    var category = 'speech_recognition';
    _recordStart(row);
    try {
      await _returnHome(tester);
      if (mode == 'alerts') {
        await control('assistant-alerts-reset');
        await deps.notificationBadgeCubit.refresh();
        expect(deps.notificationBadgeCubit.state, 2);
      }
      final before = await control('assistant-state');
      unawaited(openVoiceBot(tester.element(_opener), listen: false));
      await until(tester, () => _panel.evaluate().length == 1,
          'Home opens the assistant for verified digital PCM');
      final bot = _cubit(tester);

      if (native == null) {
        throw DeviceInfrastructureError('No native session record for this attempt');
      }
      if (mode == 'silence' || entry['recognized'] != true) {
        expect(bot.state.proposals, isEmpty);
        expect(_confirm, findsNothing);
        expect(_route(), AppRoutes.home);
        expect(await control('assistant-state'), before);
        row['actualAction'] = {'route': _route(), 'confirmationShown': false};
        if (mode == 'silence') {
          expect(entry['silencePassed'], isTrue,
              reason: 'The recognizer must consume silence and provide no text');
        } else {
          expect(entry['recognized'], isTrue,
              reason: 'Android terminal ${native['terminal']}, error ${native['error']}');
        }
      } else {
        final transcript = native['transcript'] as String;
        category = 'command_parsing';
        await bot.handleText(transcript);
        await tester.pump();
        expect(bot.state.heard, transcript.trim());
        expect(bot.state.usedAi, isFalse);
        final proposal = bot.state.proposals.singleOrNull;
        final intent = proposal?.runtimeType.toString().replaceFirst(RegExp(r'Action$'), '');
        row['parsedIntent'] = intent;
        row['proposedAction'] = proposal?.title;
        row['intentCorrect'] = intent == entry['intent'];
        final resolved = _digitalTarget(proposal, f);
        row['resolvedTarget'] = resolved;
        if (proposal is ClarifyAction) {
          row['choices'] = proposal.choices.map((choice) => choice.rawId).toList()..sort();
        }
        if (mode == 'choose') {
          row['entityCorrect'] = listEquals(row['choices'] as List<String>?, expectedChoices);
        } else if (target != null) {
          row['entityCorrect'] = resolved == target;
        }
        category = 'confirmation_state';
        expect(_route(), AppRoutes.home);
        expect(await control('assistant-state'), before);
        row['actualAction'] = {'route': _route(), 'confirmed': false};
        category = 'incorrect_transcript';
        expect(entry['transcriptMatched'], isTrue,
            reason: 'Expected “${entry['phrase']}”, received “$transcript”');
        category = 'command_parsing';
        expect(intent, entry['intent']);
        category = 'entity_resolution';
        if (expectedChoices.isNotEmpty) {
          expect(row['choices'], expectedChoices);
        } else {
          expect(resolved, target);
        }
        category = 'application_action';
        await _finishDigitalAction(tester, bot, proposal, entry, f, before, row);
      }
      if (entry['attempt'] == 1 && (entry['smoke'] == true || mode == 'draft')) {
        await _digitalScreenshot(row);
      }
      row['result'] = 'PASS';
      passed++;
    } catch (error) {
      row['result'] = error is DeviceInfrastructureError ? 'BLOCKED' : 'FAIL';
      row['failureCategory'] = category;
      row['error'] = error.toString();
      row['actualRoute'] = _route();
    } finally {
      row['durationMs'] = timer.elapsedMilliseconds + (native?['durationMs'] as int? ?? 0);
      _recordAttempt(row);
    }
  }
  await _returnHome(tester);
  expect(passed, entries.length, reason: 'Each digital-audio attempt has its own verdict');
}

Future<void> _digitalScreenshot(Map<String, Object?> row) async {
  try {
    final screenshot = await control('assistant-screenshot',
        {'sample': row['sample'], 'attempt': row['attempt'] ?? 1});
    row['screenshot'] = screenshot['file'];
  } catch (error) {
    row['screenshotError'] = error.toString();
  }
}

String? _digitalTarget(VoiceAction? action, Map<String, dynamic> f) =>
    switch (action) {
      OpenChatAction(:final to) || HandoffAction(:final to) ||
      SendMessageAction(:final to) => to.rawId,
      SetAvailabilityAction() || MarkAlertsReadAction() => _person(f, 'A'),
      _ => null,
    };

Future<void> _finishDigitalAction(
  WidgetTester tester,
  VoiceBotCubit bot,
  VoiceAction? proposal,
  Map<String, dynamic> entry,
  Map<String, dynamic> f,
  Map<String, dynamic> before,
  Map<String, Object?> row,
) async {
  final mode = entry['action'] as String;
  final label = entry['target'] as String?;
  if (mode == 'unsupported' || mode == 'unknown') {
    expect(_confirm, findsNothing);
    if (mode == 'unsupported') {
      expect(bot.state.phase, VoiceBotPhase.error);
      expect(bot.state.message, contains(VoiceBotCubit.help));
    } else {
      expect((proposal as ClarifyAction).choices, isEmpty);
      expect(find.byKey(const Key('voicebot-clarify')), findsOneWidget);
    }
    row['actualAction'] = {'route': _route(), 'feedback': bot.state.message};
    expect(await control('assistant-state'), before);
    return;
  }

  expect(bot.state.phase, VoiceBotPhase.confirm);
  if (mode == 'choose') {
    expect(_confirm, findsNothing);
    final choice = find.byKey(Key('voicebot-choice-p:${_person(f, label!)}'));
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pump();
    final selected = bot.state.proposals.single as OpenChatAction;
    row['resolvedTarget'] = selected.to.rawId;
    row['entityCorrect'] = selected.to.rawId == row['expectedTarget'];
    expect(selected.to.rawId, row['expectedTarget']);
    expect(_route(), AppRoutes.home);
    expect(await control('assistant-state'), before);
  }
  expect(_confirm, findsOneWidget);
  if (mode == 'cancel') {
    final cancel = find.descendant(of: _panel, matching: find.text('Cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    expect(bot.state.proposals, isEmpty);
    expect(bot.state.phase, VoiceBotPhase.idle);
    expect(_confirm, findsNothing);
    expect(_route(), AppRoutes.home);
    expect(await control('assistant-state'), before);
    row['actualAction'] = {'route': _route(), 'confirmation': 'cancelled'};
    return;
  }

  if (proposal is NavigateAction) expect(proposal.tab, entry['value']);
  if (proposal is SearchAction) expect(proposal.query.toLowerCase(), entry['value']);
  if (proposal is SetAvailabilityAction) expect(proposal.status, entry['value']);
  if (proposal is SendMessageAction) {
    expect(proposal.text.toLowerCase().replaceFirst(RegExp(r'[.!?]$'), ''),
        (entry['value'] as String).toLowerCase());
  }
  if (mode == 'alerts') {
    expect(before['actorUnread'], 2);
    expect(before['otherUnread'], greaterThanOrEqualTo(1));
  }
  if (mode == 'unavailable') {
    await control('assistant-dm-failure', {'enabled': true});
  }
  try {
    await _tapConfirm(tester);
    row['confirmation'] = 'tapped';
    await _checkConfirmedDigitalAction(tester, bot, proposal, entry, f, before, row);
  } finally {
    if (mode == 'unavailable') {
      await control('assistant-dm-failure', {'enabled': false});
    }
  }
}

Future<void> _checkConfirmedDigitalAction(
  WidgetTester tester,
  VoiceBotCubit bot,
  VoiceAction? proposal,
  Map<String, dynamic> entry,
  Map<String, dynamic> f,
  Map<String, dynamic> before,
  Map<String, Object?> row,
) async {
  final mode = entry['action'] as String;
  final label = entry['target'] as String?;

  switch (mode) {
    case 'dm' || 'choose':
      await _assertChat(tester, f, label!, before, row);
    case 'draft':
      await _assertDraft(tester, f, before, row, recipient: label!,
          beds: (entry['beds'] as List).cast<String>());
    case 'channel' || 'needl':
      final expectedId = row['expectedTarget'] as String;
      final expectedRoute = mode == 'channel'
          ? AppRoutes.channelPath(f['spaceId'] as String, expectedId)
          : AppRoutes.dmPath(expectedId);
      final chat = find.byType(ChannelChatPage).hitTestable();
      await until(tester, () => chat.evaluate().length == 1,
          'the confirmed conversation is visible');
      final id = tester.widget<ChannelChatPage>(chat).channelId;
      row['actualAction'] = {'route': _route(), 'visibleChatIds': [id]};
      expect(id, expectedId);
      expect(_route(), expectedRoute);
      expect(await control('assistant-state'), before);
    case 'navigate' || 'search':
      final target = mode == 'search' ? AppRoutes.search : AppRoutes.profile;
      await until(tester, () => _route() == target, 'the confirmed route opens');
      row['actualAction'] = {'route': _route()};
      if (mode == 'search') {
        final field = find.descendant(of: find.byType(GlobalSearchPage),
            matching: find.byType(EditableText));
        expect(field, findsOneWidget);
        final text = tester.widget<EditableText>(field).controller.text;
        row['actualAction'] = {'route': _route(), 'searchField': text};
        expect(text, isEmpty);
      }
      expect(await control('assistant-state'), before);
    case 'denied' || 'unavailable' || 'no-shared-group' || 'send' || 'availability' || 'alerts':
      await until(tester, () => bot.state.phase == VoiceBotPhase.done,
          'the assistant reports the confirmed request result');
      expect(_route(), AppRoutes.home);
      final after = await control('assistant-state');
      final facts = <String, Object?>{'route': _route(), 'feedback': bot.state.message};
      row['actualAction'] = facts;
      switch (mode) {
        case 'denied':
          expect(bot.state.message, contains('accepted message request'));
          expect((await control('assistant-dm-response'))['code'], 403);
          expect(after, {...before, 'dmOpens': (before['dmOpens'] as int) + 1});
        case 'unavailable':
          final response = await control('assistant-dm-response');
          facts['httpStatus'] = response['code'];
          expect(response['code'], 503);
          expect(bot.state.message, contains('Could not do that'));
          expect(after, {...before, 'dmOpens': (before['dmOpens'] as int) + 1});
        case 'no-shared-group':
          expect(bot.state.message, contains('not in a group together'));
          expect(after, before);
        case 'send':
          final prior = before['sent'] as List;
          final sent = after['sent'] as List;
          final channel = (f['voiceDms'] as Map)[label];
          expect(sent, hasLength(prior.length + 1));
          final item = sent.last as Map;
          facts['message'] = item;
          expect(item['id'], isNotEmpty);
          expect(item['channelId'], channel);
          expect(item['text'], (proposal as SendMessageAction).text);
          expect(sent.take(prior.length), prior);
          expect({...after, 'sent': prior, 'messages': before['messages'],
            'dmOpens': before['dmOpens'], 'notifications': before['notifications'],
            'otherUnread': before['otherUnread']}, before);
          expect(after['messages'], (before['messages'] as int) + 1);
          expect(after['dmOpens'], (before['dmOpens'] as int) + 1);
        case 'availability':
          facts['availability'] = after['availability'];
          expect(before['availability'], isNot(entry['value']));
          expect(after, {...before, 'availability': entry['value']});
        case 'alerts':
          facts['unread'] = after['actorUnread'];
          expect(after, {...before, 'actorUnread': 0});
          expect(deps.notificationBadgeCubit.state, 0);
      }
    default:
      throw DeviceInfrastructureError('Unregistered digital action $mode');
  }
}
