// OKRAlignmentShared/Services/DataEncryptionManager.swift

import Foundation
import os
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// 数据加密管理器
///
/// 功能：
/// - CoreData 存储加密（使用 NSFileProtectionComplete）
/// - 生物识别解锁（Face ID / Touch ID）
/// - 加密开关控制
///
/// ## 使用方式
/// ```swift
/// let manager = DataEncryptionManager.shared
/// let authenticated = await manager.authenticateWithBiometrics()
/// if authenticated {
///     // 允许访问数据
/// }
/// ```
public final class DataEncryptionManager: @unchecked Sendable {

    // MARK: - Shared Instance

    public static let shared = DataEncryptionManager()

    // MARK: - Constants

    private static let encryptionEnabledKey = "okr_data_encryption_enabled"
    private static let biometricEnabledKey = "okr_biometric_unlock_enabled"

    // MARK: - Properties

    /// 数据加密是否启用
    public var isEncryptionEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.encryptionEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.encryptionEnabledKey)
            Logger.app.info("数据加密已\(newValue ? "启用" : "禁用")")
        }
    }

    /// 生物识别解锁是否启用
    public var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.biometricEnabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.biometricEnabledKey)
            Logger.app.info("生物识别解锁已\(newValue ? "启用" : "禁用")")
        }
    }

    /// 生物识别类型名称（Face ID 或 Touch ID）
    public var biometricTypeName: String {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "不可用"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "生物识别"
        }
        #else
        return "不可用"
        #endif
    }

    /// 设备是否支持生物识别
    public var isBiometricAvailable: Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #else
        return false
        #endif
    }

    /// 文件保护级别
    public var protectionLevel: String {
        isEncryptionEnabled ? "NSFileProtectionComplete" : "NSFileProtectionCompleteUntilFirstUserAuthentication"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Biometric Authentication

    /// 使用生物识别进行身份验证
    /// - Parameter reason: 请求原因描述
    /// - Returns: 是否验证成功
    public func authenticateWithBiometrics(
        reason: String = "验证身份以访问 OKR 数据"
    ) async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "使用密码"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                AppErrorHandler.shared.handle(
                    AppErrorHandler.AppError.biometric(.notAvailable),
                    context: "生物识别不可用: \(error.localizedDescription)"
                )
            }
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success {
                Logger.app.info("生物识别认证成功")
            }
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                Logger.app.info("用户取消了生物识别认证")
            case .biometryNotEnrolled:
                AppErrorHandler.shared.handle(
                    AppErrorHandler.AppError.biometric(.notEnrolled),
                    context: "生物识别未录入"
                )
            case .authenticationFailed:
                AppErrorHandler.shared.handle(
                    AppErrorHandler.AppError.biometric(.authenticationFailed),
                    context: "生物识别认证失败"
                )
            default:
                AppErrorHandler.shared.handle(
                    AppErrorHandler.AppError.biometric(.authenticationFailed),
                    context: "生物识别错误: \(error.localizedDescription)"
                )
            }
            return false
        } catch {
            AppErrorHandler.shared.handle(
                AppErrorHandler.AppError.biometric(.authenticationFailed),
                context: "未知生物识别错误: \(error.localizedDescription)"
            )
            return false
        }
        #else
        return false
        #endif
    }

    /// 使用设备密码进行身份验证
    /// - Parameter reason: 请求原因描述
    /// - Returns: 是否验证成功
    public func authenticateWithDevicePasscode(
        reason: String = "验证身份以访问 OKR 数据"
    ) async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        context.localizedCancelTitle = "取消"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch {
            Logger.app.warning("设备密码认证失败: \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - File Protection

    /// 获取当前加密配置对应的 NSFileProtection 级别字符串
    /// 用于 CoreData store description 配置
    public func fileProtectionOption() -> String {
        if isEncryptionEnabled {
            return "NSFileProtectionComplete"
        } else {
            return "NSFileProtectionCompleteUntilFirstUserAuthentication"
        }
    }
}
