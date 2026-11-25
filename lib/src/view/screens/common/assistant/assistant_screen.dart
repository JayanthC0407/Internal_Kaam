import 'package:assistant_core/assistant_core.dart';
import 'package:assistant_transport/assistant_transport.dart';
import 'package:assistant_ui/assistant_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:demo_bank/src/infra/network/dio_web_credentials.dart';
import 'package:demo_bank/src/infra/pref/preference_helper.dart';
import 'package:demo_bank/src/infra/service/navigation_service.dart';

import 'assistant_settings.dart';
import 'named_route_navigator.dart';

/// Signs in to the assistant with the user's OBDX session and shows the chat.
///
/// DEVELOPMENT ONLY: see [AssistantSettings]. The assistant reads this user's
/// OBDX data read-only, and the screen says so.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  AssistantClient? _client;
  TenantConfig? _config;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _start() async {
    final base = AssistantSettings.apiBase;
    if (base == null) {
      setState(() => _error = 'The assistant is not enabled in this build.');
      return;
    }
    try {
      final token = await _assistantToken(base);
      if (token == null) {
        if (mounted) setState(() => _error = 'Sign in to the bank first.');
        return;
      }
      final client = AssistantClient(
        baseUrl: base,
        tenantId: AssistantSettings.tenantId,
        sessionToken: () async => token,
      );
      final state = await ConfigLoader(
        expectedTenantId: AssistantSettings.tenantId,
        fetch: client.fetchConfig,
      ).load();
      if (!mounted) {
        client.close();
        return;
      }
      if (state is AssistantActive) {
        setState(() {
          _client = client;
          _config = state.config;
        });
      } else {
        client.close();
        setState(() => _error = 'The assistant is not available right now.');
      }
    } on Object catch (e) {
      debugPrint('assistant: could not start: ${e.runtimeType}');
      if (mounted) setState(() => _error = 'Could not reach the assistant.');
    }
  }

  /// DEVELOPMENT ONLY. Hands this app's OBDX session to the assistant backend,
  /// which checks it with OBDX and returns an assistant token for the user OBDX
  /// names. The backend uses it for GET calls only. A production app would use a
  /// token exchange through the bank's identity service instead.
  Future<String?> _assistantToken(Uri base) async {
    final prefs = PreferenceHelper.getInstance();
    final auth = await prefs.getAuthorization();
    if (auth == null || auth.accessToken.isEmpty) return null;
    // Native builds keep the OBDX cookies in secure storage. On web the browser keeps
    // them and the app can't read them; sending the request with credentials makes
    // the browser attach them (the dev proxy stores them for localhost).
    final cookies = await prefs.getCookieModel();
    final dio = Dio(BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ));
    applyWebCredentials(dio);
    final response = await dio.postUri<Map<String, dynamic>>(
      base.resolve('v1/dev/bank-session'),
      data: {
        'tenantId': AssistantSettings.tenantId,
        'token': auth.accessToken,
        'tokenType': auth.tokenType.isEmpty ? 'Bearer' : auth.tokenType,
        'cookies': {
          if (cookies.jsessionId != null) 'JSESSIONID': cookies.jsessionId!,
          if (cookies.secretKey != null) 'secretKey': cookies.secretKey!,
        },
      },
    );
    if (response.statusCode != 200) throw StateError('bank session refused (${response.statusCode})');
    return response.data?['token'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final client = _client;
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(config?.assistantName ?? 'Assistant')),
      body: switch ((config, client, _error)) {
        (_, _, final String error) => Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text(error, textAlign: TextAlign.center)),
          ),
        (final TenantConfig config, final AssistantClient client, _) => Column(
            children: [
              const _UatBanner(),
              Expanded(
                child: ProviderScope(
                  overrides: [
                    assistantSetupProvider.overrideWithValue(AssistantSetup(
                      client: client,
                      config: config,
                      navigator: NamedRouteNavigator(NavigationService.globalAppNav),
                      // Tier 3: no transfer drafts, so no payee check is needed.
                      isSavedPayee: (_) async => false,
                      language: config.languages.any((l) => l.code == language) ? language : 'en',
                    )),
                  ],
                  child: const AssistantChatView(suggestions: [
                    "What's my balance?",
                    'Show my last 5 transactions',
                    'Who are my saved payees?',
                    'Take me to transfer money',
                  ]),
                ),
              ),
            ],
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _UatBanner extends StatelessWidget {
  const _UatBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('assistant-uat-banner'),
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        'Development preview: the assistant reads your UAT accounts (read only).',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}
