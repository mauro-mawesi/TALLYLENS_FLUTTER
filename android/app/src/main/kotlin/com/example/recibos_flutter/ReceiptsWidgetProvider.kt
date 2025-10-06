package com.example.recibos_flutter

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.app.PendingIntent

class ReceiptsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            val monthlyTotal = prefs.getString("monthly_total", "$0.00") ?: "$0.00"
            val receiptCount = prefs.getInt("receipt_count", 0)
            val lastMerchant = prefs.getString("last_merchant", "No receipts") ?: "No receipts"
            val lastAmount = prefs.getString("last_amount", "$0.00") ?: "$0.00"

            val views = RemoteViews(context.packageName, R.layout.receipts_widget)

            // Update widget content
            views.setTextViewText(R.id.monthly_total, monthlyTotal)
            views.setTextViewText(R.id.receipt_count, "$receiptCount receipts")
            views.setTextViewText(R.id.last_merchant, lastMerchant)
            views.setTextViewText(R.id.last_amount, lastAmount)

            // Click action to open app
            val intent = Intent(Intent.ACTION_VIEW)
            intent.data = Uri.parse("receipts://scan")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Scan button action
            val scanIntent = Intent(Intent.ACTION_VIEW)
            scanIntent.data = Uri.parse("receipts://scan")
            scanIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

            val scanPendingIntent = PendingIntent.getActivity(
                context,
                1,
                scanIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.scan_button, scanPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
