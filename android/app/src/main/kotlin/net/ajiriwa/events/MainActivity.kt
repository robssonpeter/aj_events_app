package com.example.event_manager_new

import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "net.ajiriwa.events/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareToWhatsApp" -> {
                        val phone    = call.argument<String>("phone") ?: ""
                        val text     = call.argument<String>("text") ?: ""
                        val filePath = call.argument<String>("filePath") ?: ""
                        val success  = shareToWhatsApp(phone, text, filePath)
                        if (success) result.success(true)
                        else result.error("WHATSAPP_NOT_INSTALLED", "WhatsApp is not installed", null)
                    }
                    "isWhatsAppInstalled" -> {
                        result.success(isPackageInstalled("com.whatsapp") || isPackageInstalled("com.whatsapp.w4b"))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareToWhatsApp(phone: String, text: String, filePath: String): Boolean {
        // Try standard WhatsApp first, then WhatsApp Business
        val whatsappPackages = listOf("com.whatsapp", "com.whatsapp.w4b")
        val pkg = whatsappPackages.firstOrNull { isPackageInstalled(it) } ?: return false

        return try {
            // Strip everything except digits for the JID
            val digits = phone.replace(Regex("[^0-9]"), "")
            val jid = "$digits@s.whatsapp.net"

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/jpeg"
                setPackage(pkg)
                putExtra("jid", jid)                  // pre-selects the WhatsApp contact
                putExtra(Intent.EXTRA_TEXT, text)

                if (filePath.isNotEmpty()) {
                    val file = File(filePath)
                    val uri  = FileProvider.getUriForFile(
                        this@MainActivity,
                        "${applicationContext.packageName}.fileprovider",
                        file
                    )
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            }

            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
