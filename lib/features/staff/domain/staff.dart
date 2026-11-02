class StaffBranch {
  const StaffBranch(this.id, this.name);
  final int id;
  final String name;
}

class WorkShift {
  const WorkShift(this.dayOfWeek, this.startTime, this.endTime);
  final int dayOfWeek;
  final String startTime;
  final String endTime;
}

class StaffMember {
  const StaffMember({
    required this.id,
    required this.branchId,
    required this.name,
    required this.email,
    required this.phone,
    required this.active,
    this.shifts = const [],
  });
  final int id;
  final int branchId;
  final String name;
  final String email;
  final String phone;
  final bool active;
  final List<WorkShift> shifts;
}

class StaffDraft {
  const StaffDraft({
    required this.branchId,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.shifts = const [],
  });
  final int branchId;
  final String name;
  final String email;
  final String phone;
  final String password;
  final List<WorkShift> shifts;
}

abstract class StaffRepository {
  Future<List<StaffBranch>> branches();
  Future<List<StaffMember>> list(int branchId, {int offset = 0});
  Future<void> save(StaffDraft draft, String key, {int? id});
  Future<void> setActive(StaffMember member, bool active, String key);
}
