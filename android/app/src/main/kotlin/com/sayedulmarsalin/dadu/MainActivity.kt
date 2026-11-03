package com.sayedulmarsalin.dadu

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val display = windowManager.defaultDisplay
                val modes = display.supportedModes
                if (modes != null && modes.isNotEmpty()) {
                    var maxMode = modes[0]
                    for (mode in modes) {
                        if (mode.refreshRate > maxMode.refreshRate) {
                            maxMode = mode
                        }
                    }
                    val params = window.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    window.attributes = params
                }
            } catch (e: Exception) {
                // Ignore if display mode switching not supported by hardware/ROM
            }
        }
    }
}
