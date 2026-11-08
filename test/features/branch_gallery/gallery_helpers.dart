import 'dart:typed_data';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/branch_gallery/domain/branch_image.dart';

BranchImage image(int id, {int branchId = 3}) => BranchImage(
  id: id,
  branchId: branchId,
  url: 'https://cdn.example.com/$id.png',
);

class FakeBranchImages implements BranchImageRepository {
  FakeBranchImages([List<BranchImage> initial = const []])
    : items = [...initial];

  final List<BranchImage> items;
  Failure? failure;
  int nextId = 100;
  final uploaded = <List<String>>[];
  final deleted = <int>[];

  @override
  Future<List<BranchImage>> publicImages(int branchId) async {
    if (failure != null) throw failure!;
    return List.unmodifiable(items);
  }

  @override
  Future<List<BranchImage>> adminImages(int branchId) => publicImages(branchId);

  @override
  Future<List<BranchImage>> upload(
    int branchId,
    List<PickedImage> images,
  ) async {
    if (failure != null) throw failure!;
    uploaded.add([for (final i in images) i.name]);
    final saved = [for (final _ in images) image(nextId++, branchId: branchId)];
    items.addAll(saved);
    return saved;
  }

  @override
  Future<void> delete(int imageId) async {
    if (failure != null) throw failure!;
    deleted.add(imageId);
    items.removeWhere((e) => e.id == imageId);
  }
}

class FakePicker implements BranchImagePicker {
  List<PickedImage> next = const [];
  int calls = 0;

  @override
  Future<List<PickedImage>> pickMany() async {
    calls++;
    return next;
  }
}

PickedImage picked(String name, {int bytes = 10}) =>
    PickedImage(name: name, bytes: Uint8List(bytes));
