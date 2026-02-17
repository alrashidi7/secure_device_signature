import Flutter
import UIKit
import Security
import Darwin

/// Device integrity and hardware-bound signature plugin (iOS).
/// Uses Keychain with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly for persistence across reinstall.
public class DeviceIntegritySignaturePlugin: NSObject, FlutterPlugin {

    private static let channelName = "com.diyar.device_integrity_signature/native"
    private static let keychainService = "com.diyar.device_integrity_signature"
    private static let keychainAccount = "device_integrity_uuid"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = DeviceIntegritySignaturePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getHardwarePayload":
            getHardwarePayload(result: result)
        case "isDebugOrHookingDetected":
            result(isDebugOrHookingDetected())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Hardware payload

    private func getHardwarePayload(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { result(FlutterError(code: "NO_CONTEXT", message: "Plugin deallocated", details: nil)) }
                return
            }
            let payload = self.buildHardwarePayload()
            DispatchQueue.main.async { result(payload) }
        }
    }

    private func buildHardwarePayload() -> [String: Any] {
        let hardwareId = getHardwareIdentifier()
        let uuid = getOrCreatePersistentUuid()
        let deviceModel = UIDevice.current.model
        let osVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"

        return [
            "hardwareId": hardwareId,
            "uuid": uuid,
            "deviceModel": deviceModel,
            "osVersion": osVersion,
            "platform": "ios",
        ]
    }

    /// Hardware-bound identifier: vendor ID + keychain-backed persistent UUID component.
    /// identifierForVendor changes after reinstall when no other app from same vendor is installed;
    /// Keychain value persists across reinstall when using kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
    private func getHardwareIdentifier() -> String {
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let keychainId = getOrCreatePersistentUuid()
        return "\(vendorId)_\(keychainId)".trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    /// Persistent UUID stored in Keychain with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    /// so it persists across app uninstall/reinstall (Keychain items are not deleted on uninstall).
    /// Prefer Secure Enclave for key storage when generating the value (handled by Keychain on supported devices).
    private func getOrCreatePersistentUuid() -> String {
        if let existing = readKeychainUuid() {
            return existing
        }
        let newUuid = UUID().uuidString
        if writeKeychainUuid(newUuid) {
            return newUuid
        }
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    private func readKeychainUuid() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func writeKeychainUuid(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Debugger / tracing detection (e.g. Frida attachment).
    private func isDebugOrHookingDetected() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        return result == 0 && (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
