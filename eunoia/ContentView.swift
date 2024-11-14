import SwiftUI
import AVFoundation
import CoreHaptics


struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}


struct MainTabView: View {
    @StateObject private var meditationStore = MeditationStore()
    
    var body: some View {
        TabView {
            PeaceExperienceView()
                .tabItem {
                    Label("Meditate", systemImage: "sparkles")
                }
            
            StatisticsView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
        }
        .environmentObject(meditationStore)
    }
}


struct PeaceExperienceView: View {
    @StateObject private var viewModel = PeaceExperienceViewModel()
    @State private var showingTimerSheet = false
    @State private var selectedDuration: TimeInterval = 600
    @State private var animationPhase = 0.0
    @State private var engine: CHHapticEngine?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    DailyStreakBanner(streak: viewModel.currentStreak)
                        .padding(.horizontal)
                    
                    ThemeCarousel(
                        themes: viewModel.themes,
                        currentTheme: $viewModel.currentTheme,
                        onThemeSelect: viewModel.selectTheme
                    )
                    .frame(height: 120)
                    
                    ZStack {
                        FlowingShape(phase: animationPhase)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        viewModel.currentTheme.primaryColor.opacity(0.3 + viewModel.intensity * 0.4),
                                        viewModel.currentTheme.secondaryColor.opacity(0.3 + viewModel.intensity * 0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                ParticleSystem(intensity: viewModel.intensity)
                                    .blur(radius: 20)
                            )
                            .onAppear {
                                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                                    animationPhase = .pi * 2
                                }
                            }
                        
                       
                        VStack {
                            if viewModel.isPlaying {
                                SessionTimer(duration: selectedDuration)
                                    .padding()
                            }
                            
                            
                            PlayButton(isPlaying: $viewModel.isPlaying) {
                                viewModel.togglePlayback()
                                triggerHapticFeedback()
                            }
                        }
                    }
                    .frame(height: geometry.size.height * 0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .shadow(radius: 10)
                    
                   
                    ControlPanel(
                        intensity: $viewModel.intensity,
                        onIntensityChange: viewModel.updateIntensity,
                        theme: viewModel.currentTheme,
                        showingTimerSheet: $showingTimerSheet
                    )
                    
                    
                    ThemeInfoCard(theme: viewModel.currentTheme)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .sheet(isPresented: $showingTimerSheet) {
            TimerSelectionSheet(selectedDuration: $selectedDuration)
        }
        .onAppear(perform: setupHaptics)
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptics error: \(error)")
        }
    }
    
    private func triggerHapticFeedback() {
        guard let engine = engine else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
}


struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let primaryColor: Color
    let secondaryColor: Color
    let soundFileName: String
    let benefits: [String]
    let icon: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.id == rhs.id
    }
}

struct ThemeCarousel: View {
    let themes: [Theme]
    @Binding var currentTheme: Theme
    let onThemeSelect: (Theme) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(themes) { theme in
                    ThemeCard(theme: theme, isSelected: theme == currentTheme)
                        .onTapGesture { onThemeSelect(theme) }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: theme.icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
            
            Text(theme.name)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 100)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [theme.primaryColor, theme.secondaryColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
        )
        .shadow(radius: isSelected ? 10 : 5)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}


struct DailyStreakBanner: View {
    let streak: Int
    
    var body: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text("\(streak) Day Streak")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct ControlPanel: View {
    @Binding var intensity: Double
    let onIntensityChange: (Double) -> Void
    let theme: Theme
    @Binding var showingTimerSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sound Intensity")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "speaker.wave.1.fill")
                    Slider(value: $intensity, in: 0...1) { changed in
                        if !changed {
                            onIntensityChange(intensity)
                        }
                    }
                    Image(systemName: "speaker.wave.3.fill")
                }
            }
            
            Button(action: { showingTimerSheet.toggle() }) {
                HStack {
                    Image(systemName: "timer")
                    Text("Set Timer")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.primaryColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(.horizontal)
    }
}

struct ThemeInfoCard: View {
    let theme: Theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benefits")
                .font(.headline)
            
            ForEach(theme.benefits, id: \.self) { benefit in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.primaryColor)
                    Text(benefit)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

// MARK: - Timer Components
struct SessionTimer: View {
    let duration: TimeInterval
    @State private var remainingTime: TimeInterval
    
    init(duration: TimeInterval) {
        self.duration = duration
        _remainingTime = State(initialValue: duration)
    }
    
    var body: some View {
        Text(timeString(from: remainingTime))
            .font(.system(size: 48, weight: .light, design: .rounded))
            .onAppear {
                startTimer()
            }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct TimerSelectionSheet: View {
    @Binding var selectedDuration: TimeInterval
    @Environment(\.dismiss) var dismiss
    
    let durations: [(String, TimeInterval)] = [
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("20 minutes", 1200),
        ("30 minutes", 1800)
    ]
    
    var body: some View {
        NavigationView {
            List(durations, id: \.1) { duration in
                Button(action: {
                    selectedDuration = duration.1
                    dismiss()
                }) {
                    HStack {
                        Text(duration.0)
                        Spacer()
                        if duration.1 == selectedDuration {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Duration")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}


struct ParticleSystem: View {
    let intensity: Double
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let particles = generateParticles(size: size)
                for particle in particles {
                    context.opacity = particle.opacity
                    context.fill(
                        Circle().path(in: CGRect(x: particle.x, y: particle.y, width: 4, height: 4)),
                        with: .color(.white)
                    )
                }
            }
        }
    }
    
    private func generateParticles(size: CGSize) -> [(x: Double, y: Double, opacity: Double)] {
        let count = Int(intensity * 100)
        return (0..<count).map { _ in
            (
                x: Double.random(in: 0...size.width),
                y: Double.random(in: 0...size.height),
                opacity: Double.random(in: 0.1...0.3)
            )
        }
    }
}

// MARK: - View Model
class PeaceExperienceViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var intensity: Double = 0.5
    @Published var currentTheme: Theme
    @Published var currentStreak: Int = 0
    
    private var audioPlayer: AVAudioPlayer?
    
    let themes = [
        Theme(
            id: "harmony",
            name: "Harmony",
            description: "Find inner peace and balance",
            primaryColor: .blue,
            secondaryColor: .purple,
            soundFileName: "harmony_ambient",
            benefits: ["Reduces stress", "Improves focus", "Enhances clarity"],
            icon: "sparkles"
        ),
        Theme(
            id: "empathy",
            name: "Empathy",
            description: "Connect with your emotions",
            primaryColor: .pink,
            secondaryColor: .red,
            soundFileName: "empathy_ambient",
            benefits: ["Emotional awareness", "Better relationships", "Self-compassion"],
            icon: "heart.fill"
        ),
        Theme(
            id: "resilience",
            name: "Resilience",
            description: "Build inner strength",
            primaryColor: .green,
            secondaryColor: .teal,
            soundFileName: "resilience_ambient",
            benefits: ["Mental strength", "Adaptability", "Emotional balance"],
            icon: "shield.fill"
        )
    ]
    
    init() {
        self.currentTheme = themes[0]
        setupAudio()
        loadStreak()
    }
    
    private func setupAudio() {
        guard let soundURL = Bundle.main.url(forResource: currentTheme.soundFileName, withExtension: "mp3") else {
            print("Sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize audio player: \(error)")
        }
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            audioPlayer?.play()
        } else {
            audioPlayer?.pause()
        }
    }
    
    func updateIntensity(_ newValue: Double) {
        intensity = newValue
        audioPlayer?.volume = Float(intensity)
    }
    
    func selectTheme(_ theme: Theme) {
        currentTheme = theme
        setupAudio()
        if isPlaying {
            audioPlayer?.play()
        }
    }
    
    private func loadStreak() {
        
        currentStreak = UserDefaults.standard.integer(forKey: "meditationStreak")
    }
    
    func updateStreak() {
        currentStreak += 1
        UserDefaults.standard.set(currentStreak, forKey: "meditationStreak")
    }
}


struct StatisticsView: View {
    @EnvironmentObject var meditationStore: MeditationStore
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    WeeklyProgressCard(sessions: meditationStore.weeklySessions)
                    
                    
                    TotalTimeCard(minutes: meditationStore.totalMinutes)
                    
                    
                    AchievementsGrid(achievements: meditationStore.achievements)
                   
                    MeditationCalendar(completedDates: meditationStore.completedDates)
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }
}

struct WeeklyProgressCard: View {
    let sessions: [Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Progress")
                .font(.headline)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack {
                        Capsule()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 30, height: CGFloat(sessions[index]))
                        
                        Text(dayAbbreviation(for: index))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
    
    private func dayAbbreviation(for index: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][index]
    }
}

struct TotalTimeCard: View {
    let minutes: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(minutes)")
                .font(.system(size: 48, weight: .bold))
            
            Text("Total Minutes")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
}

struct AchievementsGrid: View {
    let achievements: [Achievement]
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.headline)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(achievements) { achievement in
                    AchievementCard(achievement: achievement)
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.system(size: 24))
                .foregroundColor(achievement.isUnlocked ? .blue : .gray)
            
            Text(achievement.title)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Text(achievement.description)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
        .opacity(achievement.isUnlocked ? 1 : 0.6)
    }
}


struct JournalView: View {
    @State private var journalEntries: [JournalEntry] = []
    @State private var showingNewEntrySheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(journalEntries) { entry in
                    JournalEntryRow(entry: entry)
                }
            }
            .navigationTitle("Meditation Journal")
            .navigationBarItems(trailing:
                Button(action: { showingNewEntrySheet.toggle() }) {
                    Image(systemName: "square.and.pencil")
                }
            )
            .sheet(isPresented: $showingNewEntrySheet) {
                NewJournalEntryView { entry in
                    journalEntries.insert(entry, at: 0)
                }
            }
        }
    }
}

struct JournalEntry: Identifiable {
    let id = UUID()
    let date: Date
    let mood: String
    let notes: String
    let theme: String
    let duration: TimeInterval
}

struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.date, style: .date)
                    .font(.headline)
                Spacer()
                Text(entry.mood)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Text(entry.notes)
                .font(.body)
                .lineLimit(3)
            
            HStack {
                Label(entry.theme, systemImage: "leaf.fill")
                Spacer()
                Text("\(Int(entry.duration / 60)) min")
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

struct NewJournalEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var notes = ""
    @State private var mood = "😊"
    @State private var theme = "Harmony"
    let onSave: (JournalEntry) -> Void
    
    let moods = ["😊", "😌", "😔", "😤", "🤔"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("How do you feel?")) {
                    Picker("Mood", selection: $mood) {
                        ForEach(moods, id: \.self) { mood in
                            Text(mood)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Reflection")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section(header: Text("Session")) {
                    Picker("Theme", selection: $theme) {
                        Text("Harmony").tag("Harmony")
                        Text("Empathy").tag("Empathy")
                        Text("Resilience").tag("Resilience")
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    let entry = JournalEntry(
                        date: Date(),
                        mood: mood,
                        notes: notes,
                        theme: theme,
                        duration: 600
                    )
                    onSave(entry)
                    dismiss()
                }
            )
        }
    }
}


class MeditationStore: ObservableObject {
    @Published var weeklySessions: [Int] = [10, 15, 0, 20, 30, 15, 0]
    @Published var totalMinutes: Int = 90
    @Published var completedDates: Set<Date> = []
    
    let achievements: [Achievement] = [
        Achievement(
            id: "firstSession",
            title: "First Step",
            description: "Complete your first meditation",
            icon: "foot.fill",
            isUnlocked: true
        ),
        Achievement(
            id: "threeDay",
            title: "Consistent",
            description: "Meditate for 3 days in a row",
            icon: "flame.fill",
            isUnlocked: true
        ),
        Achievement(
            id: "tenHours",
            title: "Deep Diver",
            description: "Complete 10 hours of meditation",
            icon: "water.waves",
            isUnlocked: false
        ),
        Achievement(
            id: "allThemes",
            title: "Explorer",
            description: "Try all meditation themes",
            icon: "map.fill",
            isUnlocked: false
        )
    ]
}

struct FlowingShape: Shape {
    var phase: Double
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
      
        for x in stride(from: 0, through: width, by: 5) {
            let relativeX = x / width
            let sine = sin(relativeX * 7 * .pi * 0.3 + phase)
            let y = midHeight + sine/0.7 * 20 * (1)
            
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}


struct PlayButton: View {
    @Binding var isPlaying: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPlaying ? 1.06 : 1.0)
        .animation(.spring(response: 0.13, dampingFraction: 0.7), value: isPlaying)
    }
}


struct MeditationCalendar: View {
    let completedDates: Set<Date>
    @State private var selectedMonth = Date()
    
    private let calendar = Calendar.current
    private let daysInWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 20) {
     
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(monthYearString(from: selectedMonth))
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            
        
            HStack {
                ForEach(daysInWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            
      
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(date: date, isCompleted: completedDates.contains(date))
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
    
    private func previousMonth() {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        }
    }
    
    private func nextMonth() {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))
        else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let numberOfDays = range.count
       
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        
        let remainingCells = 42 - days.count
        if remainingCells > 0 {
            days.append(contentsOf: Array(repeating: nil, count: remainingCells))
        }
        
        return days
    }
}

struct DayCell: View {
    let date: Date
    let isCompleted: Bool
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            if isCompleted {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
            }
            
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 17))
                .foregroundColor(isCompleted ? .white : .primary)
        }
        .frame(height: 40)
    }
}

#Preview {
    ContentView()
}
