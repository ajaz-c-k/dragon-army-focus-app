import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Dragon.createdAt) private var dragons: [Dragon]
    @Query(sort: \DragonEgg.startedAt, order: .reverse) private var eggs: [DragonEgg]
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]
    @Query(sort: \KingdomItem.plantedAt) private var kingdomItems: [KingdomItem]
    @AppStorage("focusDurationMinutes") private var focusDurationMinutes = 25
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes = 60
    @AppStorage("activeFocusRunning") private var activeFocusRunning = false
    @AppStorage("activeFocusStartTime") private var activeFocusStartTime = 0.0
    @AppStorage("activeFocusSessionStartTime") private var activeFocusSessionStartTime = 0.0
    @AppStorage("activeFocusElapsedSeconds") private var activeFocusElapsedSeconds = 0.0
    @AppStorage("activeFocusTotalSeconds") private var activeFocusTotalSeconds = 0
    @AppStorage("activeFocusEggStartingSeconds") private var activeFocusEggStartingSeconds = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("dragonExplorerName") private var explorerName = "Dragon Keeper"
    @State private var selectedTab = 0
    @State private var selectedSpeciesID = "ruby"
    @State private var remainingSeconds = 25 * 60
    @State private var sessionTotalSeconds = 25 * 60
    @State private var timerRunning = false
    @State private var showingCompletion = false
    @State private var showingSettings = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var dragon: Dragon? { dragons.first }
    private var selectedDragon: Dragon? {
        dragons.first(where: { $0.speciesID == selectedSpeciesID }) ?? dragon
    }
    private var minutesFocused: Int { sessions.filter(\.completed).reduce(0) { $0 + $1.durationMinutes } }
    private var unlockedSpecies: Set<String> { Set(dragons.map(\.speciesID)) }
    private var activeEgg: DragonEgg? { eggs.first(where: { !$0.hatched }) }
    private var latestEgg: DragonEgg? { eggs.first }
    private var eggForDisplay: DragonEgg? { activeEgg ?? latestEgg }
    private var nextEggSpecies: DragonSpecies? {
        DragonSpecies.all.first(where: { !unlockedSpecies.contains($0.id) })
    }
    private var explorerDisplayName: String {
        let trimmed = explorerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Dragon Keeper" : trimmed
    }
    private var dragonColorOptions: [(name: String, hex: String)] {
        [("Ruby", "E85D4A"), ("Azure", "4C9ED9"), ("Moss", "5D9B67"), ("Sunstone", "E5A83B"), ("Moon", "7B6BB4"), ("Crystal", "57B9B1")]
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    dashboardView.tag(0).tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
                    focusView.tag(1).tabItem { Label("Focus", systemImage: "timer") }
                    collectionView.tag(2).tabItem { Label("Dragons", systemImage: "flame.fill") }
                    lakeView.tag(3).tabItem { Label("Lake", systemImage: "water.waves") }
                }
            } else {
                DragonOnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
        .tint(DragonTheme.coral)
        .onAppear {
            seedIfNeeded()
            restoreTimerState()
        }
        .onChange(of: focusDurationMinutes) { _, newValue in
            guard !timerRunning else { return }
            sessionTotalSeconds = newValue * 60
            remainingSeconds = sessionTotalSeconds
        }
        .onReceive(timer) { _ in tick() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { restoreTimerState() }
        }
        .alert("Focus complete", isPresented: $showingCompletion) {
            Button("Keep growing") { }
        } message: {
                        Text("Your dragon gained XP, the lake expanded, and a new discovery was added.")
        }
        .sheet(isPresented: $showingSettings) {
            TimerSettingsView(
                durationMinutes: $focusDurationMinutes,
                dailyGoalMinutes: $dailyGoalMinutes,
                isTimerRunning: timerRunning
            )
        }
        .preferredColorScheme(.light)
    }

    private var dashboardView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dashboardHeader
                    dashboardHero
                    dashboardMetrics
                    consistencyCard
                    analyticsCard
                    medalsCard
                }
                .padding(20)
            }
            .background(DragonTheme.cream.ignoresSafeArea())
            .navigationTitle("Today")
        }
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Welcome back, \(explorerDisplayName)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Your focus command center")
                .font(.headline)
            Text("Small, consistent sessions build a stronger dragon army.")
                .font(.subheadline)
                .foregroundStyle(DragonTheme.ink.opacity(0.62))
        }
    }

    private var dashboardHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(DragonTheme.coral.opacity(0.14), lineWidth: 12)
                Circle().trim(from: 0, to: CGFloat(min(Double(todayMinutes) / Double(max(dailyGoalMinutes, 1)), 1)))
                    .stroke(DragonTheme.coral, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(todayMinutes)m").font(.title3.bold()).monospacedDigit()
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 5) {
                Text("Today's focus goal").font(.headline)
                Text("\(max(0, dailyGoalMinutes - todayMinutes)) minutes left")
                    .font(.subheadline).foregroundStyle(DragonTheme.ink.opacity(0.62))
                Text("\(currentStreak)-day streak")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(DragonTheme.coralDark)
            }
            Spacer()
        }
        .dragonCard()
    }

    private var dashboardMetrics: some View {
        HStack(spacing: 10) {
            DashboardMetric(value: "\(minutesFocused)m", label: "all-time focus", icon: "clock.fill")
            DashboardMetric(value: "\(sessions.filter(\.completed).count)", label: "sessions", icon: "checkmark.circle.fill")
            DashboardMetric(value: "\(dragons.count)/\(DragonSpecies.all.count)", label: "dragons", icon: "flame.fill")
        }
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Consistency").font(.headline)
                Spacer()
                Text("last 7 days").font(.caption).foregroundStyle(DragonTheme.ink.opacity(0.55))
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(weeklyMinutes.enumerated()), id: \.offset) { index, minutes in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(minutes > 0 ? DragonTheme.coral : DragonTheme.ink.opacity(0.12))
                            .frame(maxWidth: .infinity, minHeight: 8, maxHeight: CGFloat(max(8, Double(minutes) / Double(max(weeklyMax, 1)) * 86)))
                        Text(weekdayLabels[index]).font(.caption2).foregroundStyle(DragonTheme.ink.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            Text("\(currentStreak) consecutive day\(currentStreak == 1 ? "" : "s") active")
                .font(.subheadline.weight(.semibold)).foregroundStyle(DragonTheme.coralDark)
        }
        .dragonCard()
    }

    private var medalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Medals").font(.headline)
                Spacer()
                Text("\(earnedMedals.count)/\(FocusMedal.all.count)").font(.subheadline.bold()).foregroundStyle(DragonTheme.coral)
            }
            ForEach(FocusMedal.all) { medal in
                MedalRow(medal: medal, earned: earnedMedals.contains(medal.id))
            }
        }
        .dragonCard()
    }

    private var analyticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance snapshot").font(.headline)
                Spacer()
                Text("this week").font(.caption).foregroundStyle(DragonTheme.ink.opacity(0.55))
            }
            HStack(spacing: 10) {
                DashboardMetric(value: "\(weeklyMinutes.reduce(0, +))m", label: "this week", icon: "calendar")
                DashboardMetric(value: "\(averageSessionMinutes)m", label: "average session", icon: "chart.line.uptrend.xyaxis")
                DashboardMetric(value: "\(goalDays)/7", label: "goal days", icon: "target")
            }
            Text(bestFocusDayMessage)
                .font(.caption)
                .foregroundStyle(DragonTheme.ink.opacity(0.58))
        }
        .dragonCard()
    }

    private var focusView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    timerCard
                    statsRow
                    tipCard
                }
                .padding(20)
            }
            .background(DragonTheme.cream.ignoresSafeArea())
            .navigationTitle("Dragon Army")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Focus timer settings")
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome, \(explorerDisplayName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DragonTheme.coralDark)
                Text("Peaceful focus,")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("powerful dragons.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DragonTheme.coral)
                Text("Expand your lake and dragon collection one focused minute at a time.")
                    .font(.subheadline)
                    .foregroundStyle(DragonTheme.ink.opacity(0.62))
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(DragonTheme.gold)
                .padding(12)
                .background(.white.opacity(0.75), in: Circle())
        }
    }

    private var timerCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(DragonTheme.coral.opacity(0.14), lineWidth: 18)
                Circle().trim(from: 0, to: CGFloat(timerProgress)).stroke(DragonTheme.coral, style: StrokeStyle(lineWidth: 18, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 3) {
                    Text(timeString).font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(timerRunning ? "Focus in progress" : "Ready when you are")
                        .font(.caption).foregroundStyle(DragonTheme.ink.opacity(0.55))
                }
            }
            .frame(height: 230)
            if focusDurationMinutes == 60 || activeEgg != nil {
                TimerEggPanel(
                    progress: activeEgg == nil ? (latestEgg?.progress ?? 0) : eggProgress,
                    species: activeEgg?.species ?? latestEgg?.species ?? nextEggSpecies,
                    isRunning: timerRunning && activeEgg != nil,
                    hasHatched: activeEgg == nil && latestEgg?.hatched == true
                )
            }
            Button(timerRunning ? "Pause focus" : "Start \(focusDurationMinutes)-minute focus") {
                toggleTimer()
            }
            .buttonStyle(PrimaryButtonStyle())
            if !timerRunning && remainingSeconds < sessionTotalSeconds {
                Button("End session early") { finishSession() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DragonTheme.coralDark)
            }
            Text("Timer length: \(focusDurationMinutes) minutes · Change it with ⚙︎")
                .font(.caption)
                .foregroundStyle(DragonTheme.ink.opacity(0.52))
        }
        .frame(maxWidth: .infinity)
        .dragonCard()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(minutesFocused)m", label: "focused")
            StatTile(value: "\(kingdomItems.count)", label: "lake discoveries")
            StatTile(value: "\(dragons.count)/\(DragonSpecies.all.count)", label: "dragons")
        }
    }

    private var tipCard: some View {
        HStack(spacing: 14) {
            Text("🌱").font(.largeTitle)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your next reward").font(.headline)
                Text(nextDragonMessage)
                    .font(.subheadline)
                    .foregroundStyle(DragonTheme.ink.opacity(0.62))
            }
        }
        .dragonCard()
    }

    private var nextDragonMessage: String {
        guard let next = DragonSpecies.all.first(where: { !unlockedSpecies.contains($0.id) }) else {
            return "You have unlocked every dragon in this MVP collection."
        }
        return "Focus \(max(0, next.unlockMinutes - minutesFocused)) more minutes to discover \(next.name)."
    }

    private var collectionView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dragon Army").font(.title.bold())
                            Text("\(dragons.count) unlocked · \(DragonSpecies.all.count - dragons.count) still to discover")
                                .font(.subheadline).foregroundStyle(DragonTheme.ink.opacity(0.62))
                        }
                        Spacer()
                        Text("\(dragons.count)/\(DragonSpecies.all.count)")
                            .font(.title2.bold()).foregroundStyle(DragonTheme.coral)
                    }
                    .dragonCard()

                    if let dragon = selectedDragon {
                        DragonSceneView(stage: dragon.stage, colorHex: dragon.colorHex, speciesID: dragon.speciesID)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dragon.name).font(.title2.bold())
                                    Text(dragon.stage.title).font(.subheadline.weight(.semibold)).foregroundStyle(DragonTheme.coral)
                                }
                                Spacer()
                                Text("\(dragon.experience) XP").font(.headline.monospacedDigit())
                            }
                            ProgressView(value: dragon.progress).tint(DragonTheme.coral)
                            Text(dragon.stage.next.map { "\(max(0, dragon.stage.requiredXP - dragon.experience)) XP until \($0.title)" } ?? "Your dragon has reached its final MVP form")
                                .font(.caption).foregroundStyle(DragonTheme.ink.opacity(0.58))
                            TextField("Dragon name", text: Binding(
                                get: { dragon.name },
                                set: { dragon.name = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            Text("Dragon colors").font(.subheadline.bold())
                            HStack(spacing: 12) {
                                ForEach(dragonColorOptions, id: \.hex) { option in
                                    Button {
                                        dragon.colorHex = option.hex
                                        try? modelContext.save()
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: option.hex))
                                            .frame(width: 30, height: 30)
                                            .overlay {
                                                Circle().stroke(dragon.colorHex == option.hex ? DragonTheme.ink : .clear, lineWidth: 3)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(option.name)
                                }
                            }
                        }
                        .dragonCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Dragon roster").font(.headline)
                            Spacer()
                            Text("Tap a dragon to inspect it")
                                .font(.caption)
                                .foregroundStyle(DragonTheme.ink.opacity(0.48))
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(DragonSpecies.all) { species in
                                let unlockedDragon = dragons.first(where: { $0.speciesID == species.id })
                                DragonCollectionCard(
                                    species: species,
                                    dragon: unlockedDragon,
                                    isSelected: selectedSpeciesID == species.id,
                                    minutesFocused: minutesFocused
                                ) {
                                    guard unlockedDragon != nil else { return }
                                    selectedSpeciesID = species.id
                                }
                            }
                        }
                    }
                    .dragonCard()
                }
                .padding(20)
            }
            .background(DragonTheme.cream.ignoresSafeArea())
            .navigationTitle("Dragon Collection")
        }
    }

    private var lakeView: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.17, green: 0.45, blue: 0.62), DragonTheme.sky, DragonTheme.mint.opacity(0.8)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Azuremere Lake").font(.title.bold()).foregroundStyle(.white)
                                Text("A peaceful home where your dragons gather.").foregroundStyle(.white.opacity(0.82))
                            }
                            Spacer()
                            Text("Level \(lakeLevel)").font(.headline).foregroundStyle(.white).padding(10).background(.white.opacity(0.18), in: Capsule())
                        }
                        lakeHero
                        EggHatchingCard(
                            progress: activeEgg == nil ? (latestEgg?.progress ?? 0) : eggProgress,
                            species: eggForDisplay?.species ?? nextEggSpecies,
                            isHatching: activeEgg != nil,
                            focusDurationMinutes: focusDurationMinutes
                        )
                        Text("Lake projects").font(.headline).foregroundStyle(.white)
                        VStack(spacing: 10) {
                            ForEach(LakeProject.all) { project in
                                LakeProjectRow(project: project, unlocked: lakeLevel >= project.requiredLevel)
                            }
                        }
                        Text("Dragon bays").font(.headline).foregroundStyle(.white)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(dragons) { dragon in
                                LakeDragonCard(dragon: dragon)
                            }
                        }
                        Text("Lake discoveries").font(.headline).foregroundStyle(.white)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(kingdomItems.filter { $0.kind == "lake" || $0.kind == "tree" }) { item in
                                KingdomTile(item: item)
                            }
                        }
                        if kingdomItems.filter({ $0.kind == "lake" }).isEmpty {
                            Text("Complete a focus session to create your first lake expansion.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.82))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Lake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var lakeHero: some View {
        LakeIslandView(dragons: dragons, lakeLevel: lakeLevel)
    }

    private var todayMinutes: Int {
        sessions.filter { session in
            session.completed && Calendar.current.isDateInToday(session.startedAt)
        }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let activeDays = Set(sessions.filter(\.completed).map { calendar.startOfDay(for: $0.startedAt) })
        var day = calendar.startOfDay(for: .now)
        var streak = 0
        while activeDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private var weeklyMinutes: [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return 0 }
            return sessions.filter { session in
                session.completed && calendar.isDate(session.startedAt, inSameDayAs: day)
            }.reduce(0) { $0 + $1.durationMinutes }
        }
    }

    private var weeklyMax: Int { max(weeklyMinutes.max() ?? 0, 1) }
    private var weekdayLabels: [String] { ["M", "T", "W", "T", "F", "S", "S"] }
    private var lakeLevel: Int { max(1, min(10, kingdomItems.filter { $0.kind == "lake" }.count + 1)) }

    private var averageSessionMinutes: Int {
        let completed = sessions.filter(\.completed)
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0) { $0 + $1.durationMinutes } / completed.count
    }

    private var goalDays: Int {
        weeklyMinutes.filter { $0 >= dailyGoalMinutes }.count
    }

    private var bestFocusDayMessage: String {
        guard let best = weeklyMinutes.max(), best > 0 else { return "Complete a session to start building your personal focus pattern." }
        return "Your strongest day this week reached \(best) focused minutes."
    }

    private var earnedMedals: Set<String> {
        let completedCount = sessions.filter(\.completed).count
        let weeklySessionCount = sessions.filter { session in
            session.completed && Calendar.current.dateComponents([.day], from: session.startedAt, to: .now).day ?? 999 < 7
        }.count
        var result = Set<String>()
        if completedCount >= 1 { result.insert("first_focus") }
        if minutesFocused >= 60 { result.insert("focused_hour") }
        if currentStreak >= 3 { result.insert("three_day_streak") }
        if minutesFocused >= 300 { result.insert("deep_work") }
        if dragons.count >= 2 { result.insert("dragon_friend") }
        if weeklySessionCount >= 5 { result.insert("weekly_rhythm") }
        return result
    }

    private var timerProgress: Double {
        guard sessionTotalSeconds > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / Double(sessionTotalSeconds)
    }

    private var eggProgress: Double {
        guard let egg = activeEgg else { return 0 }
        let focusedSeconds: Double
        if timerRunning && activeFocusRunning {
            focusedSeconds = Double(activeFocusEggStartingSeconds) + activeFocusElapsedSeconds + max(0, Date.now.timeIntervalSince1970 - activeFocusStartTime)
        } else {
            focusedSeconds = Double(egg.focusedSeconds)
        }
        return min(max(focusedSeconds / Double(max(egg.durationSeconds, 1)), 0), 1)
    }

    private var timeString: String { String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60) }

    private func toggleTimer() {
        if !timerRunning {
            if remainingSeconds == 0 || remainingSeconds == sessionTotalSeconds {
                sessionTotalSeconds = focusDurationMinutes * 60
                remainingSeconds = sessionTotalSeconds
                activeFocusElapsedSeconds = 0
                activeFocusSessionStartTime = Date.now.timeIntervalSince1970
            }
            if activeEgg == nil, let next = nextEggSpecies {
                modelContext.insert(DragonEgg(speciesID: next.id))
                try? modelContext.save()
            }
            activeFocusEggStartingSeconds = activeEgg?.focusedSeconds ?? 0
            timerRunning = true
            activeFocusRunning = true
            activeFocusTotalSeconds = sessionTotalSeconds
            activeFocusStartTime = Date.now.timeIntervalSince1970
            scheduleFocusNotification(after: remainingSeconds)
        } else {
            updateRemainingFromClock()
            syncEggProgress()
            timerRunning = false
            activeFocusRunning = false
            activeFocusElapsedSeconds = Double(sessionTotalSeconds - remainingSeconds)
            activeFocusStartTime = 0
            cancelFocusNotification()
        }
    }

    private func tick() {
        guard timerRunning, activeFocusRunning else { return }
        updateRemainingFromClock()
        if remainingSeconds == 0 { finishSession() }
    }

    private func updateRemainingFromClock() {
        guard activeFocusRunning, activeFocusStartTime > 0 else { return }
        let elapsed = activeFocusElapsedSeconds + max(0, Date.now.timeIntervalSince1970 - activeFocusStartTime)
        remainingSeconds = max(0, activeFocusTotalSeconds - Int(elapsed))
    }

    private func restoreTimerState() {
        guard activeFocusTotalSeconds > 0 else { return }
        sessionTotalSeconds = activeFocusTotalSeconds
        if activeFocusRunning {
            timerRunning = true
            updateRemainingFromClock()
            if remainingSeconds == 0 {
                finishSession()
            } else {
                scheduleFocusNotification(after: remainingSeconds)
            }
        } else {
            timerRunning = false
            remainingSeconds = max(0, sessionTotalSeconds - Int(activeFocusElapsedSeconds))
        }
    }

    private func finishSession() {
        updateRemainingFromClock()
        syncEggProgress()
        let elapsedSeconds = max(1, sessionTotalSeconds - remainingSeconds)
        let elapsed = max(1, elapsedSeconds / 60)
        let earned = elapsed * 2
        let startedAt = activeFocusSessionStartTime > 0 ? Date(timeIntervalSince1970: activeFocusSessionStartTime) : .now
        modelContext.insert(FocusSession(startedAt: startedAt, durationMinutes: elapsed, xpEarned: earned))
        dragon?.addXP(earned)
        modelContext.insert(KingdomItem(kind: "lake", title: elapsed >= 20 ? "Crystal lagoon" : "Lake ripple"))
        var speciesIDs = unlockedSpecies
        if let egg = activeEgg, eggProgress >= 1 {
            egg.focusedSeconds = egg.durationSeconds
            egg.hatched = true
            if !speciesIDs.contains(egg.speciesID) {
                modelContext.insert(Dragon(name: egg.species.name, speciesID: egg.species.id, colorHex: egg.species.colorHex))
                speciesIDs.insert(egg.speciesID)
            }
        }
        let totalAfterSession = minutesFocused + elapsed
        for species in DragonSpecies.all where species.unlockMinutes <= totalAfterSession && !speciesIDs.contains(species.id) {
            modelContext.insert(Dragon(name: species.name, speciesID: species.id, colorHex: species.colorHex))
            speciesIDs.insert(species.id)
        }
        try? modelContext.save()
        timerRunning = false
        activeFocusRunning = false
        activeFocusStartTime = 0
        activeFocusSessionStartTime = 0
        activeFocusElapsedSeconds = 0
        activeFocusTotalSeconds = 0
        cancelFocusNotification()
        sessionTotalSeconds = focusDurationMinutes * 60
        remainingSeconds = sessionTotalSeconds
        showingCompletion = true
    }

    private func syncEggProgress() {
        guard let egg = activeEgg else { return }
        let elapsedSeconds = max(0, sessionTotalSeconds - remainingSeconds)
        egg.focusedSeconds = min(egg.durationSeconds, activeFocusEggStartingSeconds + elapsedSeconds)
        try? modelContext.save()
    }

    private func scheduleFocusNotification(after seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["focus-complete"])
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Focus complete"
            content.body = "Your dragon and Azuremere Lake are ready for their reward."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(seconds)), repeats: false)
            let request = UNNotificationRequest(identifier: "focus-complete", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private func cancelFocusNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-complete"])
    }

    private func seedIfNeeded() {
        if dragons.isEmpty {
            let ruby = DragonSpecies.all[0]
            modelContext.insert(Dragon(name: ruby.name, speciesID: ruby.id, colorHex: ruby.colorHex))
        }
        if activeFocusTotalSeconds == 0 {
            sessionTotalSeconds = focusDurationMinutes * 60
            remainingSeconds = sessionTotalSeconds
        }
        try? modelContext.save()
    }
}

private struct TimerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var durationMinutes: Int
    @Binding var dailyGoalMinutes: Int
    let isTimerRunning: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Focus duration") {
                    ForEach([15, 25, 50], id: \.self) { value in
                        Button {
                            durationMinutes = value
                        } label: {
                            HStack {
                                Text("\(value) minutes")
                                Spacer()
                                if durationMinutes == value {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isTimerRunning)
                    }

                    NavigationLink {
                        CustomDurationView(durationMinutes: $durationMinutes, isTimerRunning: isTimerRunning)
                    } label: {
                        HStack {
                            Text(isPresetDuration ? "Custom duration" : "\(durationMinutes) minutes")
                            Spacer()
                            if !isPresetDuration {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .disabled(isTimerRunning)
                }
                Section("Daily goal") {
                    Picker("Minutes per day", selection: $dailyGoalMinutes) {
                        ForEach([30, 60, 90, 120], id: \.self) { value in
                            Text("\(value) minutes").tag(value)
                        }
                    }
                }
                if isTimerRunning {
                    Section {
                        Label("Pause or finish the current session before changing its duration.", systemImage: "info.circle.fill")
                            .foregroundStyle(DragonTheme.coralDark)
                    }
                }
                Section("Good to know") {
                    Text("You can pause a session. Ending early still saves your focused minutes and rewards your dragon.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Focus Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }

    private var isPresetDuration: Bool {
        [15, 25, 50].contains(durationMinutes)
    }
}

private struct CustomDurationView: View {
    @Binding var durationMinutes: Int
    let isTimerRunning: Bool

    var body: some View {
        Form {
            Section {
                Picker("Custom focus duration", selection: $durationMinutes) {
                    ForEach(1...180, id: \.self) { value in
                        Text("\(value) minutes").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 190)
                .disabled(isTimerRunning)
            } header: {
                Text("Custom focus length")
            } footer: {
                Text("Choose any duration from 1 to 180 minutes.")
            }
        }
        .navigationTitle("Custom Duration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TimerEggPanel: View {
    let progress: Double
    let species: DragonSpecies?
    let isRunning: Bool
    let hasHatched: Bool

    private var message: String {
        if hasHatched { return "Hatched! Start another focus session for the next dragon." }
        if isRunning { return "Your focus is cracking the shell. Keep going." }
        return "Every 60 focused minutes hatches a new dragon."
    }

    var body: some View {
        HStack(spacing: 12) {
            EggVisual(
                progress: progress,
                species: species,
                colorHex: species?.colorHex ?? "E5A83B",
                isHatching: isRunning
            )
                .frame(width: 70, height: 76)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(hasHatched ? "Dragon unlocked" : "Egg mission")
                        .font(.subheadline.weight(.bold))
                    if let species {
                        Text("· \(species.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DragonTheme.coralDark)
                    }
                }
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DragonTheme.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: progress)
                    .tint(hasHatched ? DragonTheme.mint : DragonTheme.coral)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(DragonTheme.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EggHatchingCard: View {
    let progress: Double
    let species: DragonSpecies?
    let isHatching: Bool
    let focusDurationMinutes: Int

    private var title: String {
        if progress >= 1 { return "Dragon hatched!" }
        if isHatching { return "Your egg is hatching" }
        return species == nil ? "Your collection is complete" : "A new dragon awaits"
    }

    private var detail: String {
        if progress >= 1 {
            return "Welcome, \(species?.name ?? "new dragon"). Your island has a new resident."
        }
        if isHatching {
            if progress < 0.25 { return "The shell is warming in the lake light." }
            if progress < 0.60 { return "Hairline cracks are appearing. Keep focusing." }
            if progress < 0.90 { return "Your dragon is stirring inside the shell." }
            return "One last push. The hatchling is almost here!"
        }
        return "Start a focus session and build toward 60 focused minutes to hatch this dragon."
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                EggVisual(
                    progress: progress,
                    species: species,
                    colorHex: species?.colorHex ?? "E5A83B",
                    isHatching: isHatching
                )
                    .frame(width: 90, height: 96)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(DragonTheme.ink)
                        .lineLimit(2)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(DragonTheme.ink.opacity(0.62))
                        .lineLimit(3)
                    if let species {
                        Text(progress >= 1 ? species.name : "Next: \(species.name)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DragonTheme.coralDark)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ProgressView(value: progress)
                .tint(progress >= 1 ? DragonTheme.mint : DragonTheme.coral)
            HStack {
                Text(progress >= 1 ? "Ready to explore" : isHatching ? "\(Int(progress * 100))% hatched" : "60 focused minutes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DragonTheme.ink.opacity(0.58))
                Spacer(minLength: 8)
                if !isHatching && species != nil {
                    Text("Focus tab →")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DragonTheme.coralDark)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct EggVisual: View {
    let progress: Double
    let species: DragonSpecies?
    let colorHex: String
    let isHatching: Bool
    @State private var wobble = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(progress > 0 ? 0.22 : 0.14))
                .blur(radius: 8)
            if progress >= 1 {
                DragonAvatarView(species: species ?? DragonSpecies.all[0], stage: .hatchling, size: 58, animated: true)
                    .transition(.scale.combined(with: .opacity))
            } else {
                ZStack {
                    Ellipse()
                        .fill(LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color(hex: colorHex).opacity(0.96),
                                Color(hex: colorHex).opacity(0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay {
                            Ellipse()
                                .stroke(Color(hex: colorHex).opacity(0.92), lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 4)
                    Circle()
                        .fill(.white.opacity(0.50))
                        .frame(width: 8, height: 8)
                        .offset(x: -10, y: -17)
                    Circle()
                        .fill(.white.opacity(0.24))
                        .frame(width: 5, height: 5)
                        .offset(x: 12, y: 13)
                    if isHatching {
                        CrackMark(variant: 0)
                    }
                    if isHatching && progress >= 0.33 {
                        CrackMark(variant: 1)
                    }
                    if isHatching && progress >= 0.66 {
                        CrackMark(variant: 2)
                    }
                }
                .frame(width: 52, height: 70)
                .rotationEffect(.degrees(isHatching ? (wobble ? 3 : -3) : 0))
                .offset(x: isHatching ? (wobble ? 1 : -1) : 0)
                .scaleEffect(isHatching && wobble ? 1.04 : 1)
                .animation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true), value: wobble)
            }
        }
        .onAppear { wobble = isHatching }
        .onChange(of: isHatching) { _, value in wobble = value }
    }
}

private struct CrackMark: View {
    let variant: Int

    var body: some View {
        Path { path in
            switch variant {
            case 0:
                path.move(to: CGPoint(x: 23, y: 16))
                path.addLine(to: CGPoint(x: 18, y: 27))
                path.addLine(to: CGPoint(x: 23, y: 35))
                path.addLine(to: CGPoint(x: 19, y: 48))
            case 1:
                path.move(to: CGPoint(x: 22, y: 35))
                path.addLine(to: CGPoint(x: 30, y: 41))
                path.addLine(to: CGPoint(x: 27, y: 55))
            default:
                path.move(to: CGPoint(x: 18, y: 27))
                path.addLine(to: CGPoint(x: 10, y: 30))
                path.addLine(to: CGPoint(x: 8, y: 40))
            }
        }
        .stroke(.white.opacity(0.94), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        .frame(width: 44, height: 60)
        .shadow(color: .black.opacity(0.12), radius: 1)
    }
}

private struct LakeIslandView: View {
    let dragons: [Dragon]
    let lakeLevel: Int

    private let dragonOffsets: [(CGFloat, CGFloat)] = [
        (-88, 18), (-42, -12), (0, 12), (44, -14), (88, 18), (0, -38)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 300, height: 180)
                .offset(y: 36)
            Ellipse()
                .fill(Color(red: 0.26, green: 0.66, blue: 0.47))
                .frame(width: 268, height: 92)
                .offset(y: 40)
            Ellipse()
                .fill(Color(red: 0.40, green: 0.76, blue: 0.39))
                .frame(width: 228, height: 66)
                .offset(y: 28)
            Text("🌳")
                .font(.system(size: 44))
                .offset(x: -76, y: 18)
            Text("🌿")
                .font(.system(size: 34))
                .offset(x: 72, y: 24)
            ForEach(Array(dragons.prefix(6).indices), id: \.self) { index in
                let dragon = dragons[index]
                let offset = dragonOffsets[index % dragonOffsets.count]
                LakeDragonSprite(dragon: dragon, size: index == 2 ? 54 : 46, delay: Double(index) * 0.08)
                    .offset(x: offset.0, y: offset.1)
            }
            VStack {
                HStack {
                    Label("Azuremere Island", systemImage: "water.waves")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Lv. \(lakeLevel)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                .foregroundStyle(.white)
                Spacer()
                Text(dragons.isEmpty ? "Your island is waiting for its first dragon" : "\(dragons.count) dragon\(dragons.count == 1 ? "" : "s") roaming the island")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.bottom, 12)
            }
            .padding(16)
        }
        .frame(height: 250)
        .clipped()
    }
}

private struct LakeDragonSprite: View {
    let dragon: Dragon
    let size: CGFloat
    let delay: Double
    @State private var floating = false

    var body: some View {
        VStack(spacing: 0) {
            DragonAvatarView(species: dragon.species, stage: dragon.stage, size: size, animated: true)
            Circle()
                .fill(.black.opacity(0.16))
                .frame(width: size * 0.62, height: 6)
                .blur(radius: 2)
        }
        .offset(y: floating ? -4 : 4)
        .animation(.easeInOut(duration: 1.8).delay(delay).repeatForever(autoreverses: true), value: floating)
        .onAppear { floating = true }
    }
}

private struct DragonSpeciesRow: View {
    let species: DragonSpecies
    let unlocked: Bool
    let minutesFocused: Int

    var body: some View {
        HStack(spacing: 12) {
            DragonAvatarView(species: species, stage: .hatchling, size: 48)
                .grayscale(unlocked ? 0 : 1)
                .opacity(unlocked ? 1 : 0.42)
            VStack(alignment: .leading, spacing: 3) {
                Text(unlocked ? species.name : "Locked dragon").font(.subheadline.bold())
                Text(unlocked ? species.description : "Unlock at \(species.unlockMinutes) focused minutes")
                    .font(.caption).foregroundStyle(DragonTheme.ink.opacity(0.56))
            }
            Spacer()
            if unlocked {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(DragonTheme.mint)
            } else {
                Text("\(max(0, species.unlockMinutes - minutesFocused))m")
                    .font(.caption.bold()).foregroundStyle(DragonTheme.coralDark)
            }
        }
    }
}

private struct DragonCollectionCard: View {
    let species: DragonSpecies
    let dragon: Dragon?
    let isSelected: Bool
    let minutesFocused: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                DragonAvatarView(
                    species: species,
                    stage: dragon?.stage ?? .hatchling,
                    size: 106,
                    animated: dragon != nil
                )
                .frame(maxWidth: .infinity)
                .grayscale(dragon == nil ? 1 : 0)
                .opacity(dragon == nil ? 0.42 : 1)

                HStack(alignment: .firstTextBaseline) {
                    Text(dragon?.name ?? "Locked dragon")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DragonTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: dragon == nil ? "lock.fill" : (isSelected ? "checkmark.circle.fill" : "arrow.up.right.circle"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(dragon == nil ? DragonTheme.ink.opacity(0.3) : DragonTheme.coral)
                }
                Text(dragon == nil ? "Unlock at \(species.unlockMinutes) focused minutes" : species.name)
                    .font(.caption)
                    .foregroundStyle(DragonTheme.ink.opacity(0.55))
                    .lineLimit(1)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? DragonTheme.coral.opacity(0.10) : Color.white.opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isSelected ? DragonTheme.coral.opacity(0.65) : .clear, lineWidth: 2)
                    }
            )
        }
        .buttonStyle(.plain)
        .disabled(dragon == nil)
        .accessibilityLabel(dragon == nil ? "Locked \(species.name) dragon" : "View \(dragon?.name ?? species.name)")
    }
}

private struct DragonAvatarView: View {
    let species: DragonSpecies
    let stage: DragonStage
    let size: CGFloat
    var animated = false
    @State private var breathing = false

    private var baseColor: Color { Color(hex: species.colorHex) }
    private var wingColor: Color {
        switch species.id {
        case "ruby": return Color(red: 0.53, green: 0.08, blue: 0.12)
        case "azure": return Color(red: 0.05, green: 0.30, blue: 0.58)
        case "moss": return Color(red: 0.12, green: 0.35, blue: 0.20)
        case "sunstone": return Color(red: 0.82, green: 0.34, blue: 0.05)
        case "moon": return Color(red: 0.22, green: 0.12, blue: 0.42)
        default: return Color(red: 0.05, green: 0.42, blue: 0.43)
        }
    }
    private var glowColor: Color {
        switch species.id {
        case "azure": return .cyan
        case "moss": return .green
        case "sunstone": return .yellow
        case "moon": return .purple
        case "crystal": return .mint
        default: return DragonTheme.coral
        }
    }

    var body: some View {
        ZStack {
            // RealityKit can take a moment to initialize in a small grid cell.
            // Keep the polished animated avatar visible while that happens.
            flatPreview
            DragonMiniSceneView(
                speciesID: species.id,
                stage: stage,
                colorHex: species.colorHex,
                size: size,
                animated: animated
            )
        }
        .frame(width: size, height: size)
    }

    private var flatPreview: some View {
        ZStack {
            Circle()
                .fill(glowColor.opacity(0.16))
                .frame(width: size * 0.92, height: size * 0.92)
                .blur(radius: size * 0.12)

            DragonTailShape()
                .fill(wingColor)
                .frame(width: size * 0.42, height: size * 0.22)
                .rotationEffect(.degrees(-22))
                .offset(x: size * 0.30, y: size * 0.14)

            DragonWingShape()
                .fill(wingColor.gradient)
                .frame(width: size * 0.42, height: size * 0.34)
                .offset(x: -size * 0.28, y: size * 0.04)
            DragonWingShape()
                .fill(wingColor.gradient)
                .frame(width: size * 0.42, height: size * 0.34)
                .scaleEffect(x: -1, y: 1)
                .offset(x: size * 0.28, y: size * 0.04)

            Ellipse()
                .fill(baseColor.gradient)
                .frame(width: size * 0.53, height: size * 0.48)
                .shadow(color: wingColor.opacity(0.30), radius: size * 0.08, y: size * 0.04)
                .offset(y: size * 0.12)

            Ellipse()
                .fill(.white.opacity(0.16))
                .frame(width: size * 0.20, height: size * 0.27)
                .offset(x: -size * 0.08, y: size * 0.19)

            Circle()
                .fill(baseColor.gradient)
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: -size * 0.12)

            Triangle()
                .fill(wingColor)
                .frame(width: size * 0.11, height: size * 0.16)
                .rotationEffect(.degrees(-12))
                .offset(x: -size * 0.12, y: -size * 0.37)
            Triangle()
                .fill(wingColor)
                .frame(width: size * 0.11, height: size * 0.16)
                .rotationEffect(.degrees(12))
                .offset(x: size * 0.12, y: -size * 0.37)

            Capsule()
                .fill(baseColor.opacity(0.86))
                .frame(width: size * 0.24, height: size * 0.12)
                .offset(y: size * 0.02)

            HStack(spacing: size * 0.11) {
                DragonEye(color: glowColor)
                DragonEye(color: glowColor)
            }
            .offset(y: -size * 0.16)

            speciesDetail
                .offset(y: -size * 0.39)
        }
        .frame(width: size, height: size)
        .scaleEffect(breathing ? 1.025 : 0.985)
        .animation(animated ? .easeInOut(duration: 2.1).repeatForever(autoreverses: true) : nil, value: breathing)
        .onAppear { if animated { breathing = true } }
    }

    @ViewBuilder private var speciesDetail: some View {
        switch species.id {
        case "sunstone":
            Circle().stroke(.yellow.opacity(0.85), lineWidth: size * 0.025).frame(width: size * 0.34, height: size * 0.34)
        case "moon":
            Image(systemName: "moon.fill").font(.system(size: size * 0.18, weight: .bold)).foregroundStyle(.white.opacity(0.8))
        case "crystal":
            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.72)).frame(width: size * 0.13, height: size * 0.13).rotationEffect(.degrees(45))
        case "moss":
            HStack(spacing: -size * 0.02) { Circle().fill(.green.opacity(0.85)); Circle().fill(.mint.opacity(0.85)); Circle().fill(.green.opacity(0.65)) }
                .frame(width: size * 0.22, height: size * 0.10)
        default:
            Capsule().fill(.white.opacity(0.46)).frame(width: size * 0.12, height: size * 0.04)
        }
    }
}

private struct DragonEye: View {
    let color: Color
    var body: some View {
        Circle().fill(.white).frame(width: 8, height: 8).overlay(Circle().fill(color).frame(width: 4, height: 4))
    }
}

private struct DragonWingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control1: CGPoint(x: rect.width * 0.36, y: rect.height * 0.12), control2: CGPoint(x: rect.width * 0.78, y: rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.width * 0.55, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.34, y: rect.height * 0.62))
        path.closeSubpath()
        return path
    }
}

private struct DragonTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control1: CGPoint(x: rect.width * 0.38, y: rect.height * 0.12), control2: CGPoint(x: rect.width * 0.76, y: rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.42))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control1: CGPoint(x: rect.width * 0.68, y: rect.height * 0.75), control2: CGPoint(x: rect.width * 0.28, y: rect.height * 0.86))
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) { Text(value).font(.title3.bold()); Text(label).font(.caption).foregroundStyle(DragonTheme.ink.opacity(0.55)) }
            .frame(maxWidth: .infinity).padding(.vertical, 13).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct DashboardMetric: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).foregroundStyle(DragonTheme.coral)
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(DragonTheme.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct MedalRow: View {
    let medal: FocusMedal
    let earned: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(medal.icon).font(.title2).grayscale(earned ? 0 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(medal.title).font(.subheadline.bold()).foregroundStyle(earned ? DragonTheme.ink : DragonTheme.ink.opacity(0.45))
                Text(medal.detail).font(.caption).foregroundStyle(DragonTheme.ink.opacity(0.52))
            }
            Spacer()
            Image(systemName: earned ? "checkmark.seal.fill" : "lock.fill")
                .foregroundStyle(earned ? DragonTheme.gold : DragonTheme.ink.opacity(0.25))
        }
    }
}

private struct LakeDragonCard: View {
    let dragon: Dragon

    var body: some View {
        VStack(spacing: 7) {
            DragonAvatarView(species: dragon.species, stage: dragon.stage, size: 70, animated: true)
            Text(dragon.name).font(.subheadline.bold()).foregroundStyle(DragonTheme.ink)
            Text(dragon.stage.title).font(.caption2).foregroundStyle(DragonTheme.coralDark)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct KingdomTile: View {
    let item: KingdomItem
    var body: some View {
        VStack(spacing: 8) { Text(item.kind == "lake" ? "🌊" : item.kind == "tree" ? "🌳" : "🌱").font(.system(size: 46)); Text(item.title).font(.headline).foregroundStyle(DragonTheme.ink) }
            .frame(maxWidth: .infinity).padding(.vertical, 22).background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct LakeProject: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let requiredLevel: Int

    static let all: [LakeProject] = [
        LakeProject(id: "shore", title: "Quiet shore", detail: "A calm place to begin", icon: "🌊", requiredLevel: 1),
        LakeProject(id: "reed_garden", title: "Reed garden", detail: "A refuge for gentle dragons", icon: "🌾", requiredLevel: 2),
        LakeProject(id: "moon_bridge", title: "Moon bridge", detail: "Unlocks at lake level 4", icon: "🌙", requiredLevel: 4),
        LakeProject(id: "crystal_isle", title: "Crystal isle", detail: "A sanctuary for rare dragons", icon: "💎", requiredLevel: 7)
    ]
}

private struct LakeProjectRow: View {
    let project: LakeProject
    let unlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(unlocked ? project.icon : "🔒").font(.title2).frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.title).font(.subheadline.bold())
                Text(unlocked ? project.detail : "Focus to reach lake level \(project.requiredLevel)")
                    .font(.caption).foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Image(systemName: unlocked ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(unlocked ? DragonTheme.gold : .white.opacity(0.55))
        }
        .padding(12)
        .background(.white.opacity(unlocked ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15).background(DragonTheme.coral, in: Capsule()).scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
