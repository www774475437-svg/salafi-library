"""Runs on GitHub after `flutter create`: Arabic app name, internet permission,
launch colour and the fixed signing key (so every new APK installs over the old one)."""
import re
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text(encoding="utf-8")
m = re.sub(r'android:label="[^"]*"', 'android:label="مكتبة العلماء"', m, count=1)
for p in ["android.permission.INTERNET"]:
    if p not in m:
        m = m.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)
# links (Telegram, the website) open in the browser
if "android.intent.action.VIEW" not in m.split("<application")[0]:
    q = ('<queries><intent><action android:name="android.intent.action.VIEW"/>'
         '<data android:scheme="https"/></intent></queries>')
    m = m.replace("<application", q + "\n    <application", 1)
manifest.write_text(m, encoding="utf-8")
print("Manifest patched")

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
