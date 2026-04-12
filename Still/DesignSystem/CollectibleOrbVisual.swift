import SwiftUI

// MARK: - Unlocked sphere fills (ported from docs/collectibles-lab.html)

/// Lit collectible body only — rim stroke and SF Symbol stay in `CollectibleOrbCluster`.
struct CollectibleUnlockedOrbFill: View {
    let achievementId: String
    let size: CGFloat

    var body: some View {
        ZStack {
            core
            if achievementId == "streak_14" {
                specularHighlight(size: size, strong: true)
                    .mask(
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle().frame(width: size * 0.5)
                        }
                    )
            } else if achievementId != "streak_3" {
                specularHighlight(size: size, strong: achievementId != "streak_100")
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var core: some View {
        switch achievementId {
        case "streak_3": NewMoonOrb(size: size)
        case "streak_7": CrescentOrb(size: size)
        case "streak_14": QuarterOrb(size: size)
        case "streak_30": GibbousOrb(size: size)
        case "streak_60": FullMoonOrb(size: size)
        case "streak_100": SupermoonOrb(size: size)
        case "streak_365": LunarYearOrb(size: size)
        case "focus_1h": StarlightOrb(size: size)
        case "focus_5h": ConstellationOrb(size: size)
        case "focus_10h": NebulaOrb(size: size)
        case "focus_24h": FulldayOrb(size: size)
        case "focus_50h": AuroraOrb(size: size)
        case "focus_100h": GalaxyOrb(size: size)
        case "focus_500h": UniverseOrb(size: size)
        default: DefaultLitOrb(size: size)
        }
    }

    private func specularHighlight(size: CGFloat, strong: Bool) -> some View {
        let dark = StillTheme.current == .dark
        return Circle()
            .fill(
                RadialGradient(
                    stops: dark
                        ? [
                            .init(color: Color.white.opacity(strong ? 0.22 : 0.16), location: 0),
                            .init(color: Color.white.opacity(0.04), location: 0.4),
                            .init(color: .clear, location: 0.55)
                        ]
                        : [
                            .init(color: Color.white.opacity(strong ? 0.65 : 0.5), location: 0),
                            .init(color: Color.white.opacity(0.08), location: 0.42),
                            .init(color: .clear, location: 0.58)
                        ],
                    center: .init(x: 0.26, y: 0.2),
                    startRadius: 0,
                    endRadius: size * 0.38
                )
            )
            .blendMode(.softLight)
            .allowsHitTesting(false)
    }
}

// MARK: - Moon ladder

private struct NewMoonOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.04, green: 0.043, blue: 0.06), location: 0),
                            .init(color: Color(red: 0.1, green: 0.11, blue: 0.16), location: 0.55),
                            .init(color: Color(red: 0.01, green: 0.012, blue: 0.012), location: 1)
                        ],
                        center: .init(x: 0.78, y: 0.82),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.35, green: 0.37, blue: 0.43).opacity(0.9), location: 0),
                            .init(color: .clear, location: 1)
                        ],
                        center: .init(x: 0.26, y: 0.2),
                        startRadius: 0,
                        endRadius: size * 0.42
                    )
                )
        }
    }
}

private struct CrescentOrb: View {
    let size: CGFloat
    private let moonLit = Color(red: 0.98, green: 0.96, blue: 0.92)
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.55), location: 0),
                            .init(color: .clear, location: 0.38)
                        ],
                        center: .init(x: 0.28, y: 0.24),
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: moonLit, location: 0),
                            .init(color: Color(red: 0.66, green: 0.63, blue: 0.59), location: 0.72),
                            .init(color: Color(red: 0.43, green: 0.41, blue: 0.38), location: 1)
                        ],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.16, green: 0.18, blue: 0.21), location: 0),
                            .init(color: Color(red: 0.07, green: 0.08, blue: 0.1), location: 1)
                        ],
                        center: .init(x: 0.7, y: 0.75),
                        startRadius: 0,
                        endRadius: size * 0.48
                    )
                )
                .frame(width: size, height: size)
                .offset(x: size * 0.34)
        }
        .clipShape(Circle())
    }
}

private struct QuarterOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 1, green: 0.98, blue: 0.96), location: 0),
                            .init(color: Color(red: 0.98, green: 0.95, blue: 0.9), location: 0.22),
                            .init(color: Color(red: 0.85, green: 0.81, blue: 0.76), location: 0.52),
                            .init(color: Color(red: 0.6, green: 0.57, blue: 0.52), location: 1)
                        ],
                        center: .init(x: 0.62, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(red: 0.16, green: 0.15, blue: 0.2), location: 0),
                                .init(color: Color(red: 0.09, green: 0.08, blue: 0.11), location: 0.7),
                                .init(color: Color(red: 0.05, green: 0.04, blue: 0.06), location: 1)
                            ],
                            center: .trailing,
                            startRadius: 0,
                            endRadius: size * 0.55
                        )
                    )
                    .frame(width: size * 0.5, height: size)
                Color.clear
                    .frame(width: size * 0.5, height: size)
            }
        }
        .clipShape(Circle())
    }
}

private struct GibbousOrb: View {
    let size: CGFloat
    private let moonLit = Color(red: 0.98, green: 0.96, blue: 0.92)
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.5), location: 0),
                            .init(color: .clear, location: 0.36)
                        ],
                        center: .init(x: 0.28, y: 0.24),
                        startRadius: 0,
                        endRadius: size * 0.33
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: moonLit, location: 0),
                            .init(color: Color(red: 0.79, green: 0.77, blue: 0.72), location: 0.68),
                            .init(color: Color(red: 0.54, green: 0.52, blue: 0.49), location: 1)
                        ],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.18, green: 0.2, blue: 0.24), location: 0),
                            .init(color: Color(red: 0.08, green: 0.09, blue: 0.11), location: 1)
                        ],
                        center: .init(x: 0.2, y: 0.7),
                        startRadius: 0,
                        endRadius: size * 0.48
                    )
                )
                .frame(width: size, height: size)
                .offset(x: -size * 0.32)
        }
        .clipShape(Circle())
    }
}

private struct FullMoonOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.56, green: 0.53, blue: 0.47), location: 0),
                            .init(color: Color(red: 0.82, green: 0.78, blue: 0.72), location: 0.38),
                            .init(color: Color(red: 0.92, green: 0.89, blue: 0.86), location: 0.72),
                            .init(color: Color(red: 0.95, green: 0.93, blue: 0.9), location: 1)
                        ],
                        center: .init(x: 0.72, y: 0.78),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.95), location: 0),
                            .init(color: Color(red: 0.96, green: 0.95, blue: 0.93).opacity(0.5), location: 0.22),
                            .init(color: .clear, location: 0.4)
                        ],
                        center: .init(x: 0.26, y: 0.22),
                        startRadius: 0,
                        endRadius: size * 0.38
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.61, green: 0.58, blue: 0.54).opacity(0.14), location: 0),
                            .init(color: .clear, location: 0.14)
                        ],
                        center: .init(x: 0.38, y: 0.42),
                        startRadius: 0,
                        endRadius: size * 0.2
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.58, green: 0.56, blue: 0.52).opacity(0.12), location: 0),
                            .init(color: .clear, location: 0.12)
                        ],
                        center: .init(x: 0.62, y: 0.58),
                        startRadius: 0,
                        endRadius: size * 0.16
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.63, green: 0.6, blue: 0.56).opacity(0.1), location: 0),
                            .init(color: .clear, location: 0.11)
                        ],
                        center: .init(x: 0.48, y: 0.36),
                        startRadius: 0,
                        endRadius: size * 0.14
                    )
                )
        }
        .shadow(color: Color(red: 0.82, green: 0.8, blue: 0.76).opacity(0.35), radius: size * 0.12, x: 0, y: 0)
    }
}

private struct SupermoonOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.48, green: 0.4, blue: 0.35), location: 0),
                            .init(color: Color(red: 0.79, green: 0.66, blue: 0.57), location: 0.28),
                            .init(color: Color(red: 0.95, green: 0.89, blue: 0.83), location: 0.62),
                            .init(color: Color(red: 1, green: 0.96, blue: 0.92), location: 1)
                        ],
                        center: .init(x: 0.78, y: 0.82),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.98), location: 0),
                            .init(color: Color(red: 1, green: 0.92, blue: 0.82).opacity(0.55), location: 0.16),
                            .init(color: .clear, location: 0.36)
                        ],
                        center: .init(x: 0.28, y: 0.2),
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
        }
        .shadow(color: Color(red: 1, green: 0.67, blue: 0.51).opacity(0.45), radius: size * 0.2, x: 0, y: 0)
        .shadow(color: Color(red: 1, green: 0.86, blue: 0.75).opacity(0.35), radius: size * 0.1, x: 0, y: 0)
    }
}

private struct LunarYearOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 1, green: 0.98, blue: 0.96), location: 0),
                            .init(color: Color(red: 0.91, green: 0.82, blue: 0.72), location: 0.24),
                            .init(color: Color(red: 0.56, green: 0.45, blue: 0.39), location: 0.58),
                            .init(color: Color(red: 0.16, green: 0.13, blue: 0.17), location: 0.85),
                            .init(color: Color(red: 0.055, green: 0.047, blue: 0.08), location: 1)
                        ],
                        center: .init(x: 0.48, y: 0.42),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            lunarStarDot(opacity: 0.95)
                .offset(x: size * 0.36, y: -size * 0.34)
            lunarStarDot(opacity: 0.82)
                .offset(x: -size * 0.32, y: size * 0.28)
            lunarStarDot(opacity: 0.82)
                .offset(x: size * 0.08, y: size * 0.3)
            Circle()
                .stroke(Color(red: 0.79, green: 0.64, blue: 0.3).opacity(0.75), lineWidth: max(1, size * 0.014))
                .scaleEffect(0.82)
            Circle()
                .stroke(
                    Color(red: 0.91, green: 0.83, blue: 0.66).opacity(0.45),
                    style: StrokeStyle(lineWidth: max(0.7, size * 0.009), dash: [size * 0.03, size * 0.05])
                )
                .scaleEffect(0.68)
        }
    }

    private func lunarStarDot(opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(opacity), location: 0),
                        .init(color: .clear, location: 0.02)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 2
                )
            )
            .frame(width: 3, height: 3)
    }
}

// MARK: - Focus set

private struct StarlightOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(red: 1, green: 0.97, blue: 0.9).opacity(0.45),
                            Color.clear,
                            Color(red: 1, green: 0.97, blue: 0.9).opacity(0.35),
                            Color.clear,
                            Color(red: 1, green: 0.97, blue: 0.9).opacity(0.4),
                            Color.clear
                        ],
                        center: .center
                    )
                )
                .opacity(0.75)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.95), location: 0),
                            .init(color: Color(red: 1, green: 0.93, blue: 0.75).opacity(0.45), location: 0.32),
                            .init(color: .clear, location: 0.58)
                        ],
                        center: .init(x: 0.48, y: 0.42),
                        startRadius: 0,
                        endRadius: size * 0.45
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.85), location: 0),
                            .init(color: .clear, location: 0.4)
                        ],
                        center: .init(x: 0.28, y: 0.22),
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.72, green: 0.53, blue: 0.04), location: 0),
                            .init(color: Color(red: 0.91, green: 0.75, blue: 0.38), location: 0.45),
                            .init(color: Color(red: 1, green: 0.97, blue: 0.88), location: 1)
                        ],
                        center: .init(x: 0.65, y: 0.72),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 3, height: 3)
                .offset(x: size * 0.18, y: -size * 0.06)
            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 3, height: 3)
                .offset(x: -size * 0.08, y: size * 0.18)
            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 3, height: 3)
                .offset(x: size * 0.02, y: -size * 0.14)
        }
    }
}

private struct ConstellationOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.12, green: 0.13, blue: 0.18), location: 0),
                            .init(color: Color(red: 0.04, green: 0.05, blue: 0.07), location: 1)
                        ],
                        center: .init(x: 0.5, y: 0.55),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.31, green: 0.35, blue: 0.47).opacity(0.35), location: 0),
                            .init(color: .clear, location: 0.42)
                        ],
                        center: .init(x: 0.25, y: 0.2),
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
            Canvas { ctx, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height
                var path = Path()
                path.move(to: CGPoint(x: w * 0.22, y: h * 0.72))
                path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.28))
                path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.62))
                ctx.stroke(
                    path,
                    with: .color(Color(red: 0.82, green: 0.84, blue: 0.9).opacity(0.85)),
                    lineWidth: max(1.2, w * 0.018)
                )
                let dots: [(CGFloat, CGFloat)] = [(0.78, 0.62), (0.52, 0.28), (0.22, 0.72)]
                for (nx, ny) in dots {
                    let r = w * 0.035
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: w * nx - r, y: h * ny - r, width: r * 2, height: r * 2)),
                        with: .color(Color(white: 0.93))
                    )
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

private struct NebulaOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.07, green: 0.05, blue: 0.09), location: 0),
                            .init(color: Color(red: 0.12, green: 0.08, blue: 0.19), location: 0.55),
                            .init(color: Color(red: 0.05, green: 0.03, blue: 0.09), location: 1)
                        ],
                        center: .init(x: 0.5, y: 0.6),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.39, green: 0.71, blue: 1).opacity(0.4), location: 0),
                            .init(color: .clear, location: 0.5)
                        ],
                        center: .init(x: 0.72, y: 0.58),
                        startRadius: 0,
                        endRadius: size * 0.42
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.71, green: 0.47, blue: 1).opacity(0.5), location: 0),
                            .init(color: .clear, location: 0.55)
                        ],
                        center: .init(x: 0.28, y: 0.38),
                        startRadius: 0,
                        endRadius: size * 0.45
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 1, green: 0.78, blue: 1).opacity(0.25), location: 0),
                            .init(color: .clear, location: 0.38)
                        ],
                        center: .init(x: 0.22, y: 0.18),
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
        }
    }
}

private struct FulldayOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.49, green: 0.62, blue: 0.77), location: 0),
                            .init(color: Color(red: 0.77, green: 0.65, blue: 0.45), location: 0.35),
                            .init(color: Color(red: 0.55, green: 0.41, blue: 0.08), location: 0.65),
                            .init(color: Color(red: 1, green: 0.85, blue: 0.53), location: 0.85)
                        ],
                        center: .init(x: 0.5, y: 0.92),
                        startRadius: 0,
                        endRadius: size * 0.65
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 1, green: 0.85, blue: 0.55), location: 0),
                            .init(color: Color(red: 0.96, green: 0.69, blue: 0.38), location: 0.28),
                            .init(color: .clear, location: 0.45)
                        ],
                        center: .init(x: 0.48, y: 0.32),
                        startRadius: 0,
                        endRadius: size * 0.38
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.5), location: 0),
                            .init(color: .clear, location: 0.36)
                        ],
                        center: .init(x: 0.28, y: 0.18),
                        startRadius: 0,
                        endRadius: size * 0.32
                    )
                )
        }
    }
}

private struct AuroraOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.08, green: 0.12, blue: 0.2).opacity(0.85), location: 0),
                            .init(color: Color(red: 0.24, green: 0.78, blue: 0.55).opacity(0.35), location: 0.35),
                            .init(color: Color(red: 0.51, green: 0.35, blue: 0.78).opacity(0.45), location: 0.7),
                            .init(color: Color(red: 0.08, green: 0.12, blue: 0.2).opacity(0.85), location: 1)
                        ],
                        startPoint: .init(x: 0.2, y: 0.9),
                        endPoint: .init(x: 0.85, y: 0.1)
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.71, green: 1, blue: 0.86).opacity(0.35), location: 0),
                            .init(color: .clear, location: 0.45)
                        ],
                        center: .init(x: 0.5, y: 0.2),
                        startRadius: 0,
                        endRadius: size * 0.42
                    )
                )
        }
    }
}

private struct GalaxyOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.06, green: 0.06, blue: 0.09), location: 0),
                            .init(color: Color(red: 0.04, green: 0.04, blue: 0.08), location: 1)
                        ],
                        center: .init(x: 0.55, y: 0.6),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: (0..<40).flatMap { i -> [Gradient.Stop] in
                            let t = Double(i) / 40.0
                            let lit = i % 5 == 0
                            return [
                                .init(color: lit ? Color.white.opacity(0.05) : .clear, location: t),
                                .init(color: lit ? Color.white.opacity(0.05) : .clear, location: min(1, t + 0.025))
                            ]
                        }),
                        center: .center
                    )
                )
                .opacity(0.9)
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 1, green: 0.91, blue: 0.63).opacity(0.35), location: 0),
                            .init(color: .clear, location: 0.4)
                        ],
                        center: .init(x: 0.28, y: 0.22),
                        startRadius: 0,
                        endRadius: size * 0.38
                    )
                )
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 1, green: 0.91, blue: 0.63), location: 0),
                            .init(color: .clear, location: 0.11)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.1
                    )
                )
        }
    }
}

private struct UniverseOrb: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.02, green: 0.02, blue: 0.03), location: 0),
                            .init(color: Color(red: 0.1, green: 0.13, blue: 0.27), location: 1)
                        ],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )
            ForEach(0..<4, id: \.self) { i in
                let pts: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.18, 0.28, 0.95), (0.72, 0.58, 0.9), (0.42, 0.78, 0.85), (0.88, 0.22, 0.75)
                ]
                let p = pts[i]
                Circle()
                    .fill(Color.white.opacity(Double(p.2)))
                    .frame(width: 3, height: 3)
                    .offset(x: size * (p.0 - 0.5) * 1.6, y: size * (p.1 - 0.5) * 1.6)
            }
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(red: 0.47, green: 0.71, blue: 1).opacity(0.2), location: 0),
                            .init(color: .clear, location: 0.38)
                        ],
                        center: .init(x: 0.22, y: 0.18),
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
        }
        .shadow(color: Color(red: 0.39, green: 0.78, blue: 1).opacity(0.25), radius: 6, x: 0, y: 0)
    }
}

private struct DefaultLitOrb: View {
    let size: CGFloat
    var body: some View {
        let dark = StillTheme.current == .dark
        return Circle()
            .fill(
                RadialGradient(
                    colors: dark
                        ? [Color(white: 0.4), Color(white: 0.22), Color(white: 0.12)]
                        : [Color(white: 0.99), Color(white: 0.88), Color(white: 0.7)],
                    center: .init(x: 0.28, y: 0.22),
                    startRadius: 1,
                    endRadius: size * 0.55
                )
            )
    }
}

// MARK: - Shelf / sheet cluster (shadow + sphere + glyph)

struct CollectibleOrbCluster: View {
    let achievement: StillAchievement
    let unlocked: Bool
    let size: CGFloat

    var body: some View {
        let a = achievement
        let u = unlocked
        let dark = StillTheme.current == .dark

        ZStack {
            // Contact shadow — sits below the sphere center
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(dark ? 0.35 : 0.18),
                            Color.black.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.38
                    )
                )
                .frame(width: size * 0.6, height: size * 0.14)
                .blur(radius: dark ? 3 : 2)
                .offset(y: size * 0.38)

            // Sphere
            if u {
                CollectibleUnlockedOrbFill(achievementId: a.id, size: size)
                    .overlay(collectibleRimStroke())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 3)
            } else {
                Circle()
                    .fill(lockedSphereGradient(size: size))
                    .overlay(collectibleRimStroke().opacity(0.5))
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 2)
            }

            if !u {
                Text("?")
                    .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        dark
                            ? Color(white: 0.48).opacity(0.5)
                            : Color(white: 0.42).opacity(0.55)
                    )
            }
        }
        .frame(width: size, height: size)
    }

    private func collectibleRimStroke() -> some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(StillTheme.current == .dark ? 0.18 : 0.45),
                        Color.white.opacity(0.06),
                        Color.black.opacity(StillTheme.current == .dark ? 0.35 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
    }

    /// Same gradient for all locked orbs (regular + Unknown).
    private func lockedSphereGradient(size: CGFloat) -> RadialGradient {
        let dark = StillTheme.current == .dark
        return RadialGradient(
            colors: dark
                ? [Color(white: 0.2), Color(white: 0.12)]
                : [Color(white: 0.78), Color(white: 0.62)],
            center: .init(x: 0.28, y: 0.22),
            startRadius: 1,
            endRadius: size * 0.55
        )
    }
}
