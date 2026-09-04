import Foundation
import CloudKit

// MARK: - iCloud backup (beta)
//
// Manual and explicit: CloudKit rides the device's existing iCloud sign-in,
// so RPGFit has no account system of its own. One record in the user's
// PRIVATE database carries the save file in an encryptedValues field.
// Backups happen only when the user taps a button; nothing syncs in the
// background.

final class CloudBackupManager {
    static let shared = CloudBackupManager()

    static let lastBackupKey = "cloudBackupLastDate"

    private let container = CKContainer(identifier: "iCloud.com.devoncheng.RPGFitMVP")
    private let recordID = CKRecord.ID(recordName: "rpgfit-save")
    private static let recordType = "SaveFile"
    /// encryptedValues Data fields cap out at ~1MB; refuse politely past it.
    private static let maxPayloadBytes = 900_000

    enum BackupError: LocalizedError {
        case noAccount
        case tooLarge
        case noBackupFound
        case operationIncomplete

        var errorDescription: String? {
            switch self {
            case .noAccount:
                return "Sign in to iCloud in the Settings app first."
            case .tooLarge:
                return "This save file is too large for iCloud backup right now."
            case .noBackupFound:
                return "No iCloud backup exists for this character yet."
            case .operationIncomplete:
                return "iCloud did not finish that backup request. Please try again."
            }
        }
    }

    /// Whether this binary was signed with the iCloud entitlement. Simulator
    /// builds skip device provisioning entirely; device builds signed by a
    /// personal (free) Apple team use the reduced Debug entitlements (no
    /// iCloud), and the backup UI must downgrade honestly instead of letting
    /// CKContainer throw at first touch.
    static var entitlementPresent: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let profile = try? String(contentsOfFile: path, encoding: .isoLatin1) else {
            // No embedded profile means App Store / TestFlight signing,
            // where the full entitlements always shipped.
            return true
        }
        return profile.contains("com.apple.developer.icloud-services")
        #endif
    }

    private func requireAccount() async throws {
        let status = try await container.accountStatus()
        guard status == .available else { throw BackupError.noAccount }
    }

    /// Uploads the encoded save file, replacing any previous backup.
    func backUp(_ data: Data) async throws {
        try await requireAccount()
        guard data.count <= Self.maxPayloadBytes else { throw BackupError.tooLarge }

        let database = container.privateCloudDatabase
        let record: CKRecord
        if let existing = try? await database.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
        }
        record.encryptedValues["payload"] = data
        record["savedAt"] = Date()
        let results = try await database.modifyRecords(saving: [record], deleting: [],
                                                       savePolicy: .allKeys)
        guard let saveResult = results.saveResults[record.recordID] else {
            throw BackupError.operationIncomplete
        }
        _ = try saveResult.get()
        UserDefaults.standard.set(Date(), forKey: Self.lastBackupKey)
    }

    /// Downloads the most recent backup payload.
    func restore() async throws -> Data {
        try await requireAccount()
        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            guard let data = record.encryptedValues["payload"] as? Data else {
                throw BackupError.noBackupFound
            }
            return data
        } catch let error as CKError where error.code == .unknownItem {
            throw BackupError.noBackupFound
        }
    }

    /// Removes the save record from the user's private iCloud database.
    /// A record that is already absent is the desired end state, not an error.
    func deleteBackup() async throws {
        try await requireAccount()

        do {
            let results = try await container.privateCloudDatabase.modifyRecords(
                saving: [], deleting: [recordID], savePolicy: .allKeys
            )
            guard let deleteResult = results.deleteResults[recordID] else {
                throw BackupError.operationIncomplete
            }
            do {
                try deleteResult.get()
            } catch {
                guard Self.isUnknownItem(error, recordID: recordID) else { throw error }
            }
        } catch {
            guard Self.isUnknownItem(error, recordID: recordID) else { throw error }
        }

        UserDefaults.standard.removeObject(forKey: Self.lastBackupKey)
    }

    private static func isUnknownItem(_ error: Error, recordID: CKRecord.ID) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .unknownItem { return true }
        if cloudError.code == .partialFailure,
           let itemError = cloudError.partialErrorsByItemID?[recordID] {
            return isUnknownItem(itemError, recordID: recordID)
        }
        return false
    }

    static var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: lastBackupKey) as? Date
    }
}

extension AppState {
    /// Encodes the current profile+history exactly as the save file does.
    func encodedSaveData() throws -> Data {
        try Self.jsonEncoder.encode(PersistedData(user: user, history: history))
    }

    /// Replaces the in-memory state with a restored backup and persists it.
    func applyRestoredSave(_ data: Data) throws {
        try replaceState(withValidatedSave: data)
        pushToast(title: "Backup Restored",
                  subtitle: "Your character is back from the cloud vault",
                  icon: "icloud.and.arrow.down.fill", kind: .accent)
    }
}
