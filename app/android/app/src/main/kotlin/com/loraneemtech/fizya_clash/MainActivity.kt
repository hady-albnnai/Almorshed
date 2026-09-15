package com.loraneemtech.fizya_clash

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

// A3 — حماية الشاشة (قرار 62): FLAG_SECURE على التطبيق كله
// يمنع لقطة الشاشة وتسجيل الشاشة والبث — أسود. معلوم أنه لا يمنع تصوير هاتف آخر.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)
    }
}
