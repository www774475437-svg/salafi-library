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
