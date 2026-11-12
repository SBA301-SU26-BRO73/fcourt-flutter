import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                  children: [
                    Text(
                      'Đội ngũ tại cơ sở',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (state.branches.isNotEmpty)
                      DropdownButtonFormField<int>(
                        key: ValueKey(state.branchId),
                        initialValue: state.branchId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Chi nhánh',
                        ),
                        items: state.branches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(
                                  b.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (id) {
                                if (id != null) cubit.load(id);
                              },
                      ),
                    if (state.loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: LinearProgressIndicator(),
                      ),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton(
                              onPressed: () => state.branchId == null
                                  ? cubit.initialize()
                                  : cubit.load(state.branchId!),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    if (!state.loading &&
                        state.error == null &&
                        state.members.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          state.branches.isEmpty
                              ? 'Chưa có chi nhánh đang hoạt động để quản lý nhân viên.'
                              : 'Chưa có nhân viên. Chọn “Thêm nhân viên” để phân công người vận hành.',
                        ),
                      ),
                    ...state.members.map(
                      (m) => Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              child: Text(
                                m.name.isEmpty
                                    ? '?'
                                    : m.name.characters.first.toUpperCase(),
                              ),
                            ),
                            title: Text(m.name),
                            subtitle: Text(
                              '${m.email}\n${m.phone}\n${state.branches.where((b) => b.id == m.branchId).map((b) => b.name).join()}\n${m.active ? 'Đang hoạt động' : 'Đã khóa'}',
                            ),
                            isThreeLine: true,
                            onTap: _busy || !m.active
                                ? null
                                : () => _edit(state, m),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _busy ? null : () => _toggle(m),
                              icon: Icon(
                                m.active ? Icons.lock_outline : Icons.lock_open,
                              ),
                              label: Text(
                                m.active ? 'Khóa tài khoản' : 'Mở khóa',
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
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
