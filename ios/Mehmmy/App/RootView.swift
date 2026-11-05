import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.onboarded {
                MainView()
            } else {
                OnboardingFlow()
            }
        }
        .tint(Palette.ink)
    }
}

struct MainView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Palette.cream.ignoresSafeArea(edges: .top)
                screen
                    .id(state.tab)
                    .transition(.opacity)
            }
            TabBar()
        }
        .background(Palette.cream)
        .overlay(alignment: .top) {
            if let toast = state.toast {
                ToastView(toast: toast)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { state.toast = nil }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.toast)
        .sensoryFeedback(.success, trigger: state.toast?.id)
    }

    @ViewBuilder private var screen: some View {
        switch state.tab {
        case .ride: RideView()
        case .board: BoardView()
        case .rewards: RewardsView()
        case .activity: ActivityView()
        case .me: MeView()
        }
    }
}

struct TabBar: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                let active = state.tab == tab
                Button {
                    state.tab = tab
                } label: {
                    VStack(spacing: 3) {
                        Text(tab.icon).font(.system(size: 21)).opacity(active ? 1 : 0.4)
                        Text(tab.label)
                            .font(Typo.body(10, active ? .heavy : .semibold))
                            .foregroundStyle(active ? Palette.ink : Palette.muted)
                        Circle().fill(active ? Palette.ink : .clear).frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.top, 9)
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
        .background(Palette.cream.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: Metrics.border) }
    }
}

// shared screen scaffold: scrolling column with standard gutters
struct Screen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 10)
                .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Palette.cream)
    }
}
