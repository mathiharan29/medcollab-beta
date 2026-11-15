// Issue 5 (beta 11-14): voice notes on handoffs (app side).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/theme/app_theme.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_voice_note.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/handoff_form_cubit.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_voice_note_field.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';

import 'functional_regression/fakes/chat_fakes.dart';

const _receiver = UserModel(id: 'r1', name: 'Arjun');
const _voice = HandoffVoiceNote(url: 'https://res.cloudinary.com/x/a.m4a', durationMs: 9000);

HandoffModel _h({int version = 3, HandoffVoiceNote? voice}) => HandoffModel(
      id: 'h1',
      spaceId: 's1',
      channelId: 'c1',
      fromUser: const UserModel(id: 'me'),
      toUser: _receiver,
      shiftDate: DateTime(2026, 11, 14),
      shiftType: ShiftType.night,
      status: HandoffStatus.submitted,
      patients: const [HandoffPatientModel(id: 'p1', bedNumber: '7', clinicalAlias: 'Post-op')],
      voiceNote: voice,
      contentVersion: version,
    );

class _Repo extends HandoffRepository {
  _Repo() : super(apiClient: isolatedApiClient());
  int serverVersion = 3;
  HandoffVoiceNote? serverVoice;
  final sent = <Map<String, Object?>>[];

  @override
  Future<HandoffModel> updateHandoff({
    required String handoffId,
    DateTime? shiftDate,
    ShiftType? shiftType,
    List<HandoffPatientModel>? patients,
    String? shiftSummary,
    HandoffVoiceNote? voiceNote,
    bool setVoiceNote = false,
    int? baseContentVersion,
  }) async {
    sent.add({'voice': voiceNote, 'set': setVoiceNote, 'base': baseContentVersion});
    if (baseContentVersion != serverVersion) {
      throw const ConflictException('changed on another device');
    }
    serverVersion++;
    if (setVoiceNote) serverVoice = voiceNote;
    return _h(version: serverVersion, voice: serverVoice);
  }

  @override
  Future<HandoffModel> getHandoffById(String handoffId) async =>
      _h(version: serverVersion, voice: serverVoice);
}

class _Rec implements VoiceRecorderEngine {
  _Rec({this.permission = true});
  final bool permission;
  String? path;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start(String p) async {
    path = p;
    await File(p).writeAsBytes(List<int>.filled(256, 3));
  }

  @override
  Stream<double> amplitudeDbfs() => const Stream.empty();
  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

/// Let real I/O (temp files) finish and run its continuations.
Future<void> _settle(WidgetTester tester, [int ms = 0]) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: i == 0 ? ms : 20)));
    await tester.pump();
  }
}

void main() {
  group('form cubit', () {
    late _Repo repo;
    late HandoffFormCubit cubit;
    setUp(() {
      repo = _Repo();
      cubit = HandoffFormCubit(
        handoffRepository: repo,
        spaceId: 's1',
        channelId: 'c1',
        currentUserId: 'me',
        existing: _h(),
      );
    });
    tearDown(() => cubit.close());

    test('saving sends the voice note with the base version, adopts the new one',
        () async {
      cubit.setVoiceNote(_voice);
      final r = await cubit.saveChanges();
      expect(r, isNotNull);
      expect(repo.sent.single, {'voice': _voice, 'set': true, 'base': 3});
      expect(cubit.state.contentVersion, 4);

      cubit.removeVoiceNote();
      await cubit.saveChanges();
      expect(repo.sent.last, {'voice': null, 'set': true, 'base': 4},
          reason: 'removal is sent explicitly (null)');
    });

    test('edited on another device → conflict banner; reload takes the latest',
        () async {
      repo.serverVersion = 5; // someone saved twice meanwhile
      repo.serverVoice = _voice;
      cubit.setShiftSummary('my stale edit');
      expect(await cubit.saveChanges(), isNull);
      expect(cubit.state.conflict, isTrue);

      await cubit.reloadLatest();
      expect(cubit.state.conflict, isFalse);
      expect(cubit.state.contentVersion, 5);
      expect(cubit.state.voiceNote, _voice);
      expect(await cubit.saveChanges(), isNotNull);
    });

    test('a voice note still uploading blocks save', () async {
      cubit.uploadStarted();
      expect(await cubit.saveChanges(), isNull);
      expect(cubit.state.error, contains('uploading'));
      expect(repo.sent, isEmpty);
      cubit.uploadFinished();
      expect(await cubit.saveChanges(), isNotNull);
    });
  });

  group('voice note field', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('handoff_voice'));
    tearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {} // Windows may still hold the file briefly
    });

    Widget host(Widget child) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
        );

    testWidgets('record → stop → uploaded → player; remove asks first',
        (tester) async {
      HandoffVoiceNote? value;
      final busy = <bool>[];
      var now = DateTime(2026);
      final rec = VoiceRecorderController(engine: _Rec(), tempDir: () async => tmp.path, clock: () => now);
      final upload = Completer<HandoffVoiceNote>();
      Future<void> pumpField() => tester.pumpWidget(host(StatefulBuilder(
            builder: (context, setState) => HandoffVoiceNoteField(
              value: value,
              playbackId: 't',
              recorder: rec,
              upload: (_) => upload.future,
              onBusyChanged: busy.add,
              onChanged: (v) => setState(() => value = v),
            ),
          )));
      await pumpField();
      await tester.tap(find.byKey(const Key('handoff-voice-record')));
      await _settle(tester); // recording has started
      now = now.add(const Duration(seconds: 2)); // spoke for 2 s
      expect(find.byKey(const Key('handoff-voice-recording')), findsOneWidget);

      await tester.tap(find.byKey(const Key('composer-action'))); // stop & keep
      await _settle(tester);
      expect(find.byKey(const Key('handoff-voice-uploading')), findsOneWidget);
      expect(busy, [true]);

      upload.complete(_voice);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(value, _voice);
      expect(busy, [true, false]);
      expect(find.byKey(const Key('handoff-voice-player')), findsOneWidget);

      await tester.tap(find.byTooltip('Remove voice note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(value, _voice);
      await tester.tap(find.byTooltip('Remove voice note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(find.byKey(const Key('handoff-voice-record')), findsOneWidget);
      rec.dispose();
    });

    testWidgets('too short or no microphone permission: clear message, nothing saved',
        (tester) async {
      HandoffVoiceNote? value;
      final shortRec = VoiceRecorderController(engine: _Rec(), tempDir: () async => tmp.path, clock: () => DateTime(2026)); // 0 s
      await tester.pumpWidget(host(HandoffVoiceNoteField(
        value: null,
        playbackId: 't',
        recorder: shortRec,
        upload: (_) async => _voice,
        onChanged: (v) => value = v,
      )));
      await tester.tap(find.byKey(const Key('handoff-voice-record')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('composer-action')));
      await _settle(tester);
      expect(find.textContaining('Too short'), findsOneWidget);
      expect(value, isNull);
      shortRec.dispose();

      final denied = VoiceRecorderController(engine: _Rec(permission: false), tempDir: () async => tmp.path);
      await tester.pumpWidget(host(HandoffVoiceNoteField(
        key: const Key('denied'),
        value: null,
        playbackId: 't2',
        recorder: denied,
        upload: (_) async => _voice,
        onChanged: (v) => value = v,
      )));
      await tester.tap(find.byKey(const Key('handoff-voice-record')));
      await _settle(tester);
      expect(find.textContaining('Microphone permission'), findsOneWidget);
      expect(value, isNull);
      denied.dispose();
    });

    test('model round-trips and ignores empty urls', () {
      expect(HandoffVoiceNote.fromJson({'url': ''}), isNull);
      final n = HandoffVoiceNote.fromJson({
        'url': 'u', 'durationMs': 1200, 'waveform': [1, 200, -5], 'recordedBy': {'_id': 'me'},
      })!;
      expect(n.waveform, [1, 100, 0]);
      expect(n.recordedById, 'me');
      final p = HandoffPatientModel.fromJson({
        'bedNumber': '7', 'clinicalAlias': 'x', 'voiceNote': {'url': 'u', 'durationMs': 1200},
      });
      expect(p.voiceNote?.url, 'u');
      expect(p.copyWith(clearVoiceNote: true).toJson()['voiceNote'], isNull);
    });
  });
}
