import 'package:flutter/material.dart';

/// Every session owns its routes. Replacing it removes retained account data,
/// including details, chat, maps and dialogs, from the navigation stack.
class AuthSessionNavigator extends StatelessWidget {
  const AuthSessionNavigator({
    super.key,
    required this.ownerId,
    required this.home,
  });

  final String ownerId;
  final WidgetBuilder home;

  @override
  Widget build(BuildContext context) => Navigator(
    key: ValueKey(ownerId),
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: home),
  );
}
