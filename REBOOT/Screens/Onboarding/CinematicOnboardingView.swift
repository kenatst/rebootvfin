import SwiftUI
@preconcurrency import UIKit

/// Screen-by-screen port of `CinematicOnboarding.tsx`.
/// Artwork is full-bleed and edge-to-edge; type + controls sit in the safe area
/// over the bottom scrim, exactly like the web.
struct CinematicOnboardingView: View {
    @ObservedObject var state: AppState
    var onDebug: () -> Void

    @State private var currentImageID: Int?
    @State private var outgoingImageID: Int?
    @State private var outgoingOpacity: Double = 0
    @State private var incomingScale: CGFloat = 1.02

    private var screens: [CineScreen] { CinematicContent.screens }
    private var screen: CineScreen {
        screens[min(state.screen, screens.count - 1)]
    }
    private var isLast: Bool { state.screen == screens.count - 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppColors.void

                artwork
                scrim

                VStack(spacing: 0) {
                    EditorialHeader(
                        variant: .cinema(
                            meta: screen.meta,
                            showsSkip: !isLast,
                            onSkip: { state.patch(phase: .dissolve) }
                        ),
                        safeTop: geo.safeAreaInsets.top,
                        onDebug: onDebug
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)

                    Spacer(minLength: 0)

                    bottomContent
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.bottom, max(AppSpacing.safeBottomMin, geo.safeAreaInsets.bottom))
                }
            }
            .ignoresSafeArea()
        }
        .background(AppColors.void)
    }

    // MARK: - Artwork layer

    private var artwork: some View {
        GeometryReader { geo in
            ZStack {
                if let outgoing = outgoingImageID {
                    artworkImage(outgoing, size: geo.size)
                        .opacity(outgoingOpacity)
                }
                if let current = currentImageID {
                    artworkImage(current, size: geo.size)
                        .scaleEffect(incomingScale)
                }
                BreatheHalo(size: geo.size)
            }
            .onAppear {
                currentImageID = screen.id
            }
            .onChange(of: screen.id, initial: false) { _, newID in
                guard newID != currentImageID else { return }
                if let current = currentImageID {
                    outgoingImageID = current
                    outgoingOpacity = 1
                    withAnimation(.reboot(duration: AppMotion.artworkCrossfade)) {
                        outgoingOpacity = 0
                    }
                }
                currentImageID = newID
                incomingScale = 1.02
                withAnimation(.reboot(duration: AppMotion.artworkCrossfade)) {
                    incomingScale = 1
                }
            }
        }
    }

    private func artworkImage(_ id: Int, size: CGSize) -> some View {
        let screen = screens.first { $0.id == id } ?? screen
        return Image(uiImage: OnboardingArtwork.image(screen.imageName))
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .allowsHitTesting(false)
    }

    private var scrim: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: AppColors.void.opacity(0.25), location: 0),
                .init(color: AppColors.void.opacity(0), location: 0.26),
                .init(color: AppColors.void.opacity(0.55), location: 0.52),
                .init(color: AppColors.void.opacity(0.94), location: 0.74),
                .init(color: AppColors.void, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Bottom content

    private var bottomContent: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                CineTextBlock(screen: screen)
                    .id(screen.id)
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
            .animation(.easeOut(duration: 0.22), value: screen.id)
            .frame(maxWidth: AppSpacing.contentMaxWidth)

            Spacer().frame(height: AppSpacing.lg)

            PrimaryButton(title: screen.cta, tint: .light) {
                if isLast {
                    state.patch(phase: .dissolve)
                } else {
                    state.advanceCinematic()
                }
            }
            .frame(maxWidth: AppSpacing.contentMaxWidth)

            footer
                .frame(maxWidth: AppSpacing.contentMaxWidth)
                .padding(.top, AppSpacing.sm)
        }
    }

    private var footer: some View {
        HStack {
            Button(action: { state.backCinematic() }) {
                Text("Back", style: .smallLink)
                    .foregroundStyle(AppColors.cineMuted.opacity(0.6))
            }
            .disabled(state.screen == 0)
            .opacity(state.screen == 0 ? 0 : 1)

            Spacer()

            HStack(spacing: 6) {
                ForEach(screens.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == state.screen ? AppColors.signal : AppColors.cineFG.opacity(0.22))
                        .frame(width: i == state.screen ? 22 : 8, height: 3)
                        .animation(.reboot(duration: 0.5), value: state.screen)
                }
            }

            Spacer()

            if let ghost = screen.ghost {
                Button(action: { state.patch(phase: .dissolve) }) {
                    Text(ghost, style: .smallLink)
                        .foregroundStyle(AppColors.cineMuted.opacity(0.6))
                }
            } else {
                Spacer().frame(width: 32)
            }
        }
        .frame(height: 24)
    }
}

/// Loads the bundled onboarding artwork (plain PNGs under `Assets/Onboarding/`).
enum OnboardingArtwork {
    private static var cache: [String: UIImage] = [:]

    static func image(_ name: String) -> UIImage {
        if let cached = cache[name] { return cached }
        let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "Assets/Onboarding"
        ) ?? Bundle.main.url(forResource: name, withExtension: "png")!
        let image = UIImage(contentsOfFile: url.path) ?? UIImage()
        cache[name] = image
        return image
    }
}

/// The animated red breathing halo — radial `signal` at 22% over the artwork,
/// ellipse 60%×38% anchored at 50%/26%, screen blend, 6.5s breathing.
struct BreatheHalo: View {
    let size: CGSize
    @State private var breathing = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [AppColors.signal.opacity(0.22), AppColors.signal.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(size.width * 0.3, size.height * 0.19)
                )
            )
            .frame(width: size.width * 0.6, height: size.height * 0.38)
            .position(x: size.width * 0.5, y: size.height * 0.26)
            .opacity(breathing ? 0.62 : 0.32)
            .blendMode(.screen)
            .onAppear {
                withAnimation(.easeInOut(duration: AppMotion.breatheCycle).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
    }
}

/// Title / body / stages / secondary block with the web's reveal cascade
/// (delays 0.16 / 0.26 / 0.34 / 0.40, 12pt rise, 0.58s).
struct CineTextBlock: View {
    let screen: CineScreen

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Reveal(delay: AppMotion.textRevealDelay) {
                Text(screen.title, style: .cineTitle)
                    .foregroundStyle(AppColors.cineFG)
            }

            Reveal(delay: 0.26) {
                Text(screen.body, style: .cineBody)
                    .foregroundStyle(AppColors.cineFG.opacity(0.8))
                    .padding(.top, AppSpacing.sm)
            }

            if let stages = screen.stages {
                Reveal(delay: 0.34) {
                    stagesRow(stages)
                        .padding(.top, 20)
                }
            }

            if let secondary = screen.secondary {
                Reveal(delay: 0.40) {
                    Text(secondary, style: .cineSecondary)
                        .foregroundStyle(AppColors.cineMuted.opacity(0.75))
                        .padding(.top, AppSpacing.sm)
                }
            }
        }
    }

    private func stagesRow(_ stages: [String]) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                if index > 0 {
                    Text("→", style: .choiceLabel)
                        .foregroundStyle(AppColors.signal.opacity(0.7))
                }
                Pill.stage(stage)
            }
        }
    }
}

extension Text {
    /// Builds text with exact web metrics (font, tracking and pinned line height).
    init(_ string: String, style: AppTypography.Style) {
        let mutable = NSMutableAttributedString(string: string)
        mutable.addAttribute(.font, value: style.font, range: NSRange(location: 0, length: (string as NSString).length))
        mutable.addAttribute(.kern, value: style.kerning, range: NSRange(location: 0, length: (string as NSString).length))
        if let lineHeight = style.lineHeight {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            mutable.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: (string as NSString).length))
        }
        self.init(AttributedString(mutable))
    }
}
