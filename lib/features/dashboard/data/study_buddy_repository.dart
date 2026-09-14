import '../domain/dashboard_models.dart';

abstract interface class StudyBuddyRepository {
  StudyBuddyState loadInitialState();
}

class InMemoryStudyBuddyRepository implements StudyBuddyRepository {
  const InMemoryStudyBuddyRepository();

  @override
  StudyBuddyState loadInitialState() {
    return const StudyBuddyState();
  }
}
