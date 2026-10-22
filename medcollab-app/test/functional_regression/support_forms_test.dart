import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_constants.dart';
import 'package:medcollab_app/core/constants/legal_copy.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/support/presentation/pages/contact_team_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/feature_request_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/feedback_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/help_faq_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/legal_document_page.dart';
import 'package:medcollab_app/features/support/presentation/pages/report_bug_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SupportAdapter implements HttpClientAdapter {
  final calls = <String, int>{};
  final bodies = <String, List<Map<String, dynamic>>>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    expect(options.method, 'POST');
    expect(options.path, startsWith('/api/support/'));
    final path = options.path;
    calls[path] = (calls[path] ?? 0) + 1;
    bodies.putIfAbsent(path, () => []).add(Map<String, dynamic>.from(
        options.data as Map));
    final first = calls[path] == 1;
    return ResponseBody.fromString(jsonEncode(first
        ? {'success': false, 'message': 'Synthetic support failure'}
        : {'success': true, 'data': {'ticket': {'id': '$path-ticket'}}}),
      first ? 500 : 200,
      headers: {'content-type': ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FR-SUP-04: support failure/retry, help/legal and contact intent',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final adapter = _SupportAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'));
    dio.httpClientAdapter = adapter;
    AppDependencies.instance.apiClient = ApiClient(
      storage: SecureStorageService(), dio: dio,
    );
    final router = GoRouter(initialLocation: '/support-test', routes: [
      GoRoute(path: '/support-test', builder: (context, _) => Scaffold(
        body: Column(children: [
          for (final path in [AppRoutes.reportBug, AppRoutes.featureRequest,
              AppRoutes.feedback, AppRoutes.help, AppRoutes.privacy,
              AppRoutes.terms, AppRoutes.contact])
            TextButton(onPressed: () => context.push(path), child: Text(path)),
        ]),
      )),
      GoRoute(path: AppRoutes.reportBug, builder: (_, __) => const ReportBugPage()),
      GoRoute(path: AppRoutes.featureRequest,
          builder: (_, __) => const FeatureRequestPage()),
      GoRoute(path: AppRoutes.feedback, builder: (_, __) => const FeedbackPage()),
      GoRoute(path: AppRoutes.help, builder: (_, __) => const HelpFaqPage()),
      GoRoute(path: AppRoutes.contact, builder: (_, __) => const ContactTeamPage()),
      GoRoute(path: AppRoutes.privacy, builder: (_, __) => const LegalDocumentPage(
        title: 'Privacy policy', body: LegalCopy.privacyBody,
        lastUpdated: LegalCopy.lastUpdated,
      )),
      GoRoute(path: AppRoutes.terms, builder: (_, __) => const LegalDocumentPage(
        title: 'Terms of use', body: LegalCopy.termsBody,
        lastUpdated: LegalCopy.lastUpdated,
      )),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final cases = [
      (path: AppRoutes.reportBug, endpoint: '/api/support/bug',
        title: 'Title', detail: 'Description', submit: 'Submit report'),
      (path: AppRoutes.featureRequest, endpoint: '/api/support/feature',
        title: 'Title', detail: 'Description', submit: 'Submit request'),
      (path: AppRoutes.feedback, endpoint: '/api/support/feedback',
        title: 'Summary', detail: 'Details', submit: 'Submit feedback'),
    ];
    final retainedAfterFailure = <String, bool>{};
    for (final entry in cases) {
      for (var attempt = 1; attempt <= 2; attempt++) {
        await tester.tap(find.text(entry.path));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, entry.title),
            'Synthetic ${entry.path}');
        await tester.enterText(find.widgetWithText(TextFormField, entry.detail),
            'Synthetic support details for regression testing');
        await tester.ensureVisible(find.text(entry.submit));
        await tester.tap(find.text(entry.submit));
        for (var frame = 0;
            frame < 30 && (adapter.calls[entry.endpoint] ?? 0) < attempt;
            frame++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(adapter.calls[entry.endpoint], attempt);
        final body = adapter.bodies[entry.endpoint]!.last;
        expect(body['title'], 'Synthetic ${entry.path}');
        expect(body['description'],
            'Synthetic support details for regression testing');
        expect(find.text(entry.path), findsOneWidget,
            reason: 'Submission returns to the support entry screen');
        if (attempt == 1) {
          retainedAfterFailure[entry.path] =
              find.byType(TextFormField).evaluate().isNotEmpty;
        }
      }
      expect(adapter.bodies[entry.endpoint], hasLength(2));
    }

    final frameworkErrors = <String>[];
    Future<void> pumpRoute() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final error = tester.takeException();
      if (error != null) frameworkErrors.add(error.toString());
    }
    await tester.tap(find.text(AppRoutes.help));
    await pumpRoute();
    expect(find.text('How do I join a group?'), findsOneWidget);
    router.pop();
    await pumpRoute();
    await tester.tap(find.text(AppRoutes.privacy));
    await pumpRoute();
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.textContaining('Last updated'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    router.pop();
    await pumpRoute();
    await tester.tap(find.text(AppRoutes.terms));
    await pumpRoute();
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    router.pop();
    await pumpRoute();
    String? copiedEmail;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedEmail = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text(AppRoutes.contact));
    await pumpRoute();
    expect(find.textContaining(AppConstants.supportEmail), findsWidgets);
    await tester.tap(find.text('Copy support email'));
    await tester.pump();
    expect(copiedEmail, AppConstants.supportEmail);
    final violations = <String>[
      for (final entry in retainedAfterFailure.entries)
        if (!entry.value) '${entry.key} discarded inputs after API error',
      if (frameworkErrors.isNotEmpty)
        'Bundled help/contact rendering raised ${frameworkErrors.length} '
            'Flutter framework exception(s): ${frameworkErrors.first}',
    ];
    expect(violations, isEmpty,
        reason: 'Ticket retry and bundled support pages must remain functional');
  });
}
