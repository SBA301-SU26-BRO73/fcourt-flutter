import '../../../../core/error/failure.dart';
import 'submission_state.dart';

/// Đổi [Failure] thành trạng thái lỗi của form, giữ lỗi theo field nếu BE có trả.
SubmissionState submissionFailureFrom(Failure failure) => SubmissionState.failure(
      failure.message,
      fieldErrors: failure is ServerFailure ? failure.fieldErrors : const {},
    );
