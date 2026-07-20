import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/login_sheet.dart'; // adjust path if login_sheet.dart lives elsewhere

/// Checks if the user is logged in. If not, opens the LoginSheet as a
/// modal bottom sheet. Returns true if the user is (or just became)
/// logged in, false if they dismissed the sheet without logging in.
///
/// Usage:
///   final loggedIn = await requireLogin(context, actionLabel: 'post an item for sale');
///   if (!loggedIn) return;
Future<bool> requireLogin(BuildContext context, {required String actionLabel}) async {
  // AuthService.instance.currentUser should be the Firebase User? (or null if signed out).
  // If your AuthService exposes it under a different name, swap it in here.
  if (AuthService.instance.currentUser != null) return true;

  if (!context.mounted) return false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => LoginSheet(actionLabel: actionLabel),
  );

  return result == true;
}
