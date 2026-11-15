import 'package:medcollab_app/features/auth/data/models/user_model.dart';

/// Doctors offered in the handoff "Assigned doctor" dropdown, plus the
/// dropdown value to show.
///
/// `DropdownButtonFormField` asserts that its value is exactly one of the
/// item values. Member rows can repeat a user, and a saved handoff's
/// assignee is a different [UserModel] instance than the member row, so
/// this de-duplicates by id and returns the list instance whose id matches
/// [assigned] (or `null` if the assignee is no longer a member).
({List<UserModel> doctors, UserModel? selected}) handoffDoctorOptions(
  Iterable<UserModel> memberUsers,
  UserModel? assigned,
) {
  final doctors = <UserModel>[];
  final seenIds = <String>{};
  for (final user in memberUsers) {
    if (user.id.isEmpty || !seenIds.add(user.id)) continue;
    doctors.add(user);
  }
  final assignedId = assigned?.id;
  UserModel? selected;
  if (assignedId != null && assignedId.isNotEmpty) {
    for (final user in doctors) {
      if (user.id == assignedId) {
        selected = user;
        break;
      }
    }
  }
  return (doctors: doctors, selected: selected);
}
