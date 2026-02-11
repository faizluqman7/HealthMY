import Foundation

enum MetricRisk: String, Codable {
    case low
    case normal
    case elevated
    case high
}

enum TrendDirection: String, Codable {
    case improving
    case stable
    case worsening
}

struct MetricAnalysis {
    var risk: MetricRisk
    var trend: TrendDirection?
    var recentAvg: Double?
    var message: String
}

struct CorrelationAlert: Codable {
    var metrics: [String]
    var description: String
    var severity: MetricRisk
}

struct HealthProjection {
    var metric: String
    var currentAvg: Double
    var oneWeek: Double
    var oneMonth: Double
    var threeMonths: Double
}

struct ProjectedScores {
    var oneWeek: Int
    var oneMonth: Int
    var threeMonths: Int
}

struct HealthAnalysisResult {
    var score: Int
    var status: String
    var metricAnalyses: [String: MetricAnalysis]
    var correlationAlerts: [CorrelationAlert]
    var dataInsufficiencyMessage: String?
    var timestamp: Date
    var logEntries: [String]
    var projections: [String: HealthProjection]
    var projectedScores: ProjectedScores?
}

class RuleBasedScoring {
    static let shared = RuleBasedScoring()

    struct ScoringResult {
        var score: Int
        var risks: [String: MetricRisk]
        var messages: [String: String]
        var logEntries: [String]
    }

    func scoreReadings(
        bp: [(systolic: Int, diastolic: Int)],
        pulse: [Int],
        glucose: [Double],
        sleep: [Double],
        weight: [Double],
        height: [Double]
    ) -> ScoringResult {
        var componentScores: [(String, Double, Double)] = [] // (name, score, weight)
        var risks: [String: MetricRisk] = [:]
        var messages: [String: String] = [:]
        var log: [String] = []

        log.append("[Scoring] Input: BP=\(bp.count), Pulse=\(pulse.count), Glucose=\(glucose.count), Sleep=\(sleep.count), Weight=\(weight.count), Height=\(height.count)")

        // BP scoring — weight 30%
        if !bp.isEmpty {
            let avgSys = Double(bp.map { $0.systolic }.reduce(0, +)) / Double(bp.count)
            let avgDia = Double(bp.map { $0.diastolic }.reduce(0, +)) / Double(bp.count)
            let (bpScore, bpRisk, bpMsg) = scoreBP(avgSys: avgSys, avgDia: avgDia)
            componentScores.append(("bp", bpScore, 30))
            risks["bp"] = bpRisk
            messages["bp"] = bpMsg
            log.append("[Scoring] BP: avg sys=\(Int(avgSys)) dia=\(Int(avgDia)), score=\(Int(bpScore)) (\(bpRisk.rawValue))")
        } else {
            log.append("[Scoring] BP: no data, skipped")
        }

        // Pulse scoring — weight 15%
        if !pulse.isEmpty {
            let avg = Double(pulse.reduce(0, +)) / Double(pulse.count)
            let (pScore, pRisk, pMsg) = scorePulse(avg: avg)
            componentScores.append(("pulse", pScore, 15))
            risks["pulse"] = pRisk
            messages["pulse"] = pMsg
            log.append("[Scoring] Pulse: avg=\(Int(avg)) bpm, score=\(Int(pScore)) (\(pRisk.rawValue))")
        } else {
            log.append("[Scoring] Pulse: no data, skipped")
        }

        // Glucose scoring — weight 20%
        if !glucose.isEmpty {
            let avg = glucose.reduce(0, +) / Double(glucose.count)
            let (gScore, gRisk, gMsg) = scoreGlucose(avg: avg)
            componentScores.append(("glucose", gScore, 20))
            risks["glucose"] = gRisk
            messages["glucose"] = gMsg
            log.append("[Scoring] Glucose: avg=\(String(format: "%.1f", avg)) mg/dL, score=\(Int(gScore)) (\(gRisk.rawValue))")
        } else {
            log.append("[Scoring] Glucose: no data, skipped")
        }

        // Sleep scoring — weight 20%
        if !sleep.isEmpty {
            let avg = sleep.reduce(0, +) / Double(sleep.count)
            let (sScore, sRisk, sMsg) = scoreSleep(avg: avg)
            componentScores.append(("sleep", sScore, 20))
            risks["sleep"] = sRisk
            messages["sleep"] = sMsg
            log.append("[Scoring] Sleep: avg=\(String(format: "%.1f", avg)) hrs, score=\(Int(sScore)) (\(sRisk.rawValue))")
        } else {
            log.append("[Scoring] Sleep: no data, skipped")
        }

        // BMI scoring — weight 15%
        if !weight.isEmpty && !height.isEmpty {
            let avgW = weight.reduce(0, +) / Double(weight.count)
            let avgH = height.reduce(0, +) / Double(height.count)
            guard avgH > 0 else {
                log.append("[Scoring] BMI: height=0, cannot compute, returning default 50")
                return ScoringResult(score: 50, risks: risks, messages: messages, logEntries: log)
            }
            let bmi = avgW / ((avgH / 100) * (avgH / 100))
            let (bScore, bRisk, bMsg) = scoreBMI(bmi: bmi)
            componentScores.append(("bmi", bScore, 15))
            risks["bmi"] = bRisk
            messages["bmi"] = bMsg
            log.append("[Scoring] BMI: \(String(format: "%.1f", bmi)) (w=\(String(format: "%.1f", avgW))kg, h=\(String(format: "%.1f", avgH))cm), score=\(Int(bScore)) (\(bRisk.rawValue))")
        } else {
            log.append("[Scoring] BMI: missing weight or height, skipped")
        }

        // Weighted average with dynamic weight redistribution
        guard !componentScores.isEmpty else {
            log.append("[Scoring] No metrics available, returning default score 50")
            return ScoringResult(score: 50, risks: risks, messages: messages, logEntries: log)
        }

        let totalWeight = componentScores.map { $0.2 }.reduce(0, +)
        let weightedSum = componentScores.map { $0.1 * $0.2 }.reduce(0, +)
        let finalScore = Int(weightedSum / totalWeight)

        let activeWeights = componentScores.map { "\($0.0)=\(Int($0.2))%" }.joined(separator: ", ")
        log.append("[Scoring] Active weights (redistributed): \(activeWeights), totalWeight=\(Int(totalWeight))")
        log.append("[Scoring] Final rule-based score: \(max(0, min(100, finalScore)))")

        return ScoringResult(
            score: max(0, min(100, finalScore)),
            risks: risks,
            messages: messages,
            logEntries: log
        )
    }

    // Relaxed wellness thresholds
    private func scoreBP(avgSys: Double, avgDia: Double) -> (Double, MetricRisk, String) {
        if avgSys >= 135 || avgDia >= 88 {
            return (40, .high, "Blood pressure is elevated. Consider stress management and reducing sodium.")
        } else if avgSys >= 125 || avgDia >= 82 {
            return (65, .elevated, "Blood pressure is slightly above optimal. Monitor regularly.")
        } else if avgSys < 90 || avgDia < 60 {
            return (60, .elevated, "Blood pressure is lower than usual. Stay hydrated.")
        }
        return (100, .normal, "Blood pressure is in a healthy range.")
    }

    private func scorePulse(avg: Double) -> (Double, MetricRisk, String) {
        if avg > 100 || avg < 50 {
            return (40, .high, "Resting pulse is outside normal range.")
        } else if avg > 90 || avg < 55 {
            return (70, .elevated, "Pulse is slightly outside optimal range.")
        }
        return (100, .normal, "Pulse is in a healthy range.")
    }

    private func scoreGlucose(avg: Double) -> (Double, MetricRisk, String) {
        if avg > 130 || avg < 65 {
            return (40, .high, "Glucose levels need attention.")
        } else if avg > 110 {
            return (70, .elevated, "Glucose is slightly elevated.")
        }
        return (100, .normal, "Glucose is in a healthy range.")
    }

    private func scoreSleep(avg: Double) -> (Double, MetricRisk, String) {
        if avg < 5.5 || avg > 10.5 {
            return (40, .high, "Sleep duration needs attention. Aim for 7-9 hours.")
        } else if avg < 6.5 || avg > 9.5 {
            return (70, .elevated, "Sleep is slightly outside optimal range.")
        }
        return (100, .normal, "Sleep duration is healthy.")
    }

    private func scoreBMI(bmi: Double) -> (Double, MetricRisk, String) {
        if bmi > 30 || bmi < 17 {
            return (40, .high, "BMI is outside the healthy range.")
        } else if bmi > 27 || bmi < 18.5 {
            return (70, .elevated, "BMI is slightly outside optimal.")
        }
        return (100, .normal, "BMI is in a healthy range.")
    }
}
