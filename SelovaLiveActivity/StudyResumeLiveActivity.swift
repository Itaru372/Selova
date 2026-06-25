import ActivityKit
import SwiftUI
import WidgetKit

struct StudyResumeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyResumeActivityAttributes.self) { context in
            liveActivityView(for: context)
            .widgetURL(resumeURL(for: context.attributes.videoID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandOrb
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("集中を再開")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.74))

                        Text(context.state.videoTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandActionBadge
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        labelChip("続きから", systemImage: "gobackward")
                        labelChip(context.state.message, systemImage: "bolt.fill")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }
            } compactLeading: {
                ZStack {
                    Capsule()
                        .fill(.white.opacity(0.10))
                        .frame(width: 28, height: 28)
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Self.accentPink)
                }
                .accessibilityHidden(true)
            } compactTrailing: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Self.accentBlue.opacity(0.95))
                        .frame(width: 6, height: 6)
                    Text("再開")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } minimal: {
                ZStack {
                    Circle()
                        .fill(Self.accentPink.opacity(0.92))
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 24, height: 24)
                .accessibilityLabel("Selovaの学習を再開")
            }
            .widgetURL(resumeURL(for: context.attributes.videoID))
            .keylineTint(Self.accentPink)
        }
    }

    private func liveActivityView(
        for context: ActivityViewContext<StudyResumeActivityAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                islandOrb

                VStack(alignment: .leading, spacing: 4) {
                    Text("Selovaで集中を戻そう")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))

                    Text(context.state.videoTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                islandActionBadge
            }

            HStack(spacing: 10) {
                labelChip("学習モード", systemImage: "brain.head.profile")
                labelChip(context.state.message, systemImage: "sparkles")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activityBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selova。\(context.state.videoTitle)。\(context.state.message)")
    }

    private var islandOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Self.accentPink.opacity(0.95),
                            Self.accentBlue.opacity(0.86)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 30
                    )
                )
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
            Image(systemName: "play.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
        .shadow(color: Self.accentPink.opacity(0.35), radius: 10, y: 4)
        .accessibilityHidden(true)
    }

    private var islandActionBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.forward")
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text("再開")
                .font(.caption.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Self.accentPink.opacity(0.92))
        )
    }

    private var activityBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Self.panelBackground,
                        Self.panelBackground.opacity(0.96),
                        Self.panelBackground.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Self.accentPink.opacity(0.18))
                    .frame(width: 120, height: 120)
                    .blur(radius: 18)
                    .offset(x: -18, y: -30)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Self.accentBlue.opacity(0.16))
                    .frame(width: 140, height: 140)
                    .blur(radius: 18)
                    .offset(x: 36, y: 44)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }

    private func labelChip(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.10))
            )
    }

    private static let accentPink = Color(red: 1.0, green: 0.16, blue: 0.46)
    private static let accentBlue = Color(red: 0.26, green: 0.74, blue: 1.0)
    private static let panelBackground = Color(
        UIColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 1)
    )

    private func resumeURL(for videoID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "selova"
        components.host = "resume"
        components.queryItems = [
            URLQueryItem(name: "source", value: "live_activity"),
            URLQueryItem(name: "video_id", value: videoID)
        ]
        return components.url
    }
}
