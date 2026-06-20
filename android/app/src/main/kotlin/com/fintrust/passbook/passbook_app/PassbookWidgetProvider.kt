package com.fintrust.passbook.passbook_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PassbookWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.passbook_widget).apply {
                // Get the string values saved from Flutter
                val balance = widgetData.getString("availableBalance", "--")
                val stocks = widgetData.getString("shareValue", "--")
                val sips = widgetData.getString("sipValue", "--")

                // Update text views
                setTextViewText(R.id.value_balance, balance)
                setTextViewText(R.id.value_stocks, stocks)
                setTextViewText(R.id.value_sips, sips)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
