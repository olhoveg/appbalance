import SwiftUI

struct DiscountTimerView: View {
    let endDate: Date
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundColor(.red)
            
            Text(formatTimeRemaining())
                .font(.caption2)
                .foregroundColor(.red)
                .fontWeight(.medium)
        }
        .onAppear {
            updateTimeRemaining()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func updateTimeRemaining() {
        let now = Date()
        timeRemaining = max(0, endDate.timeIntervalSince(now))
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTimeRemaining() -> String {
        if timeRemaining <= 0 {
            return "Скидка истекла"
        }
        
        let days = Int(timeRemaining) / 86400
        let hours = Int(timeRemaining) % 86400 / 3600
        let minutes = Int(timeRemaining) % 3600 / 60
        let seconds = Int(timeRemaining) % 60
        
        if days > 0 {
            return "\(days)д \(hours)ч \(minutes)м"
        } else if hours > 0 {
            return "\(hours)ч \(minutes)м \(seconds)с"
        } else if minutes > 0 {
            return "\(minutes)м \(seconds)с"
        } else {
            return "\(seconds)с"
        }
    }
}

#Preview {
    DiscountTimerView(endDate: Date().addingTimeInterval(3600)) // 1 час
        .padding()
}
