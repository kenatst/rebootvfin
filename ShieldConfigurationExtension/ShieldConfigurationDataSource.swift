import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Tiny REBOOT shield: no shame, no stats, no clichés.
final class ShieldConfigurationDataSource: ManagedSettingsUI.ShieldConfigurationDataSource {
    private func rebootConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundColor: UIColor(red: 0.976, green: 0.969, blue: 0.945, alpha: 1),
            title: ShieldConfiguration.Label(
                text: "Focus protected",
                color: UIColor(red: 0.094, green: 0.075, blue: 0.055, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This can wait.",
                color: UIColor(red: 0.373, green: 0.353, blue: 0.329, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.094, green: 0.075, blue: 0.055, alpha: 1)
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        rebootConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        rebootConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        rebootConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        rebootConfiguration()
    }
}
