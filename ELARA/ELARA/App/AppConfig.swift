import Foundation

/// Central place for the product name and other app-wide constants.
/// To rebrand, change it here and PRODUCT_NAME in the project.
enum AppConfig {
    static let appName = "E-LARA"
    static let tagline = "Your media, all together."
    /// Name used for app data folders before the rename; its data is moved over on first launch.
    static let legacyDataFolderName = "MediaHub"
}
