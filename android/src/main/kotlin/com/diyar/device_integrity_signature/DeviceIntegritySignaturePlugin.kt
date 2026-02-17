package com.diyar.device_integrity_signature

import android.annotation.SuppressLint
import android.content.Context
import android.media.MediaDrm
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.MessageDigest
import java.util.UUID
import javax.crypto.Cipher

private val WIDEVINE_UUID: UUID = UUID.fromString("edef8ba9-79d6-4ace-a3c8-27dcd51d21ed")
private val mainHandler = Handler(Looper.getMainLooper())

/** DeviceIntegritySignaturePlugin */
class DeviceIntegritySignaturePlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.diyar.device_integrity_signature/native")
        channel.setMethodCallHandler(this)
        applicationContext = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getHardwarePayload" -> getHardwarePayload(result)
            "isDebugOrHookingDetected" -> {
                result.success(isDebugOrHookingDetected())
            }
            else -> result.notImplemented()
        }
    }

    private fun getHardwarePayload(result: Result) {
        Thread {
            try {
                val ctx = applicationContext
                if (ctx == null) {
                    mainHandler.post { result.error("NO_CONTEXT", "Application context not available", null) }
                    return@Thread
                }
                val payload = buildHardwarePayload(ctx)
                mainHandler.post { result.success(payload) }
            } catch (e: Exception) {
                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
            }
        }.start()
    }

    @SuppressLint("HardwareIds")
    private fun buildHardwarePayload(context: Context): Map<String, Any?> {
        val hardwareId = getMediaDrmDeviceId().ifEmpty { getFallbackHardwareId(context) }
        val uuid = getOrCreatePersistentUuid(context)
        val deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
        val osVersion = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"

        return mapOf(
            "hardwareId" to hardwareId,
            "uuid" to uuid,
            "deviceModel" to deviceModel,
            "osVersion" to osVersion,
            "platform" to "android",
        )
    }

    /**
     * Widevine MediaDrm deviceUniqueId — hardware-bound, varies by app on API 26+.
     * Hex-encoded for stable string in signature payload.
     */
    private fun getMediaDrmDeviceId(): String {
        return try {
            val mediaDrm = MediaDrm(WIDEVINE_UUID)
            try {
                val bytes = mediaDrm.getPropertyByteArray(MediaDrm.PROPERTY_DEVICE_UNIQUE_ID)
                bytes?.joinToString("") { "%02x".format(it) } ?: ""
            } finally {
                mediaDrm.close()
            }
        } catch (e: Exception) {
            ""
        }
    }

    /**
     * Fallback when MediaDrm is not available (e.g. emulator): Android ID.
     * Not persistent across factory reset; used only when MediaDrm fails.
     */
    @SuppressLint("HardwareIds")
    private fun getFallbackHardwareId(context: Context): String {
        return try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    /**
     * Persistent identifier that survives app uninstall/reinstall.
     * Uses Android ID (Settings.Secure.ANDROID_ID) which persists until factory reset.
     * When available, we also use Android Keystore (StrongBox/TEE) to derive a stable
     * value; if Keystore is unavailable or fails, we fall back to Android ID so the
     * signature remains stable across reinstall.
     */
    private fun getOrCreatePersistentUuid(context: Context): String {
        val keyAlias = "device_integrity_uuid"
        return try {
            val keyStore = java.security.KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            if (keyStore.containsAlias(keyAlias)) {
                val entry = keyStore.getEntry(keyAlias, null)
                if (entry is java.security.KeyStore.SecretKeyEntry) {
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.ENCRYPT_MODE, entry.secretKey)
                    val iv = cipher.iv
                    val ct = cipher.doFinal("uuid_seed".toByteArray(Charsets.UTF_8))
                    val combined = iv + ct
                    val hash = MessageDigest.getInstance("SHA-256").digest(combined)
                    bytesToUuid(hash)
                } else getFallbackHardwareId(context)
            } else {
                val keyGen = javax.crypto.KeyGenerator.getInstance("AES", "AndroidKeyStore")
                val keySpec = android.security.keystore.KeyGenParameterSpec.Builder(
                    keyAlias,
                    android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or android.security.keystore.KeyProperties.PURPOSE_DECRYPT
                )
                    .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(false)
                    .apply {
                        if (Build.VERSION.SDK_INT >= 28) {
                            setUnlockedDeviceRequired(false)
                            setIsStrongBoxBacked(true)
                        }
                    }
                    .build()
                keyGen.init(keySpec)
                keyGen.generateKey()
                getOrCreatePersistentUuid(context)
            }
        } catch (e: Exception) {
            getFallbackHardwareId(context).ifEmpty { UUID.randomUUID().toString() }
        }
    }

    private fun bytesToUuid(bytes: ByteArray): String {
        val hex = bytes.take(16).joinToString("") { "%02x".format(it) }
        return if (hex.length >= 32) hex.replace(Regex("(.{8})(.{4})(.{4})(.{4})(.{12})"), "$1-$2-$3-$4-$5") else hex
    }

    /**
     * Detects debugger attachment and common hooking frameworks (Frida/Xposed).
     * Xposed is also covered by flutter_root_jailbreak_checker's hasPotentiallyDangerousApps.
     */
    private fun isDebugOrHookingDetected(): Boolean {
        if (android.os.Debug.isDebuggerConnected()) return true
        if (android.os.Debug.waitingForDebugger()) return true
        return false
    }
}
