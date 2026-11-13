import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../domain/review.dart';
import '../domain/review_photo.dart';
import 'review_form_cubit.dart';

Future<CourtReview?> showRatingBottomSheet(
  BuildContext context, {
  required ReviewRepository repository,
  required int bookingId,
  ReviewPhotoPicker? picker,
  ReviewPhotoUploader? uploader,
}) => showModalBottomSheet<CourtReview>(
  useRootNavigator: true,
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => BlocProvider(
    create: (_) => ReviewFormCubit(
      repository,
      bookingId,
      picker: picker,
      uploader: uploader,
    ),
    child: const RatingBottomSheet(),
  ),
);

class RatingBottomSheet extends StatelessWidget {
  const RatingBottomSheet({super.key});
  static const emotions = ['Rất tệ', 'Tệ', 'Bình thường', 'Tốt', 'Tuyệt vời'];
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ReviewFormCubit, ReviewFormState>(
    listenWhen: (old, next) => old.result == null && next.result != null,
    listener: (context, state) => Navigator.of(context).pop(state.result),
    builder: (context, state) {
      final cubit = context.read<ReviewFormCubit>();
      final locked = cubit.locked;
      final colors = Theme.of(context).colorScheme;
      final cannotPick =
          locked || state.photos.length == 5 || cubit.picker == null;
      return PopScope(
        canPop: !state.busy && !state.picking,
        child: Wp3bSheet(
          title: 'Đánh giá sân',
          subtitle: 'Trải nghiệm của bạn sau trận đấu thế nào?',
          trailing: CircleIconButton(
            icon: Icons.close,
            tooltip: 'Đóng',
            onPressed: state.busy || state.picking
                ? null
                : () => Navigator.of(context).pop(),
          ),
          actions: [
            Wp3bAction(
              'Gửi đánh giá',
              onPressed:
                  locked || (state.photos.isNotEmpty && cubit.uploader == null)
                  ? null
                  : cubit.submit,
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Semantics(
                            selected: state.rating == i,
                            child: IconButton(
                              tooltip: '$i sao · ${emotions[i - 1]}',
                              onPressed: locked ? null : () => cubit.rate(i),
                              icon: AnimatedScale(
                                scale: state.rating == i ? 1.15 : 1,
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  i <= state.rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: i <= state.rating
                                      ? colors.primary
                                      : colors.outline,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        state.rating == 0
                            ? 'Chọn số sao'
                            : emotions[state.rating - 1],
                        key: ValueKey(state.rating),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: state.rating == 0
                              ? colors.onSurfaceVariant
                              : colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
              Wp3bField(
                'Nhận xét chi tiết',
                child: TextField(
                  enabled: !locked,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  onChanged: cubit.comment,
                  decoration: const InputDecoration(
                    hintText: 'Chia sẻ trải nghiệm của bạn',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: cannotPick ? null : () => cubit.pick(),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Chọn ảnh'),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: cannotPick
                          ? null
                          : () => cubit.pick(camera: true),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Chụp ảnh'),
                    ),
                  ),
                ],
              ),
              if (cubit.uploader == null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.sm),
                  child: Text(
                    'Chưa có API tải ảnh review. Bạn có thể xem trước ảnh, hoặc bỏ ảnh để gửi nhận xét.',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Text(
                  '${state.photos.length}/5 ảnh',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (state.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.md),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < state.photos.length; i++)
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(Radii.md),
                                  child: Image.memory(
                                    state.photos[i].bytes,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => ColoredBox(
                                      color: colors.surfaceContainerHighest,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -12,
                                right: -12,
                                child: CircleIconButton(
                                  icon: Icons.close,
                                  tooltip: 'Bỏ ảnh ${i + 1}',
                                  size: 30,
                                  onPressed: locked
                                      ? null
                                      : () => cubit.remove(i),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.md),
                  child: Text(
                    state.error!,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              if (state.busy || state.picking)
                const Padding(
                  padding: EdgeInsets.only(top: Gap.md),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      );
    },
  );
}
