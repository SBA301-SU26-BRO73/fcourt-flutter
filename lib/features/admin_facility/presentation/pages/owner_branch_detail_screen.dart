import 'package:flutter/material.dart';

import '../../../../app/widgets/wp3b_widgets.dart';
import '../../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../../domain/entities/branch.dart';

/// One place for the owner's settings and operations for a branch.
class OwnerBranchDetailScreen extends StatefulWidget {
  const OwnerBranchDetailScreen({
    super.key,
    required this.branch,
    required this.onEdit,
    required this.onCourts,
    this.onBack,
    this.onImages,
    this.onPayments,
    this.onRefunds,
    this.onTransactions,
  });

  final Branch branch;
  final Future<Branch?> Function(Branch) onEdit;
  final VoidCallback onCourts;
  final VoidCallback? onBack;
  final VoidCallback? onImages, onPayments, onRefunds, onTransactions;

  @override
  State<OwnerBranchDetailScreen> createState() =>
      _OwnerBranchDetailScreenState();
}

class _OwnerBranchDetailScreenState extends State<OwnerBranchDetailScreen> {
  late Branch _branch = widget.branch;

  Future<void> _edit() async {
    final updated = await widget.onEdit(_branch);
    if (!mounted || updated == null) return;
    setState(() => _branch = updated);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã cập nhật chi nhánh')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final branch = _branch;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết chi nhánh'),
        leading: widget.onBack == null
            ? null
            : CircleIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Quay lại',
                onPressed: widget.onBack,
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(ownerPad, 8, ownerPad, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: SizedBox(
              height: 180,
              child: SportPhoto(kind: sportKindOf(branch.name)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            branch.name,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          OwnerNote(branch.fullAddress),
          const SizedBox(height: 5),
          OwnerNote(
            '${branch.courtCount} sân · ${branch.status == BranchStatus.active ? 'Đang hoạt động' : 'Ngừng hoạt động'}',
          ),
          const OwnerSectionTitle('Thiết lập'),
          OwnerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Action(
                  Icons.grid_view_rounded,
                  'Sân và bảng giá',
                  widget.onCourts,
                ),
                _Action(
                  Icons.photo_library_outlined,
                  'Hình ảnh',
                  widget.onImages,
                ),
                _Action(Icons.edit_outlined, 'Sửa thông tin chi nhánh', _edit),
              ],
            ),
          ),
          const OwnerSectionTitle('Thanh toán'),
          OwnerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Action(
                  Icons.fact_check_outlined,
                  'Biên lai chờ duyệt',
                  widget.onPayments,
                ),
                _Action(Icons.currency_exchange, 'Hoàn tiền', widget.onRefunds),
                _Action(
                  Icons.account_balance_wallet_outlined,
                  'Giao dịch',
                  widget.onTransactions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
