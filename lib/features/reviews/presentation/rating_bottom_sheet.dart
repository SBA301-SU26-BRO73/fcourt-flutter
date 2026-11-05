import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      return PopScope(
        canPop: !state.busy && !state.picking,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đánh giá sân',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: state.busy || state.picking
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text('Trải nghiệm của bạn sau trận đấu thế nào?'),
              Wrap(
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
                            i <= state.rating ? Icons.star : Icons.star_outline,
                            color: Theme.of(context).colorScheme.primary,
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
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: !locked,
                maxLength: 2000,
                minLines: 3,
                maxLines: 6,
                onChanged: cubit.comment,
                decoration: const InputDecoration(
                  labelText: 'Nhận xét chi tiết',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        locked ||
                            state.photos.length == 5 ||
                            cubit.picker == null
                        ? null
                        : () => cubit.pick(),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        locked ||
                            state.photos.length == 5 ||
                            cubit.picker == null
                        ? null
                        : () => cubit.pick(camera: true),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                ],
              ),
              if (cubit.uploader == null)
                const Text(
                  'Chưa có API tải ảnh review. Bạn có thể xem trước ảnh, hoặc bỏ ảnh để gửi nhận xét.',
                ),
              Text('${state.photos.length}/5 ảnh'),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < state.photos.length; i++)
                    SizedBox(
                      width: 96,
                      height: 112,
                      child: Column(
                        children: [
                          Image.memory(
                            state.photos[i].bytes,
                            width: 96,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                          IconButton(
                            tooltip: 'Bỏ ảnh ${i + 1}',
                            onPressed: locked ? null : () => cubit.remove(i),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (state.error != null)
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (state.busy || state.picking) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    locked ||
                        (state.photos.isNotEmpty && cubit.uploader == null)
                    ? null
                    : cubit.submit,
                child: const Text('Gửi đánh giá'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
