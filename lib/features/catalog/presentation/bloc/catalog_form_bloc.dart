import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';

sealed class CatalogFormEvent<I> extends Equatable {
  const CatalogFormEvent();

  @override
  List<Object?> get props => [];
}

class CatalogFormSubmitted<I> extends CatalogFormEvent<I> {
  const CatalogFormSubmitted(this.input);

  final I input;

  @override
  List<Object?> get props => [input];
}

enum CatalogFormStatus { idle, submitting, success, failure }

class CatalogFormState extends Equatable {
  const CatalogFormState({
    this.status = CatalogFormStatus.idle,
    this.message,
    this.fieldErrors = const {},
  });

  const CatalogFormState.submitting() : this(status: CatalogFormStatus.submitting);

  const CatalogFormState.success() : this(status: CatalogFormStatus.success);

  const CatalogFormState.failure(
    String message, {
    Map<String, String> fieldErrors = const {},
  }) : this(
          status: CatalogFormStatus.failure,
          message: message,
          fieldErrors: fieldErrors,
        );

  final CatalogFormStatus status;
  final String? message;

  /// Lỗi validation của BE theo tên field, hiện dưới đúng ô nhập.
  final Map<String, String> fieldErrors;

  bool get isSubmitting => status == CatalogFormStatus.submitting;

  @override
  List<Object?> get props => [status, message, fieldErrors];
}

/// Form tạo hoặc sửa một mục danh mục. [save] đã biết đang tạo hay sửa mục nào.
class CatalogFormBloc<I> extends Bloc<CatalogFormEvent<I>, CatalogFormState> {
  CatalogFormBloc(this._save) : super(const CatalogFormState()) {
    on<CatalogFormSubmitted<I>>(_onSubmitted);
  }

  final Future<void> Function(I input) _save;

  Future<void> _onSubmitted(
    CatalogFormSubmitted<I> event,
    Emitter<CatalogFormState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(const CatalogFormState.submitting());
    try {
      await _save(event.input);
      emit(const CatalogFormState.success());
    } on Failure catch (failure) {
      emit(
        CatalogFormState.failure(
          failure.message,
          fieldErrors: failure is ServerFailure ? failure.fieldErrors : const {},
        ),
      );
    }
  }
}
