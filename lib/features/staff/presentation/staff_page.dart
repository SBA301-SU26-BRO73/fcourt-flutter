import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/widgets/wp3b_widgets.dart';
import '../../../app/widgets/fc_widgets.dart';
import '../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/command_key.dart';
import '../domain/staff.dart';
import 'staff_cubit.dart';
import 'staff_sheet.dart';

class StaffPage extends StatelessWidget {
  const StaffPage({super.key, required this.repository});
  final StaffRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StaffCubit(repository)..initialize(),
    child: const _StaffView(),
  );
}

class _StaffView extends StatefulWidget {
  const _StaffView();
  @override
  State<_StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<_StaffView> {
  final Map<String, String> _keys = {};
  bool _busy = false;

  Future<void> _edit(StaffState state, [StaffMember? member]) async {
    final cubit = context.read<StaffCubit>();
    final saved = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      builder: (_) => StaffSheet(
        repository: cubit.repository,
        branches: state.branches,
        branchId: member?.branchId ?? state.branchId!,
        member: member,
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin nhân viên')));
    await cubit.load(state.branchId!);
  }

  Future<void> _toggle(StaffMember member) async {
    if (_busy) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.active ? 'Khóa nhân viên?' : 'Mở khóa nhân viên?'),
        content: Text(
          '${member.name}\n${member.active ? 'Tài khoản sẽ không thể vận hành sân.' : 'Khôi phục quyền tại chi nhánh đã phân công.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    final commandId = '${member.id}:${!member.active}';
    setState(() => _busy = true);
    final cubit = context.read<StaffCubit>();
    try {
      await cubit.repository.setActive(
        member,
        !member.active,
        _keys.putIfAbsent(commandId, newCommandKey),
      );
      _keys.remove(commandId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật trạng thái')));
      await cubit.load(member.branchId);
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<StaffCubit, StaffState>(
    builder: (context, state) {
      final cubit = context.read<StaffCubit>();
      return Scaffold(
        appBar: AppBar(title: const Text('Nhân viên')),
        floatingActionButton: state.branchId == null
            ? null
            : FloatingActionButton.extended(
                shape: const StadiumBorder(),
                elevation: 2,
                onPressed: _busy ? null : () => _edit(state),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Thêm nhân viên'),
              ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: RefreshIndicator(
                onRefresh: () => state.branchId == null
                    ? cubit.initialize()
                    : cubit.load(state.branchId!),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    ownerPad,
                    Gap.sm,
                    ownerPad,
                    Gap.fabClearance,
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, bottom: 4),
                      child: Text(
                        'Đội ngũ tại cơ sở',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const OwnerNote('Phân công và quản lý người vận hành sân'),
                    const SizedBox(height: 16),
                    if (state.branches.isNotEmpty)
                      _BranchPicker(
                        key: ValueKey(state.branchId),
                        state: state,
                        enabled: !_busy,
                        onSelected: cubit.load,
                      ),
                    if (state.loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: LinearProgressIndicator(),
                      ),
                    if (state.error != null)
                      OwnerMessage(
                        icon: Icons.cloud_off_outlined,
                        text: state.error!,
                        action: 'Thử lại',
                        onAction: () => state.branchId == null
                            ? cubit.initialize()
                            : cubit.load(state.branchId!),
                      ),
                    if (!state.loading &&
                        state.error == null &&
                        state.members.isEmpty)
                      OwnerMessage(
                        icon: Icons.badge_outlined,
                        text: state.branches.isEmpty
                            ? 'Chưa có chi nhánh đang hoạt động để quản lý nhân viên.'
                            : 'Chưa có nhân viên. Chọn “Thêm nhân viên” để phân công người vận hành.',
                      ),
                    ...state.members.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OwnerCard(
                          onTap: _busy || !m.active
                              ? null
                              : () => _edit(state, m),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                    ),
                                    child: Text(
                                      m.name.isEmpty
                                          ? '?'
                                          : m.name.characters.first
                                                .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: m.active
                                        ? TintTag(
                                            'Đang hoạt động',
                                            tone: context.fc.success,
                                          )
                                        : TintTag(
                                            'Đã khóa',
                                            tone: context.fc.danger,
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OwnerNote(m.email),
                              OwnerNote(m.phone),
                              OwnerNote(
                                state.branches
                                    .where((b) => b.id == m.branchId)
                                    .map((b) => b.name)
                                    .join(),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OwnerPillButton(
                                  label: m.active
                                      ? 'Khóa tài khoản'
                                      : 'Mở khóa',
                                  icon: m.active
                                      ? Icons.lock_outline
                                      : Icons.lock_open,
                                  filled: false,
                                  danger: m.active,
                                  onPressed: _busy ? null : () => _toggle(m),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (state.hasMore)
                      TextButton(
                        onPressed: state.loading
                            ? null
                            : () => cubit.load(state.branchId!, more: true),
                        child: const Text('Xem thêm'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Dòng "Chi nhánh X" + pill đổi chi nhánh (kiểu `.period-picker`).
class _BranchPicker extends StatelessWidget {
  const _BranchPicker({
    super.key,
    required this.state,
    required this.enabled,
    required this.onSelected,
  });
  final StaffState state;
  final bool enabled;
  final void Function(int id) onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = state.branches
        .where((b) => b.id == state.branchId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PopupMenuButton<int>(
        enabled: enabled,
        tooltip: 'Đổi chi nhánh',
        position: PopupMenuPosition.under,
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final b in state.branches)
            PopupMenuItem(value: b.id, child: Text(b.name)),
        ],
        child: Row(
          children: [
            Expanded(
              child: Text(
                current == null
                    ? 'Chọn chi nhánh'
                    : 'Chi nhánh ${current.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
            Flexible(
              child: OwnerPill(
                'Đổi chi nhánh',
                trailing: Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
