import 'package:disastron/features/chat/presentation/service/chat_dashboard_context.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_device_provider.dart';
import 'package:disastron/features/dashboard/presentation/dashboard_weather_provider.dart';
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
