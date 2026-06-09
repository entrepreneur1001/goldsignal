package com.goldsignal.goldsignal

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class GoldPriceWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val label = widgetData.getString("widget_label", "Gold") ?: "Gold"
        val price = widgetData.getString("gold_price", "--") ?: "--"
        val currency = widgetData.getString("currency", "USD") ?: "USD"
        val change = widgetData.getString("gold_change", "") ?: ""
        val positive = widgetData.getBoolean("change_positive", true)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.gold_price_widget)
            views.setTextViewText(R.id.widget_title, label)
            views.setTextViewText(R.id.widget_price, "$price $currency/g")
            views.setTextViewText(
                R.id.widget_change,
                if (change.isEmpty()) "24h change" else "24h $change",
            )
            val changeColor = if (positive) 0xFF2E7D32.toInt() else 0xFFC62828.toInt()
            views.setTextColor(R.id.widget_change, changeColor)
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
