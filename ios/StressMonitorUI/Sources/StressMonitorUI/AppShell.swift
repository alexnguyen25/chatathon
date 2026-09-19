import SwiftUI
import StressCore

public struct AppShell: View {

    @State private var live: LiveSessionModel
    @State private var dayFlow: DayFlowModel
    @State private var tab: Tab = .live

    enum Tab: Hashable { case live, exampleDay }

    public init(
        day: DayModel = SyntheticDay.day(),
        service: SuggestionProviding = StubSuggestionService()
    ) {
        _live = State(initialValue: LiveSessionModel(day: day))
        _dayFlow = State(initialValue: DayFlowModel(day: day, service: service))
    }

    public var body: some View {
        TabView(selection: $tab) {
            LiveHeartRateView(model: live)
                .tabItem {
                    Label("Live", systemImage: "heart")
                }
                .tag(Tab.live)

            NavigationStack(path: $dayFlow.path) {
                DayView(model: dayFlow)
                    .navigationDestination(for: DayRoute.self) { route in
                        switch route {
                        case .suggestion: SuggestionDetailView(model: dayFlow)
                        case .addBreak:   AddBreakView(model: dayFlow)
                        case .added:      BreakAddedView(model: dayFlow)
                        }
                    }
            }
            .tabItem {
                Label("Example day", systemImage: "calendar")
            }
            .tag(Tab.exampleDay)
        }
        .tint(DS.Palette.greenInk)
        .preferredColorScheme(Self.uiTestColorScheme)
    }

    /// Test-only hook.
    ///
    /// `-UIUserInterfaceStyle Dark` as a launch *argument* does nothing — it
    /// is an Info.plist key, not a runtime flag — so the first dark-mode
    /// screenshot silently captured light mode. A launch environment variable
    /// the app reads is the honest way to make the UI test able to ask for
    /// dark. Returns nil in normal use, leaving the system in charge.
    static var uiTestColorScheme: ColorScheme? {
        switch ProcessInfo.processInfo.environment["UI_TEST_COLOR_SCHEME"] {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil
        }
    }
}

/// Header shared by the two root screens: wordmark, then title block.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var showsWordmark: Bool = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            if showsWordmark { Wordmark() }
            HStack(alignment: .firstTextBaseline) {
                Text(title).displayTitleStyle()
                Spacer(minLength: DS.Space.m)
                trailing()
            }
            if let subtitle {
                Text(subtitle).subtitleStyle()
            }
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, showsWordmark: Bool = true) {
        self.init(title: title, subtitle: subtitle, showsWordmark: showsWordmark) {
            EmptyView()
        }
    }
}

#Preview("App") {
    AppShell()
}

#Preview("App — dark") {
    AppShell().preferredColorScheme(.dark)
}
