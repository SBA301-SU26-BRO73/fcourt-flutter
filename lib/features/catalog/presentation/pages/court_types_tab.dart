import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../../../../app/widgets/sport_icon.dart';
import '../../domain/entities/court_type.dart';
import '../../domain/entities/court_type_input.dart';
import '../../domain/usecases/save_court_type.dart';
import '../bloc/catalog_form_bloc.dart';
import '../bloc/catalog_list_bloc.dart';
import '../widgets/catalog_notice.dart';
import '../widgets/catalog_list_view.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/status_chip.dart';
import 'court_type_form_page.dart';

typedef CourtTypeListBloc = CatalogListBloc<CourtType>;

class CourtTypesTab extends StatefulWidget {
  const CourtTypesTab({super.key, required this.saveCourtType});

  final SaveCourtType saveCourtType;

  @override
  State<CourtTypesTab> createState() => _CourtTypesTabState();
}

class _CourtTypesTabState extends State<CourtTypesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh(CourtTypeListBloc bloc) {
    bloc.add(const CatalogRefreshed());
    return bloc.stream.firstWhere((state) => !state.refreshing);
  }

  Future<void> _openForm(CourtType? editing) async {
    final bloc = context.read<CourtTypeListBloc>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BlocProvider(
          create: (_) => CatalogFormBloc<CourtTypeInput>(
            (input) => widget.saveCourtType(input, id: editing?.id),
          ),
          child: CourtTypeFormPage(editing: editing),
        ),
      ),
    );
    if (saved == true) {
      bloc.add(const CatalogRefreshed());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing == null ? 'Đã thêm loại sân' : 'Đã lưu loại sân',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(CourtType courtType) async {
    final bloc = context.read<CourtTypeListBloc>();
    final confirmed = await confirmDelete(
      context,
      title: 'Xóa loại sân?',
      message:
          'Loại sân "${courtType.name}" sẽ bị xóa khỏi danh mục. '
          'Các sân đã dùng loại này không bị ảnh hưởng.',
    );
    if (confirmed) bloc.add(CatalogItemDeleted(courtType.id));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<CourtTypeListBloc, CatalogListState<CourtType>>(
      listenWhen: (previous, current) =>
          current.notice != null && previous.notice != current.notice,
      listener: (context, state) => showCatalogNotice(context, state.notice!),
      builder: (context, state) {
        final bloc = context.read<CourtTypeListBloc>();
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            // Hai tab cùng sống trong TabBarView nên mỗi nút nổi cần hero tag riêng.
            heroTag: 'court-types-fab',
            onPressed: () => _openForm(null),
            icon: const Icon(Icons.add),
            label: const Text('Thêm loại sân'),
          ),
          body: CatalogListView<CourtType>(
            state: state,
            emptyMessage: 'Chưa có loại sân nào',
            onRefresh: () => _refresh(bloc),
            onLoadMore: () => bloc.add(const CatalogMoreRequested()),
            itemBuilder: (context, courtType) => _CourtTypeCard(
              courtType: courtType,
              deleting: state.deletingId == courtType.id,
              onTap: () => _openForm(courtType),
              onDelete: () => _delete(courtType),
            ),
          ),
        );
      },
    );
  }
}

class _CourtTypeCard extends StatelessWidget {
  const _CourtTypeCard({
    required this.courtType,
    required this.deleting,
    required this.onTap,
    required this.onDelete,
  });

  final CourtType courtType;
  final bool deleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitle = [
      if (courtType.nameEn != null) courtType.nameEn!,
      if (courtType.description != null) courtType.description!,
    ].join(' · ');
    return FcCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: deleting ? null : onTap,
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: SportIcon.named(
            courtType.name,
            color: colors.onPrimaryContainer,
          ),
        ),
        title: Text(courtType.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            StatusChip(
              courtType.active ? 'Hoạt động' : 'Tạm ngưng',
              highlighted: courtType.active,
            ),
          ],
        ),
        trailing: deleting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: 'Xóa ${courtType.name}',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
      ),
    );
  }
}
