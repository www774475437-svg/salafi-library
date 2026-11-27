"""Runs on GitHub after `flutter create`: Arabic app name, internet permission,
launch colour and the fixed signing key (so every new APK installs over the old one)."""
import re
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text(encoding="utf-8")
m = re.sub(r'android:label="[^"]*"', 'android:label="مكتبة العلماء"', m, count=1)
for p in ["android.permission.INTERNET", "android.permission.POST_NOTIFICATIONS"]:
    if p not in m:
        m = m.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)
# links (Telegram, the website) open in the browser
if "android.intent.action.VIEW" not in m.split("<application")[0]:
    q = ('<queries><intent><action android:name="android.intent.action.VIEW"/>'
         '<data android:scheme="https"/></intent></queries>')
    m = m.replace("<application", q + "\n    <application", 1)
# the review reminder and the «فائدة اليوم» widget of the home screen
if "ReminderReceiver" not in m:
    m = m.replace("</application>", '''    <receiver android:name=".ReminderReceiver" android:exported="false"/>
        <receiver android:name=".FaidaWidget" android:exported="true" android:label="فائدة اليوم">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/faida_widget_info"/>
        </receiver>
    </application>''', 1)
manifest.write_text(m, encoding="utf-8")
print("Manifest patched")

res = Path("android/app/src/main/res")
for d in ["xml", "layout", "drawable"]:
    (res / d).mkdir(parents=True, exist_ok=True)
(res / "xml/faida_widget_info.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="21600000"
    android:initialLayout="@layout/faida_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
''', encoding="utf-8")
(res / "layout/faida_widget.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/faida_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/faida_widget_bg"
    android:layoutDirection="rtl"
    android:orientation="vertical"
    android:padding="14dp">
    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="فائدة اليوم"
        android:textColor="#E1C478"
        android:textDirection="rtl"
        android:textSize="13sp"
        android:textStyle="bold" />
    <TextView
        android:id="@+id/faida_text"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:ellipsize="end"
        android:gravity="center_vertical"
        android:lineSpacingMultiplier="1.25"
        android:maxLines="7"
        android:textColor="#F3E9CF"
        android:textDirection="rtl"
        android:textSize="15sp" />
    <TextView
        android:id="@+id/faida_source"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:ellipsize="end"
        android:maxLines="1"
        android:textColor="#B3F3E9CF"
        android:textDirection="rtl"
        android:textSize="11.5sp" />
</LinearLayout>
''', encoding="utf-8")
(res / "drawable/faida_widget_bg.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <corners android:radius="22dp" />
    <gradient android:angle="270" android:startColor="#13294A" android:endColor="#081426" />
</shape>
''', encoding="utf-8")
# the small picture of the notification: an open book, in one colour as Android asks
(res / "drawable/ic_stat_book.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFF" android:pathData="M12,6.5C10.5,5.2 8,4.5 5,4.5c-1.1,0 -2.1,0.1 -3,0.4v13.6c0.9,-0.3 1.9,-0.5 3,-0.5c3,0 5.5,0.8 7,2c1.5,-1.2 4,-2 7,-2c1.1,0 2.1,0.2 3,0.5V4.9c-0.9,-0.3 -1.9,-0.4 -3,-0.4C16,4.5 13.500,5.2 12,6.5zM13,8.200c1.300,-0.900 3.400,-1.500 6,-1.500c0.300,0 0.700,0 1,0.100v9.300c-0.300,0 -0.700,-0.100 -1,-0.100c-2.300,0 -4.400,0.500 -6,1.300V8.200z" />
</vector>
''', encoding="utf-8")
print("Widget and notification resources written")

kts = Path("android/app/build.gradle.kts")
g = kts.read_text(encoding="utf-8")
if "keyProps" not in g:
    g = "import java.util.Properties\n" + g
    g = g.replace("android {", '''val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
android {''', 1)
    g = g.replace("    buildTypes {", '''    signingConfigs {
        if (keyProps.isNotEmpty()) {
            create("release") {
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
            }
        }
    }
    buildTypes {''', 1)
    g = g.replace('signingConfig = signingConfigs.getByName("debug")',
                  'signingConfig = if (keyProps.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")', 1)
kts.write_text(g, encoding="utf-8")
print("build.gradle.kts patched")

for d in ["drawable", "drawable-v21"]:
    lb = Path(f"android/app/src/main/res/{d}/launch_background.xml")
    if lb.exists():
        lb.write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item><color android:color="#F6F3EC" /></item>
</layer-list>
''', encoding="utf-8")
print("Launch background set")

# the screen stays lit while reading, and the volume buttons can turn the pages
for act in Path("android/app/src/main/kotlin").rglob("MainActivity.kt"):
    pkg = re.search(r"^package\s+([\w.]+)", act.read_text(encoding="utf-8"), re.M).group(1)
    act.write_text(f'''package {pkg}

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    private var channel: MethodChannel? = null
    private var volumeKeys = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "salafi_library/screen")
        channel = ch
        ch.setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "keepOn" -> {{
                    if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }}
                "volumeKeys" -> {{
                    volumeKeys = call.arguments == true
                    result.success(null)
                }}
                "askNotify" -> {{
                    if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 7)
                    result.success(null)
                }}
                "remind" -> {{
                    // one reminder at a time; a time of zero only removes it
                    val at = call.argument<Number>("at")?.toLong() ?: 0L
                    val i = Intent(this, ReminderReceiver::class.java)
                        .putExtra("title", call.argument<String>("title") ?: "")
                        .putExtra("text", call.argument<String>("text") ?: "")
                    val pi = PendingIntent.getBroadcast(this, 70, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    am.cancel(pi)
                    if (at > 0L) am.set(AlarmManager.RTC_WAKEUP, at, pi)
                    result.success(null)
                }}
                "widget" -> {{
                    getSharedPreferences("faida_widget", Context.MODE_PRIVATE).edit()
                        .putString("items", call.argument<String>("items") ?: "[]")
                        .putLong("start", call.argument<Number>("start")?.toLong() ?: 0L)
                        .apply()
                    val mgr = AppWidgetManager.getInstance(this)
                    FaidaWidget.updateAll(this, mgr, mgr.getAppWidgetIds(ComponentName(this, FaidaWidget::class.java)))
                    result.success(null)
                }}
                else -> result.notImplemented()
            }}
        }}
    }}

    private fun isVolume(keyCode: Int) = keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {{
        if (volumeKeys && isVolume(keyCode)) {{
            channel?.invokeMethod("volume", if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) 1 else -1)
            return true
        }}
        return super.onKeyDown(keyCode, event)
    }}

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {{
        if (volumeKeys && isVolume(keyCode)) return true
        return super.onKeyUp(keyCode, event)
    }}
}}
''', encoding="utf-8")
    print("MainActivity patched")

    (act.parent / "ReminderReceiver.kt").write_text(f'''package {pkg}

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Shows the reminder that the app asked for; a touch opens the app. */
class ReminderReceiver : BroadcastReceiver() {{
    override fun onReceive(context: Context, intent: Intent) {{
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {{
            nm.createNotificationChannel(NotificationChannel("review", "مراجعة الفوائد", NotificationManager.IMPORTANCE_DEFAULT))
        }}
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, "review") else Notification.Builder(context)
        b.setSmallIcon(R.drawable.ic_stat_book)
            .setContentTitle(intent.getStringExtra("title") ?: "")
            .setContentText(intent.getStringExtra("text") ?: "")
            .setAutoCancel(true)
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (open != null) {{
            b.setContentIntent(PendingIntent.getActivity(context, 71, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }}
        try {{
            nm.notify(71, b.build())
        }} catch (e: Exception) {{
        }}
    }}
}}
''', encoding="utf-8")
    (act.parent / "FaidaWidget.kt").write_text(f'''package {pkg}

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import java.util.TimeZone
import org.json.JSONArray

/** «فائدة اليوم» on the home screen: a new saying each day, from the list the app left here. */
class FaidaWidget : AppWidgetProvider() {{
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {{
        updateAll(context, appWidgetManager, appWidgetIds)
    }}

    companion object {{
        fun updateAll(context: Context, mgr: AppWidgetManager, ids: IntArray) {{
            var text = "افتح المكتبة مرة لتظهر فائدة اليوم هنا"
            var source = ""
            try {{
                val p = context.getSharedPreferences("faida_widget", Context.MODE_PRIVATE)
                val arr = JSONArray(p.getString("items", "[]"))
                if (arr.length() > 0) {{
                    val now = System.currentTimeMillis()
                    val day = (now + TimeZone.getDefault().getOffset(now)) / 86400000L
                    val n = arr.length().toLong()
                    val i = (((day - p.getLong("start", day)) % n) + n) % n
                    val o = arr.getJSONArray(i.toInt())
                    text = o.getString(0)
                    source = o.getString(1)
                }}
            }} catch (e: Exception) {{
            }}
            for (id in ids) {{
                val v = RemoteViews(context.packageName, R.layout.faida_widget)
                v.setTextViewText(R.id.faida_text, text)
                v.setTextViewText(R.id.faida_source, source)
                val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (open != null) {{
                    v.setOnClickPendingIntent(R.id.faida_root, PendingIntent.getActivity(context, 72, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                }}
                mgr.updateAppWidget(id, v)
            }}
        }}
    }}
}}
''', encoding="utf-8")
    print("Reminder and widget classes written")
