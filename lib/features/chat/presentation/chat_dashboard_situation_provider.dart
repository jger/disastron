import 'package:disastron/features/chat/domain/chat_dashboard_context.dart';
import 'package:disastron/features/dashboard/dashboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aggregates [dashboardDeviceProvider] + [dashboardWeatherProvider] into one text block.
final FutureProvider<String> chatDashboardSituationProvider =
    FutureProvider<String>((Ref ref) async {
      final DashboardDeviceSnapshot device = await ref.watch(
        dashboardDeviceProvider.future,
      );
      final DashboardWeatherSnapshot weather = await ref.watch(
        dashboardWeatherProvider.future,
      );
      return formatChatDashboardSituation(device: device, weather: weather);
    });
