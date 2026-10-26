import SwiftUI

struct DragonOnboardingView: View {
    let onComplete: () -> Void

    @AppStorage("dragonExplorerName") private var explorerName = ""
    @State private var nameDraft = ""
    @State private var page = 0

    private let pageCount = 5

    private var enteredName: String {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Dragon Keeper" : trimmed
    }

    var body: some View {
        ZStack {
            DragonOnboardingBackground()

            VStack(spacing: 0) {
                onboardingHeader

                TabView(selection: $page) {
                    loginPage.tag(0)
                    focusPage.tag(1)
                    lakePage.tag(2)
                    collectionPage.tag(3)
                    readyPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .preferredColorScheme(.light)
        .onAppear { nameDraft = explorerName }
    }

    private var onboardingHeader: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button { withAnimation { page -= 1 } } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DragonTheme.coralDark)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.82), in: Circle())
                }
                .accessibilityLabel("Previous introduction page")
            } else {
                Color.clear.frame(width: 42, height: 42)
            }

            Text("DRAGON ARMY")
                .font(.caption.weight(.heavy))
                .tracking(2.2)
                .foregroundStyle(DragonTheme.coralDark)

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= page ? DragonTheme.coral : DragonTheme.ink.opacity(0.10))
                        .frame(width: index == page ? 30 : 18, height: 5)
                        .animation(.easeInOut(duration: 0.2), value: page)
                }
            }
        }
    }

    private var loginPage: some View {
        OnboardingPage {
            VStack(spacing: 22) {
                Spacer(minLength: 10)
                OnboardingDragonArt(stage: .hatchling, colorHex: "E85D4A")
                VStack(spacing: 10) {
                    Text("Welcome, \(enteredName)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Create your profile and start a calm focus journey where every completed session helps your dragon grow.")
                        .font(.body)
                        .foregroundStyle(DragonTheme.ink.opacity(0.62))
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("What should we call you?")
                        .font(.headline)
                        .foregroundStyle(DragonTheme.ink)
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(DragonTheme.coral)
                        TextField("Your name", text: $nameDraft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .foregroundStyle(DragonTheme.ink)
                    }
                    .padding(.horizontal, 15)
                    .frame(height: 54)
                    .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DragonTheme.coral.opacity(0.20), lineWidth: 1)
                    }
                    Text("No account or password required. Your journey is saved privately on this iPhone.")
                        .font(.caption)
                        .foregroundStyle(DragonTheme.ink.opacity(0.52))
                }
                .padding(18)
                .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Spacer()
            }
        }
    }

    private var focusPage: some View {
        OnboardingPage {
            VStack(spacing: 18) {
                Spacer(minLength: 10)
                OnboardingTitle(title: "Focus wakes your dragon", subtitle: "Set a timer, protect your attention, and turn quiet minutes into real progress.")
                FocusPreview()
                OnboardingChecklist(items: ["Choose a session that fits your day", "Pause when life needs you", "Earn rewards when you finish"])
                Spacer()
            }
        }
    }

    private var lakePage: some View {
        OnboardingPage {
            VStack(spacing: 18) {
                Spacer(minLength: 10)
                OnboardingTitle(title: "Grow a peaceful lake", subtitle: "Each completed session adds a new ripple, discovery, or place for your dragons to gather.")
                LakePreview()
                OnboardingPill(text: "Your focus becomes a world you can see")
                Spacer()
            }
        }
    }

    private var collectionPage: some View {
        OnboardingPage {
            VStack(spacing: 18) {
                Spacer(minLength: 10)
                OnboardingTitle(title: "Meet your dragon army", subtitle: "Unlock new species, evolve your companion, and collect medals for showing up consistently.")
                DragonCollectionPreview()
                OnboardingChecklist(items: ["Unlock dragons through focused minutes", "Evolve your first companion", "Build a streak you can be proud of"])
                Spacer()
            }
        }
    }

    private var readyPage: some View {
        OnboardingPage {
            VStack(spacing: 22) {
                Spacer(minLength: 10)
                OnboardingDragonArt(stage: .guardian, colorHex: "E85D4A")
                OnboardingTitle(title: "Your first flight starts now", subtitle: "No pressure to be perfect. Choose a small session and let consistency do the growing.")
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                    Text(enteredName)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DragonTheme.gold)
                }
                .foregroundStyle(DragonTheme.ink)
                .padding(16)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer()
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Button {
                if page == pageCount - 1 {
                    explorerName = enteredName
                    onComplete()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                HStack {
                    Text(page == 0 ? "Continue as \(enteredName)" : page == pageCount - 1 ? "Start focusing" : "Continue")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(DragonTheme.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            if page > 0 && page < pageCount - 1 {
                Button("Skip introduction") {
                    explorerName = enteredName
                    onComplete()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DragonTheme.coralDark)
            }
        }
    }
}

private struct DragonOnboardingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DragonTheme.cream, DragonTheme.sky.opacity(0.78), DragonTheme.mint.opacity(0.44)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(DragonTheme.coral.opacity(0.15))
                .frame(width: 260)
                .blur(radius: 65)
                .offset(x: 150, y: -300)
            Circle()
                .fill(DragonTheme.gold.opacity(0.18))
                .frame(width: 280)
                .blur(radius: 70)
                .offset(x: -160, y: 320)
        }
        .ignoresSafeArea()
    }
}

private struct OnboardingPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OnboardingTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(DragonTheme.ink.opacity(0.62))
                .multilineTextAlignment(.center)
        }
    }
}

private struct OnboardingDragonArt: View {
    let stage: DragonStage
    let colorHex: String

    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(.white.opacity(0.58))
                .frame(width: 250, height: 250)
            Circle()
                .stroke(DragonTheme.coral.opacity(0.38), lineWidth: 2)
                .frame(width: 215, height: 215)
            DragonSceneView(stage: stage, colorHex: colorHex)
                .frame(width: 245, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .frame(height: 235)
    }
}

private struct FocusPreview: View {
    var body: some View {
        ZStack {
            Circle().stroke(DragonTheme.coral.opacity(0.14), lineWidth: 18)
            Circle().trim(from: 0, to: 0.68)
                .stroke(DragonTheme.coral, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 3) {
                Text("25:00").font(.system(size: 42, weight: .bold, design: .rounded)).monospacedDigit()
                Text("Focus session").font(.caption).foregroundStyle(DragonTheme.ink.opacity(0.58))
            }
        }
        .frame(width: 190, height: 190)
        .padding(18)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct LakePreview: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.10, green: 0.55, blue: 0.65).opacity(0.74)).frame(width: 210, height: 150)
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? DragonTheme.coral : .white.opacity(0.82))
                    .frame(width: index.isMultiple(of: 2) ? 24 : 14, height: index.isMultiple(of: 2) ? 24 : 14)
                    .offset(x: CGFloat(index - 2) * 38, y: CGFloat((index % 3) - 1) * 22)
            }
            Text("🌊").font(.system(size: 68))
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct DragonCollectionPreview: View {
    private let dragons = [("🐉", "Ruby", "E85D4A"), ("💧", "Azure", "4C9ED9"), ("🌿", "Moss", "5D9B67")]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(dragons.enumerated()), id: \.offset) { entry in
                VStack(spacing: 8) {
                    Text(entry.element.0).font(.system(size: 42))
                    Text(entry.element.1).font(.caption.weight(.semibold))
                        .foregroundStyle(DragonTheme.ink.opacity(0.78))
                    Circle().fill(Color(hex: entry.element.2)).frame(width: 8, height: 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct OnboardingChecklist: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DragonTheme.coral)
                    Text(item)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DragonTheme.ink.opacity(0.82))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct OnboardingPill: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "sparkles")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DragonTheme.coralDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DragonTheme.coral.opacity(0.12), in: Capsule())
    }
}
