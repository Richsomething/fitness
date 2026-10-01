import Foundation

/// A weighing: the day and the weight in kilograms.
struct WeightEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var kg: Double
}

enum WeightHistory {
    static let allowed: ClosedRange<Double> = 20...400

    /// One weighing a day: a second one on the same day replaces the first. Oldest first.
    static func adding(_ kg: Double, on date: Date, to entries: [WeightEntry], calendar: Calendar = .current) -> [WeightEntry] {
        let others = entries.filter { !calendar.isDate($0.date, inSameDayAs: date) }
        return (others + [WeightEntry(date: date, kg: kg)]).sorted { $0.date < $1.date }
    }

    /// How far the trend moves toward each new weighing. A day-to-day swing of a kilo is mostly water, so the trend
    /// follows about a third of it.
    static let trendWeight = 0.3

    /// The weighings smoothed: the first stands as it is, each next moves the trend part of the way to it.
    static func trend(_ entries: [WeightEntry]) -> [WeightEntry] {
        var current: Double?
        return entries.map { entry in
            let next = current.map { $0 + trendWeight * (entry.kg - $0) } ?? entry.kg
            current = next
            return WeightEntry(id: entry.id, date: entry.date, kg: next)
        }
    }

    /// Latest minus first; nil with fewer than two weighings. Not a verdict — it is shown without colour.
    static func change(_ entries: [WeightEntry]) -> Double? {
        guard entries.count >= 2, let first = entries.first, let last = entries.last else { return nil }
        return last.kg - first.kg
    }

    /// "+1,5 кг", "−2 кг", "0 кг".
    static func changeText(_ change: Double) -> String {
        let rounded = (change * 10).rounded() / 10
        let sign = rounded > 0 ? "+" : rounded < 0 ? "−" : ""
        return "\(sign)\(WeightFormat.kg(abs(rounded))) кг"
    }
}
