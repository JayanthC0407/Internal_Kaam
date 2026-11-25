import 'package:flutter/material.dart';
import 'package:demo_bank/src/infra/service/navigation_service.dart';

import 'assistant_screen.dart';
import 'assistant_settings.dart';

/// "Ask Noor" button for the home dashboard. Shows nothing unless the
/// assistant is enabled (dev builds only, see [AssistantSettings]).
class AskAssistantButton extends StatelessWidget {
  const AskAssistantButton({super.key, this.enabled});

  /// Overrides [AssistantSettings.enabled], for tests.
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    if (!(enabled ?? AssistantSettings.enabled)) return const SizedBox.shrink();
    return FloatingActionButton.small(
      key: const Key('ask-assistant'),
      heroTag: 'ask-assistant',
      tooltip: 'Ask Noor',
      onPressed: () => (NavigationService.globalAppNav.currentState ?? Navigator.of(context)).push(
        MaterialPageRoute<void>(builder: (_) => const AssistantScreen()),
      ),
      child: const Icon(Icons.chat_bubble_outline),
    );
  }
}
