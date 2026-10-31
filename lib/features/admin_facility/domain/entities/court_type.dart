import 'package:equatable/equatable.dart';

class CourtType extends Equatable {
  const CourtType({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
