import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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
            builder: (context, state) => IconButton(
              tooltip: 'Tải lại',
              onPressed: state.status == PendingOwnersStatus.loading
                  ? null
                  : context.read<PendingOwnersCubit>().load,
              icon: const Icon(Icons.refresh),
            ),
          ),
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
              padding: const EdgeInsets.all(16),
              children: [
                if (state.status == PendingOwnersStatus.failure)
                  _ErrorBanner(
                    message: state.message ?? '',
                    onRetry: cubit.load,
                  ),
                if (state.status == PendingOwnersStatus.success &&
                    state.owners.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Column(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Không có hồ sơ nào chờ duyệt',
                          textAlign: TextAlign.center,
                        ),
                      ],
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

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner, required this.onTap});

  final CourtOwner owner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = owner.createdAt;
    final legalCount = owner.legalDocuments.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                child: Text(owner.fullName.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(owner.fullName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(owner.email),
                    if (owner.phone != null) Text(owner.phone!),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('$legalCount giấy tờ pháp lý'),
                        ),
                        if (created != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              'Đăng ký '
                              '${DateFormat('dd/MM/yyyy').format(created)}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
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
