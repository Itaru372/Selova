import SwiftUI
import SwiftData
import Charts

struct FocusInsightsSheet: View {
    let namespace: Namespace.ID
    let onDismiss: () -> Void
    @Query(sort: \StudySession.startTime, order: .reverse) private var studySessions: [StudySession]

    @State private var isContentVisible = false
    @State private var dismissalOffset: CGFloat = 0
    @State private var isDismissing = false
    @GestureState private var dismissDragOffset: CGFloat = 0

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryCards
                    focusTrendChart
                    concentrationRateChart
                    insightCard
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(TikTokTheme.background)
        }
        .background(TikTokTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(TikTokTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: 12)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .ignoresSafeArea(.container, edges: .bottom)
        .offset(y: dismissDragOffset + dismissalOffset)
        .onAppear {
            SelovaAnalytics.track(.focusInsightsViewed)
            SelovaAnalytics.trackScreen("focus_insights")
            withAnimation(.smooth(duration: 0.46).delay(0.1)) {
                isContentVisible = true
            }
        }
        .onDisappear { isContentVisible = false }
    }

    private var dragIndicator: some View {
        ZStack {
            Text("集中の記録")
                .font(.headline.weight(.bold))
                .foregroundStyle(TikTokTheme.primaryText)

            HStack {
                Capsule()
                    .fill(TikTokTheme.border)
                    .frame(width: 42, height: 5)
                Spacer()
                Button("閉じる", action: onDismiss)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TikTokTheme.readableBlue)
                    .padding(.trailing, 2)
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .gesture(dismissGesture)
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dismissDragOffset) { value, state, _ in
                if value.translation.height > 0 { state = value.translation.height }
            }
            .onEnded { value in
                if value.translation.height > 110 || value.predictedEndTranslation.height > 180 {
                    dismissAfterDrag()
                }
            }
    }

    private func dismissAfterDrag() {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(.easeOut(duration: 0.2)) {
            dismissalOffset = 760
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onDismiss()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(levelState.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .matchedGeometryEffect(id: "growth-tree", in: namespace)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("Lv. \(levelState.level) の木")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(TikTokTheme.primaryText)
                Text("集中した時間が、木の成長になります")
                    .font(.subheadline)
                    .foregroundStyle(TikTokTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(TikTokTheme.panelStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TikTokTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .opacity(isContentVisible ? 1 : 0)
        .offset(y: isContentVisible ? 0 : 16)
        .animation(.smooth(duration: 0.38).delay(0.06), value: isContentVisible)
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            InsightMetricCard(title: "今日の最長集中", value: durationText(todayLongestFocusedTime), icon: "timer", accent: TikTokTheme.green)
            InsightMetricCard(title: "集中率", value: percentageText(weekFocusRate), icon: "scope", accent: TikTokTheme.readableBlue)
            InsightMetricCard(
                title: "連続",
                value: String(localized: "\(streakDays)日", comment: "Current study streak in days."),
                icon: "flame.fill",
                accent: TikTokTheme.pink
            )
        }
        .opacity(isContentVisible ? 1 : 0)
        .offset(y: isContentVisible ? 0 : 18)
        .animation(.smooth(duration: 0.4).delay(0.13), value: isContentVisible)
    }

    private var focusTrendChart: some View {
        insightSection(title: "直近7日間の最大集中時間", subtitle: "1日に最も長く集中できた時間") {
            Chart(dayMetrics) { metric in
                BarMark(
                    x: .value("日", metric.day, unit: .day),
                    y: .value("最大集中時間（分）", isContentVisible ? metric.longestFocusMinutes : 0)
                )
                .foregroundStyle(TikTokTheme.green.gradient)
                .cornerRadius(5)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(TikTokTheme.border)
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes)分")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 190)
            .accessibilityLabel("直近7日間の最大集中時間グラフ")
            .accessibilityValue("最長 \(durationText(longestFocusTime))")
            .animation(.smooth(duration: 0.55).delay(0.2), value: isContentVisible)
        }
    }

    private var concentrationRateChart: some View {
        insightSection(title: "集中率の推移", subtitle: "動画を開いていた時間のうち、集中できた割合") {
            Chart(dayMetrics) { metric in
                AreaMark(
                    x: .value("日", metric.day, unit: .day),
                    y: .value("集中率", isContentVisible ? metric.focusRate : 0)
                )
                .foregroundStyle(TikTokTheme.readableBlue.opacity(0.14))

                LineMark(
                    x: .value("日", metric.day, unit: .day),
                    y: .value("集中率", isContentVisible ? metric.focusRate : 0)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(TikTokTheme.readableBlue)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("日", metric.day, unit: .day),
                    y: .value("集中率", isContentVisible ? metric.focusRate : 0)
                )
                .foregroundStyle(TikTokTheme.readableBlue)
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 0.5, 1]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(TikTokTheme.border)
                    AxisValueLabel {
                        if let rate = value.as(Double.self) {
                            Text(percentageText(rate))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 190)
            .accessibilityLabel("直近7日間の集中率グラフ")
            .accessibilityValue("平均集中率 \(percentageText(weekFocusRate))")
            .animation(.smooth(duration: 0.62).delay(0.3), value: isContentVisible)
        }
    }

    private var insightCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(TikTokTheme.green)
                .frame(width: 36, height: 36)
                .background(TikTokTheme.green.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TikTokTheme.primaryText)
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundStyle(TikTokTheme.secondaryText)
            }
        }
        .padding(16)
        .background(TikTokTheme.panelStrong, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TikTokTheme.border, lineWidth: 1)
        }
        .opacity(isContentVisible ? 1 : 0)
        .offset(y: isContentVisible ? 0 : 18)
        .animation(.smooth(duration: 0.4).delay(0.38), value: isContentVisible)
    }

    private func insightSection<Content: View>(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(TikTokTheme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(TikTokTheme.secondaryText)
            }
            content()
        }
        .padding(18)
        .background(TikTokTheme.panelStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TikTokTheme.border, lineWidth: 1)
        }
    }

    private var dayMetrics: [FocusDayMetric] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let sessions = studySessions.filter { $0.startTime >= day && $0.startTime < nextDay }
            let focusedTime = sessions.reduce(0) { $0 + max(0, $1.focusedDuration) }
            let totalTime = sessions.reduce(0) { $0 + max(0, $1.duration) }
            let longestFocusedTime = sessions.map { max(0, $0.focusedDuration) }.max() ?? 0
            return FocusDayMetric(
                day: day,
                focusedTime: focusedTime,
                longestFocusedTime: longestFocusedTime,
                totalTime: totalTime
            )
        }
    }

    private var weekFocusedTime: TimeInterval {
        dayMetrics.reduce(0) { $0 + $1.focusedTime }
    }

    private var todayLongestFocusedTime: TimeInterval {
        dayMetrics.last?.longestFocusedTime ?? 0
    }

    private var longestFocusTime: TimeInterval {
        dayMetrics.map(\.longestFocusedTime).max() ?? 0
    }

    private var weekFocusRate: Double {
        let totalTime = dayMetrics.reduce(0) { $0 + $1.totalTime }
        return totalTime > 0 ? min(1, weekFocusedTime / totalTime) : 0
    }

    private var streakDays: Int {
        let activeDays = Set(studySessions.filter { $0.focusedDuration > 0 }.map { calendar.startOfDay(for: $0.startTime) })
        guard !activeDays.isEmpty else { return 0 }
        var day = calendar.startOfDay(for: Date())
        if !activeDays.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while activeDays.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    private var levelState: StudyGrowth.LevelState {
        StudyGrowth.levelState(totalFocusedTime: studySessions.reduce(0) { $0 + $1.focusedDuration }, streakDays: streakDays)
    }

    private var insight: (title: String, message: String, icon: String) {
        guard longestFocusTime > 0 else {
            return (
                String(localized: "最初の記録を作ろう"),
                String(localized: "動画を集中して見ると、ここにあなたのペースが育っていきます。"),
                "leaf.fill"
            )
        }
        if let bestDay = dayMetrics.max(by: { $0.longestFocusedTime < $1.longestFocusedTime }), bestDay.longestFocusedTime > 0 {
            return (
                String(localized: "いちばん長く集中できた日"),
                String(
                    localized: "\(bestDay.day.formatted(.dateTime.weekday(.wide)))は \(durationText(bestDay.longestFocusedTime)) 集中できました。",
                    comment: "Insight sentence. First value is weekday, second is focused duration."
                ),
                "sparkles"
            )
        }
        return (
            String(localized: "続けていこう"),
            String(localized: "短い集中でも、積み重ねるほど木は育ちます。"),
            "leaf.fill"
        )
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        if totalMinutes >= 60 {
            return String(
                localized: "\(totalMinutes / 60)時間\(totalMinutes % 60)分",
                comment: "Duration in hours and minutes."
            )
        }
        if duration > 0 && totalMinutes == 0 { return String(localized: "1分未満") }
        return String(localized: "\(totalMinutes)分", comment: "Duration in minutes.")
    }

    private func percentageText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct FocusDayMetric: Identifiable {
    let day: Date
    let focusedTime: TimeInterval
    let longestFocusedTime: TimeInterval
    let totalTime: TimeInterval

    var id: Date { day }
    var longestFocusMinutes: Int { max(0, Int((longestFocusedTime / 60).rounded())) }
    var focusRate: Double { totalTime > 0 ? min(1, focusedTime / totalTime) : 0 }
}

private struct InsightMetricCard: View {
    let title: LocalizedStringResource
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(TikTokTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(TikTokTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TikTokTheme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TikTokTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
