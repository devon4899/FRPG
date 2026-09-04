import SwiftUI

// MARK: - Privacy policy & support
//
// The policy ships IN the app because there is nothing server-side to
// disclose — it documents exactly what the code does, and must be kept in
// lockstep with it (HealthKit writing, exports, reset semantics).

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        section("Stored on your device by default",
                                "Your workouts, character, and settings are stored on this device. RPGFit has no account system, analytics, ads, or tracking. The app contacts iCloud only when you choose Back Up, Restore, or Delete iCloud Backup.")

                        HairlineRule()

                        section("Apple Health is optional and write-only",
                                "If you turn on \u{201C}Save Workouts to Health\u{201D}, each finished training session is written to Apple Health as a strength workout. RPGFit never reads your Health data, and the toggle is off until you enable it.")

                        HairlineRule()

                        section("Exports are yours to share",
                                "The CSV export creates a file on your device. RPGFit does not upload it; the file goes only where you choose to send or save it.")

                        HairlineRule()

                        section("iCloud backup is optional and private",
                                "If you use \u{201C}Back Up Now\u{201D}, RPGFit sends your save file to your private iCloud database using CloudKit encrypted storage. Backups happen only when you request them — nothing syncs automatically, and RPGFit has no account of its own. You can delete the iCloud copy separately in Settings.")

                        HairlineRule()

                        section("Reset erases this device",
                                "\u{201C}Reset All Data\u{201D} permanently deletes the save file, its automatic local backup, and every stored setting on this device. An optional iCloud backup remains available until you use \u{201C}Delete iCloud Backup\u{201D} separately.")

                        HairlineRule()

                        section("Questions",
                                "This policy describes the app's actual behavior. If anything seems off, use Contact Support in Settings.")

                        Text("Last updated September 1, 2026")
                            .font(RPGTheme.label(11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: AppLayout.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(RPGTheme.heading(.headline, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.body)
                .foregroundColor(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
