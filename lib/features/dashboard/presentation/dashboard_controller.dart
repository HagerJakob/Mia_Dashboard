import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_mock_repository.dart';
import '../domain/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardMockRepository>((ref) {
  return const DashboardMockRepository();
});

final dashboardDataProvider = Provider<DashboardData>((ref) {
  return ref.watch(dashboardRepositoryProvider).loadDashboard();
});
