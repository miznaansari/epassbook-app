import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String _groupId = 'group.com.fintrust.passbook.passbookApp';
  static const String _androidWidgetName = 'PassbookWidgetProvider';
  static const String _iosWidgetName = 'PassbookWidget';

  /// Saves values to shared preferences/App Groups and requests a widget redraw.
  static Future<void> updateWidgetData({
    required double availableBalance,
    required double shareValue,
    required double sipValue,
    required String currencySymbol,
  }) async {
    try {
      if (kDebugMode) {
        print("Syncing widget values: Balance=$availableBalance, Shares=$shareValue, SIP=$sipValue");
      }

      // Configure iOS App Group ID
      await HomeWidget.setAppGroupId(_groupId);

      // Save formatted strings to make native rendering simple
      await HomeWidget.saveWidgetData<String>(
        'availableBalance',
        '$currencySymbol${availableBalance.toStringAsFixed(2)}',
      );
      await HomeWidget.saveWidgetData<String>(
        'shareValue',
        '$currencySymbol${shareValue.toStringAsFixed(2)}',
      );
      await HomeWidget.saveWidgetData<String>(
        'sipValue',
        '$currencySymbol${sipValue.toStringAsFixed(2)}',
      );

      // Trigger native widget update
      final bool? success = await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: _iosWidgetName,
      );

      if (kDebugMode) {
        print("Widget update requested. Success status: $success");
      }
    } catch (e) {
      debugPrint("Error updating home widget data: $e");
    }
  }
}
