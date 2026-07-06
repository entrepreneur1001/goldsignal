package com.goldsignal.goldsignal

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.DrawableRes
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.DrawableCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class GoldPriceWidget : HomeWidgetProvider() {

    private val upColor = 0xFF2EBD85.toInt()
    private val downColor = 0xFFF6465D.toInt()

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val currency = widgetData.getString("currency", "USD") ?: "USD"
        val updated = widgetData.getString("last_updated", "") ?: ""

        val refreshBitmap = drawableToBitmap(context, R.drawable.ic_refresh)
        val settingsBitmap = drawableToBitmap(context, R.drawable.ic_settings)
        val metalGlyphBitmap = drawableToBitmap(context, R.drawable.ic_metal_glyph)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.gold_price_widget)

            views.setTextViewText(R.id.widget_currency, currency)
            views.setTextViewText(
                R.id.widget_updated,
                if (updated.isEmpty()) "" else "· $updated",
            )

            views.setImageViewBitmap(R.id.widget_refresh, refreshBitmap)
            views.setImageViewBitmap(R.id.widget_settings, settingsBitmap)
            views.setImageViewBitmap(R.id.gold_icon, metalGlyphBitmap)
            views.setImageViewBitmap(R.id.silver_icon, metalGlyphBitmap)

            bindRow(
                views, widgetData, "gold", currency,
                R.id.gold_row, R.id.gold_label, R.id.gold_sub,
                R.id.gold_price, R.id.gold_change,
            )
            bindRow(
                views, widgetData, "silver", currency,
                R.id.silver_row, R.id.silver_label, R.id.silver_sub,
                R.id.silver_price, R.id.silver_change,
            )

            // Tapping the card opens the app.
            views.setOnClickPendingIntent(
                R.id.widget_container,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            // Settings icon → open the app on the widget settings route.
            views.setOnClickPendingIntent(
                R.id.widget_settings,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("goldsignal://widget?action=settings"),
                ),
            )

            // Refresh icon → open the app and trigger a full price refresh (iOS parity).
            views.setOnClickPendingIntent(
                R.id.widget_refresh,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("goldsignal://widget?action=refresh"),
                ),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun bindRow(
        views: RemoteViews,
        data: SharedPreferences,
        prefix: String,
        currency: String,
        rowId: Int,
        labelId: Int,
        subId: Int,
        priceId: Int,
        changeId: Int,
    ) {
        if (!data.getBoolean("${prefix}_present", false)) {
            views.setViewVisibility(rowId, View.GONE)
            return
        }
        views.setViewVisibility(rowId, View.VISIBLE)

        val label = data.getString("${prefix}_label", "") ?: ""
        val price = data.getString("${prefix}_price", "--") ?: "--"
        val change = data.getString("${prefix}_change", "") ?: ""
        val changePct = data.getString("${prefix}_change_pct", "") ?: ""
        val positive = data.getBoolean("${prefix}_positive", true)

        views.setTextViewText(labelId, label)
        views.setTextViewText(subId, "$currency / gram")
        views.setTextViewText(priceId, price)
        views.setTextViewText(
            changeId,
            if (change.isEmpty()) "" else "$change  $changePct",
        )
        views.setTextColor(changeId, if (positive) upColor else downColor)
    }

    companion object {
        /** RemoteViews cannot inflate vector drawables from XML; rasterize in code. */
        private fun drawableToBitmap(context: Context, @DrawableRes resId: Int): Bitmap {
            val drawable = requireNotNull(ContextCompat.getDrawable(context, resId))
            val wrapped = DrawableCompat.wrap(drawable).mutate()
            val width = if (wrapped.intrinsicWidth > 0) wrapped.intrinsicWidth else 1
            val height = if (wrapped.intrinsicHeight > 0) wrapped.intrinsicHeight else 1
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            wrapped.setBounds(0, 0, canvas.width, canvas.height)
            wrapped.draw(canvas)
            return bitmap
        }
    }
}
