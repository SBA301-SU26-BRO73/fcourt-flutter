import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/remote_call.dart';
import '../domain/voucher.dart';
import '../domain/voucher_draft.dart';
import '../domain/voucher_repository.dart';
import 'voucher_model.dart';

class VoucherRepositoryImpl implements VoucherRepository {
  const VoucherRepositoryImpl(this.dio);
  final Dio dio;

  Future<T> _call<T>(Future<T> Function() action) => remoteCall(
    action,
    localize: (failure) => ServerFailure(
      switch (failure.statusCode) {
        409 => 'Mã voucher đã tồn tại. Vui lòng chọn mã khác.',
        403 => 'Bạn không có quyền quản lý voucher của chi nhánh này.',
        404 => 'Không tìm thấy voucher. Vui lòng tải lại danh sách.',
        400 => 'Thông tin voucher chưa hợp lệ. Vui lòng kiểm tra lại.',
        _ => failure.message,
      },
      statusCode: failure.statusCode,
      fieldErrors: failure.fieldErrors,
      errorLines: failure.errorLines,
    ),
  );

  @override
  Future<VoucherPage> list(int branchId, {int page = 0}) async {
    if (branchId <= 0 || page < 0 || page > 100000) {
      throw const ServerFailure('Chi nhánh hoặc trang không hợp lệ');
    }
    return _call(() async {
      final raw = (await dio.get<Map<String, dynamic>>(
        '/api/admin/vouchers',
        queryParameters: {
          'branchId': branchId,
          'page': page,
          'size': VoucherPage.size,
        },
      )).data;
      if (raw == null ||
          raw['page'] != page ||
          raw['size'] != VoucherPage.size ||
          raw['items'] is! List ||
          raw['total'] is! int ||
          raw['total'] < 0) {
        throw const FormatException();
      }
      final rows = (raw['items'] as List)
          .map((row) => VoucherModel.parse(row, branchId))
          .toList();
      if (rows.length > VoucherPage.size ||
          rows.map((row) => row.id).toSet().length != rows.length ||
          raw['total'] < rows.length) {
        throw const FormatException();
      }
      return VoucherPage(List.unmodifiable(rows), page, raw['total'] as int);
    });
  }

  @override
  Future<Voucher> get(int id, int branchId) async {
    if (id <= 0 || branchId <= 0) {
      throw const ServerFailure('Voucher không hợp lệ');
    }
    return _call(() async {
      final row = VoucherModel.parse(
        (await dio.get<Map<String, dynamic>>('/api/admin/vouchers/$id')).data,
        branchId,
      );
      if (row.id != id) throw const FormatException();
      return row;
    });
  }

  @override
  Future<Voucher> save(VoucherDraft draft, {int? id, int usedCount = 0}) async {
    final errors = draft.errors(usedCount: usedCount);
    if (errors.isNotEmpty || (id != null && id <= 0)) {
      throw ServerFailure(
        'Vui lòng kiểm tra thông tin voucher',
        fieldErrors: errors,
      );
    }
    return _call(() async {
      final body = VoucherModel.body(draft);
      final response = id == null
          ? await dio.post<Map<String, dynamic>>(
              '/api/admin/vouchers',
              data: body,
            )
          : await dio.put<Map<String, dynamic>>(
              '/api/admin/vouchers/$id',
              data: body,
            );
      final row = VoucherModel.parse(response.data, draft.branchId);
      if ((id != null && row.id != id) ||
          row.code != draft.code.trim().toUpperCase()) {
        throw const FormatException();
      }
      return row;
    });
  }

  @override
  Future<Voucher> setEnabled(int id, int branchId, bool enabled) async {
    final current = await get(id, branchId);
    if (enabled && current.expiredAt(DateTime.now().toUtc())) {
      throw const ServerFailure(
        'Voucher đã hết hạn. Hãy sửa thời hạn trước khi bật lại.',
      );
    }
    return save(
      VoucherDraft.fromVoucher(
        current,
        status: enabled ? VoucherStatus.active : VoucherStatus.expired,
      ),
      id: id,
      usedCount: current.usedCount,
    );
  }
}
