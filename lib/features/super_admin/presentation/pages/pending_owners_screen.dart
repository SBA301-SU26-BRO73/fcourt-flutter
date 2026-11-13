import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../../../../app/widgets/photo_empty_state.dart';
import '../../../../app/widgets/wp3b_widgets.dart';
import '../../domain/entities/court_owner.dart';
import '../bloc/owner_detail_cubit.dart';
import '../bloc/pending_owners_cubit.dart';

/// Mở màn chi tiết; trả về [OwnerDecision] khi hồ sơ đã được duyệt/từ chối.
typedef OpenOwnerDetail = Future<OwnerDecision?> Function(CourtOwner owner);

/// Danh sách hồ sơ chủ sân chờ duyệt (SuperAdmin). Cần [PendingOwnersCubit]
/// phía trên trong cây widget.
class PendingOwnersScreen extends StatelessWidget {
  const PendingOwnersScreen({super.key, required this.onOpenOwner});

  final OpenOwnerDetail onOpenOwner;

  Future<void> _open(BuildContext context, CourtOwner owner) async {
    final cubit = context.read<PendingOwnersCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final decision = await onOpenOwner(owner);
    if (decision == null) return;
    cubit.removeOwner(decision.owner.id);
    final verb = decision.type == OwnerDecisionType.approved
        ? 'Đã duyệt'
        : 'Đã từ chối';
    messenger.showSnackBar(
      SnackBar(content: Text('$verb hồ sơ ${decision.owner.fullName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ chủ sân chờ duyệt'),
        actions: [
          BlocBuilder<PendingOwnersCubit, PendingOwnersState>(
            builder: (context, state) => CircleIconButton(
              tooltip: 'Tải lại',
              onPressed: state.status == PendingOwnersStatus.loading
                  ? null
                  : context.read<PendingOwnersCubit>().load,
              icon: Icons.refresh,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<PendingOwnersCubit, PendingOwnersState>(
        builder: (context, state) {
          final cubit = context.read<PendingOwnersCubit>();
          final loading = state.status == PendingOwnersStatus.loading;
          final firstLoad =
              state.status == PendingOwnersStatus.initial ||
              (loading && state.owners.isEmpty);
          if (firstLoad) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, Gap.navClearance),
              children: [
                if (state.status == PendingOwnersStatus.failure)
                  _ErrorBanner(
                    message: state.message ?? '',
                    onRetry: cubit.load,
                  ),
                if (state.status == PendingOwnersStatus.success &&
                    state.owners.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Gap.xxl),
                    child: PhotoEmptyState(
                      title: 'Không có hồ sơ nào chờ duyệt',
                      message: 'Hồ sơ đăng ký chủ sân mới sẽ hiện ở đây để bạn xét duyệt.',
                    ),
                  ),
                for (final owner in state.owners)
                  _OwnerCard(owner: owner, onTap: () => _open(context, owner)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Flat 22dp card as the receipt cards of the mock-up: 42dp avatar circle,
/// name and contact on the left, two small tags underneath.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner, required this.onTap});

  final CourtOwner owner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final created = owner.createdAt;
    final legalCount = owner.legalDocuments.length;
    final muted = TextStyle(fontSize: 11, color: colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FcCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(
                owner.fullName.characters.first.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owner.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(owner.email, style: muted),
                  if (owner.phone != null) Text(owner.phone!, style: muted),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      TintTag('$legalCount giấy tờ pháp lý'),
                      if (created != null)
                        TintTag(
                          'Đăng ký '
                          '${DateFormat('dd/MM/yyyy').format(created)}',
                          tone: context.fc.neutral,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.error_outline, color: colors.onErrorContainer),
        title: Text(message, style: TextStyle(color: colors.onErrorContainer)),
        trailing: TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ),
    );
  }
}
