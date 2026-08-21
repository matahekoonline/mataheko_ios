import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../screens/admin/pending_motor_mechanic_approvals_screen.dart';

/// Bell icon with a live count badge for pending motor mechanic approvals.
/// Show only when the signed-in user is an admin (same `_isAdmin` guard
/// already used for the "Add Motor Mechanic" FAB).
class PendingMotorMechanicApprovalsBadge extends StatelessWidget {
  const PendingMotorMechanicApprovalsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: AuthService.instance.pendingMotorMechanicsCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Pending motor mechanic approvals',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PendingMotorMechanicApprovalsScreen()),
                );
              },
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
