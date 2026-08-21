import CoreGraphics

/// Exact px→pt mapping of the web spacing scale (16px root). See DESIGN_MAPPING.md section 3.
enum AppSpacing {
    static let screenPadding: CGFloat = 24      // px-6
    static let safeTopMin: CGFloat = 20         // safe-top floor
    static let safeBottomMin: CGFloat = 28      // safe-bottom floor

    static let xs: CGFloat = 12                 // mt-3 (hint after title)
    static let sm: CGFloat = 16                 // mt-4 (body after title)
    static let md: CGFloat = 24                 // p-6 (card padding)
    static let lg: CGFloat = 32                 // mt-8 (options / CTA)
    static let xl: CGFloat = 40                 // pt-10 (diagnosis main top)
    static let twoXL: CGFloat = 64              // pt-16 (fade above fixed CTA)

    static let choicesGap: CGFloat = 10         // space-y-2.5
    static let choicesBottom: CGFloat = 160     // pb-40 scroll runway
    static let headerGap: CGFloat = 16          // gap-4
    static let cardStack: CGFloat = 12          // space-y-3 (report)
    static let gridGap: CGFloat = 12            // gap-3 (stat grid)
    static let statPadding: CGFloat = 20        // p-5

    static let contentMaxWidth: CGFloat = 480   // max-w-[30rem]
}
