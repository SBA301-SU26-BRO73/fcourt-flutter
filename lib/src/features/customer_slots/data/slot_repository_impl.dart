import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../domain/court_slot.dart';
import '../domain/slot_repository.dart';
import 'slot_remote_data_source.dart';

class SlotRepositoryImpl implements SlotRepository {
  SlotRepositoryImpl(this.source);
  final SlotRemoteDataSource source;

  @override
  Future<List<CourtSlot>> getSlots(int courtId, DateTime date) async {
    try {
      return await source.getSlots(courtId, date);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw const ServerFailure('Không tìm thấy sân này.', statusCode: 404);
      }
      throw failureFromDio(error);
    } on Object {
      throw const UnknownFailure('Lịch sân không hợp lệ. Vui lòng tải lại.');
    }
  }
}
