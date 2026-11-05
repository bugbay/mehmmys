import SwiftUI
import AuthenticationServices

struct OnboardingFlow: View {
    @Environment(AppState.self) private var state
    @State private var step = 0
    @State private var name = ""
    @State private var emoji = "🙋"
    @State private var colorIndex = 3
    @State private var crewName = ""
    @State private var code = ""
    @State private var error: String?
    @State private var working = false

    private let emojis = ["🙋", "🐢", "🦄", "🐯", "🐶", "🦋", "🐳", "🦊", "🐼", "🐸", "🦁", "🐙", "🐧", "🦖", "🐝", "🌵"]

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()
            switch step {
            case 0: signIn
            case 1: profile
            default: crewChoice
            }
        }
        .animation(.snappy, value: step)
        .onAppear { syncStep(); if name.isEmpty { name = state.suggestedName } }
        .onChange(of: state.phase) { syncStep() }
        .onChange(of: state.suggestedName) { if name.isEmpty { name = state.suggestedName } }
    }

    private func syncStep() {
        guard !state.isSample else { return }
        switch state.phase {
        case .signedOut: step = 0
        case .needsProfile: step = 1
        case .needsCrew: step = 2
        default: break
        }
        error = nil
    }

    private func run(_ work: @escaping () async throws -> Void) {
        error = nil
        working = true
        Task {
            do { try await work() } catch { self.error = error.localizedDescription }
            working = false
        }
    }

    @ViewBuilder private var errorLine: some View {
        if let error {
            Text(error).font(Typo.body(12, .bold)).foregroundStyle(Palette.burnt).multilineTextAlignment(.center)
        }
    }

    // MARK: sign in

    private var signIn: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Palette.ink).frame(width: 128, height: 128).offset(x: 6, y: 6)
                Circle().fill(Palette.yellow).frame(width: 128, height: 128)
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                Text("🚗").font(.system(size: 60))
            }
            .accessibilityHidden(true)
            Text("Mehmmy").font(Typo.display(48)).padding(.top, 26)
            Text("Get a ride. Give a Mehmmy.\nFriends bank them, you pay up in coffee.")
                .font(Typo.body(15, .medium))
                .foregroundStyle(Palette.subtle)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            HStack(spacing: 8) {
                pill("🔔 Ask the crew", Palette.peach)
                pill("⭐ Earn Mehmmys", Palette.yellow)
                pill("🎁 Cash in", Palette.rose)
            }
            .padding(.top, 22)
            Spacer()
            VStack(spacing: 14) {
                if state.isSample {
                    Button { step = 1 } label: {
                        Label("Sign in with Apple", systemImage: "apple.logo")
                    }
                    .buttonStyle(BrutalButtonStyle(fill: Palette.ink, foreground: Palette.cream))
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        Backend.shared?.prepareAppleRequest(request)
                    } onCompletion: { result in
                        run { try await Backend.shared?.completeApple(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.ink).offset(x: 4, y: 4))
                }
                Button {
                    if state.isSample { step = 1 } else { run { try await state.remote?.signInWithGoogle() } }
                } label: {
                    HStack(spacing: 8) {
                        Text("G").font(.system(size: 17, weight: .black)).foregroundStyle(Palette.coral)
                        Text("Continue with Google")
                    }
                }
                .buttonStyle(BrutalButtonStyle(fill: Palette.paper))
                errorLine
                Text("By continuing you agree to the Terms and Privacy Policy.")
                    .font(Typo.body(11)).foregroundStyle(Palette.muted).padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text).font(Typo.body(11, .bold)).padding(.horizontal, 9).padding(.vertical, 5)
            .background(Capsule().fill(color)).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
    }

    // MARK: profile

    private var profile: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stepper(1)
                ScreenTitle(title: "Who are you?", subtitle: "This is how your crew sees you.").padding(.top, 16)
                HStack {
                    Spacer()
                    Avatar(emoji: emoji, color: Palette.avatarColors[colorIndex], size: 96, selected: true, glow: Palette.ink)
                    Spacer()
                }
                .padding(.vertical, 22)
                FieldLabel(text: "YOUR NAME").padding(.bottom, 7)
                BrutalField(placeholder: "e.g. Mehmed", text: $name)
                FieldLabel(text: "PICK AN EMOJI").padding(.top, 18).padding(.bottom, 9)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                    ForEach(emojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Text(e).font(.system(size: 22)).frame(width: 38, height: 38)
                                .background(RoundedRectangle(cornerRadius: 10).fill(emoji == e ? Palette.yellow : Palette.paper))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.ink, lineWidth: emoji == e ? 2.5 : 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                FieldLabel(text: "AND A COLOR").padding(.top, 18).padding(.bottom, 9)
                HStack(spacing: 9) {
                    ForEach(0..<8, id: \.self) { i in
                        Button { colorIndex = i } label: {
                            Circle().fill(Palette.avatarColors[i]).frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: colorIndex == i ? 3 : 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(i + 1)")
                    }
                }
                let ok = !name.trimmingCharacters(in: .whitespaces).isEmpty
                Button(working ? "Saving…" : "Continue") {
                    let clean = String(name.trimmingCharacters(in: .whitespaces).prefix(30))
                    state.me.name = clean
                    state.me.emoji = emoji
                    if let remote = state.remote {
                        let hex = Palette.avatarColors[colorIndex].hexString
                        run { try await remote.saveProfile(name: clean, emoji: emoji, colorHex: hex) }
                    } else {
                        step = 2
                    }
                }
                .buttonStyle(BrutalButtonStyle(fill: Palette.green, enabled: ok && !working))
                .disabled(!ok || working)
                .padding(.top, 28)
                errorLine.padding(.top, 10)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: crew

    private var crewChoice: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepper(2)
                ScreenTitle(title: "Start or join a crew", subtitle: "Riders start a crew. Drivers join one with a code.")
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        IconTile(icon: "🙋", fill: Palette.sky)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I need rides").font(Typo.display(18))
                            Text("Start your crew and invite the friends who drive you.").font(Typo.body(12)).foregroundStyle(Palette.subtle)
                        }
                    }
                    BrutalField(placeholder: "\(name.isEmpty ? "My" : "\(name)'s") crew", text: $crewName)
                    Button(working ? "Creating…" : "Start my crew") {
                        if let remote = state.remote {
                            let crew = crewName.trimmingCharacters(in: .whitespaces)
                            let fallback = "\(state.me.name.isEmpty ? "My" : "\(state.me.name)'s") crew"
                            run { try await remote.createCrew(name: String((crew.isEmpty ? fallback : crew).prefix(40))) }
                        } else {
                            state.phase = .ready
                        }
                    }
                    .buttonStyle(BrutalButtonStyle(fill: Palette.coral, shadow: 3, enabled: !working))
                    .disabled(working)
                }
                .padding(16)
                .brutal(Palette.paper, radius: 18, shadow: 4)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        IconTile(icon: "🚗", fill: Palette.mint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I drive friends").font(Typo.display(18))
                            Text("Enter the 6-letter code your friend shared.").font(Typo.body(12)).foregroundStyle(Palette.subtle)
                        }
                    }
                    BrutalField(placeholder: "ABC234", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button(working ? "Joining…" : "Join crew") {
                        if let remote = state.remote {
                            run { try await remote.joinCrew(code: code) }
                        } else {
                            state.currentCrewID = AppState.sampleDriverCrewID
                            state.phase = .ready
                        }
                    }
                    .buttonStyle(BrutalButtonStyle(fill: Palette.green, shadow: 3, enabled: code.count >= 6 && !working))
                    .disabled(code.count < 6 || working)
                }
                .padding(16)
                .brutal(Palette.paper, radius: 18, shadow: 4)
                errorLine.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func stepper(_ n: Int) -> some View {
        HStack {
            Button {
                if state.isSample { step = n - 1 } else if n == 1 { state.remote?.signOut() }
            } label: { Image(systemName: "chevron.left").font(.system(size: 15, weight: .heavy)) }
                .accessibilityLabel("Back")
                .opacity(!state.isSample && n == 2 ? 0 : 1)
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...2, id: \.self) { i in
                    Capsule().fill(i <= n ? Palette.ink : Palette.faint).frame(width: i == n ? 22 : 8, height: 8)
                }
            }
            Spacer()
            Color.clear.frame(width: 15)
        }
        .foregroundStyle(Palette.ink)
    }
}
