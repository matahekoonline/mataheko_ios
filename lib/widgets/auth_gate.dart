import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_sheet.dart';

/// Call before any action that needs a signed-in user
/// (posting, commenting, saving, etc).
/// Returns true if already logged in or the user just logged in.
/// Returns false if they cancelled — caller should abort the action.
Future<bool> requireLogin(BuildContext context, {String actionLabel = 'continue'}) async {
  if (AuthService.instance.isLoggedIn) return true;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => LoginSheet(actionLabel: actionLabel),
  );

  return result ?? false;
}