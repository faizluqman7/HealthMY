import Foundation

class HealthAnalysisService {
    static let shared = HealthAnalysisService()

    func analyze(
        bp: [BloodPressureReading],
        weight: [WeightReading],
        height: [HeightReading],
        pulse: [PulseReading],
        sleep: [SleepReading],
        glucose: [GlucoseReading],
        completion: @escaping (HealthAnalysisResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.performAnalysis(
                bp: bp, weight: weight, height: height,
                pulse: pulse, sleep: sleep, glucose: glucose
            )
            // Print all log entries to Xcode console
            for entry in result.logEntries {
                print(entry)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func performAnalysis(
        bp: [BloodPressureReading],
        weight: [WeightReading],
        height: [HeightReading],
        pulse: [PulseReading],
        sleep: [SleepReading],
        glucose: [GlucoseReading]
    ) -> HealthAnalysisResult {
        var log: [String] = []
        log.append("[Analysis] ========== Starting Health Analysis ==========")
        log.append("[Analysis] Timestamp: \(Date())")

        // Prepare data arrays
        let bpTuples = bp.map { ($0.systolic, $0.diastolic) }
        let pulseValues = pulse.map { $0.pulse }
        let glucoseValues = glucose.map { $0.glucose }
        let sleepValues = sleep.map { $0.hours }
        let weightValues = weight.map { $0.weight }
        let heightValues = height.map { $0.height }

        log.append("[Analysis] Input counts: BP=\(bp.count), Weight=\(weight.count), Height=\(height.count), Pulse=\(pulse.count), Sleep=\(sleep.count), Glucose=\(glucose.count)")
        let totalReadings = bp.count + pulse.count + glucose.count + sleep.count + weight.count
        log.append("[Analysis] Total readings (excl. height): \(totalReadings)")

        // 1. Always run rule-based scoring
        log.append("[Analysis] --- Phase 1: Rule-Based Scoring ---")
        let ruleResult = RuleBasedScoring.shared.scoreReadings(
            bp: bpTuples,
            pulse: pulseValues,
            glucose: glucoseValues,
            sleep: sleepValues,
            weight: weightValues,
            height: heightValues
        )
        log.append(contentsOf: ruleResult.logEntries)

        // 2. Run trend analysis if enough data
        log.append("[Analysis] --- Phase 2: Trend Analysis ---")
        let trendOutput = TrendAnalyzer.shared.analyzeTrends(
            bp: bp.map { ($0.systolic, $0.diastolic, $0.date) },
            pulse: pulse.map { ($0.pulse, $0.date) },
            glucose: glucose.map { ($0.glucose, $0.date) },
            sleep: sleep.map { ($0.hours, $0.date) },
            weight: weight.map { ($0.weight, $0.date) }
        )
        let trends = trendOutput.results
        log.append(contentsOf: trendOutput.log)

        // Extract projections from trend results
        var projections: [String: HealthProjection] = [:]
        for (key, trendResult) in trends {
            if let proj = trendResult.projection {
                projections[key] = proj
            }
        }
        log.append("[Analysis] Extracted \(projections.count) metric projections from trends")

        // 3. Run cross-metric correlation analysis with projections
        log.append("[Analysis] --- Phase 3: Cross-Metric Correlation ---")
        let correlationInput = CrossMetricAnalyzer.AnalysisInput(
            bp: bp.map { ($0.systolic, $0.diastolic, $0.date) },
            pulse: pulse.map { ($0.pulse, $0.date) },
            glucose: glucose.map { ($0.glucose, $0.date) },
            sleep: sleep.map { ($0.hours, $0.date) },
            weight: weight.map { ($0.weight, $0.date) },
            height: height.map { ($0.height, $0.date) }
        )
        let correlationOutput = CrossMetricAnalyzer.shared.analyzeCorrelations(input: correlationInput, projections: projections)
        let correlationAlerts = correlationOutput.alerts
        let mlPredictedScore = correlationOutput.mlPredictedScore
        let projectedScores = correlationOutput.projectedScores
        log.append(contentsOf: correlationOutput.log)

        // 4. Build metric analyses
        log.append("[Analysis] --- Phase 4: Building Metric Analyses ---")
        var metricAnalyses: [String: MetricAnalysis] = [:]

        for (key, risk) in ruleResult.risks {
            let trend = trends[key]
            let message = ruleResult.messages[key] ?? ""
            let avg = recentAverage(key: key, bp: bpTuples, pulse: pulseValues, glucose: glucoseValues, sleep: sleepValues, weight: weightValues, height: heightValues)
            metricAnalyses[key] = MetricAnalysis(
                risk: risk,
                trend: trend?.direction,
                recentAvg: avg,
                message: message
            )
            let trendStr = trend != nil ? trend!.direction.rawValue : "n/a"
            let avgStr = avg != nil ? String(format: "%.1f", avg!) : "n/a"
            log.append("[Analysis] Metric '\(key)': risk=\(risk.rawValue), trend=\(trendStr), recentAvg=\(avgStr)")
        }

        // 5. Blend scores
        log.append("[Analysis] --- Phase 5: Score Blending ---")
        var finalScore: Int

        // ML + rule blending
        if let mlScore = mlPredictedScore {
            finalScore = Int(0.6 * Double(ruleResult.score) + 0.4 * Double(mlScore))
            log.append("[Analysis] Blended score: 0.6 * rule(\(ruleResult.score)) + 0.4 * ML(\(mlScore)) = \(finalScore)")
        } else {
            finalScore = ruleResult.score
            log.append("[Analysis] Base rule score: \(finalScore) (no ML score available)")
        }

        let worseningCount = trends.values.filter { $0.direction == .worsening }.count
        if worseningCount > 0 {
            let penalty = worseningCount * 3
            finalScore -= penalty
            log.append("[Analysis] Worsening trends: \(worseningCount), penalty: -\(penalty)")
        }
        let improvingCount = trends.values.filter { $0.direction == .improving }.count
        if improvingCount > 0 {
            let bonus = improvingCount * 2
            finalScore += bonus
            log.append("[Analysis] Improving trends: \(improvingCount), bonus: +\(bonus)")
        }
        finalScore = max(0, min(100, finalScore))
        log.append("[Analysis] Adjusted final score: \(finalScore)")

        // 6. Determine status
        let status: String
        if finalScore >= 80 {
            status = "Healthy"
        } else if finalScore >= 60 {
            status = "Needs Attention"
        } else {
            status = "At Risk"
        }
        log.append("[Analysis] Status: \(status)")

        // 7. Data insufficiency message
        var insufficiencyMessage: String? = nil
        if totalReadings == 0 {
            insufficiencyMessage = "Add health readings to see your wellness score."
            log.append("[Analysis] Data insufficiency: no readings at all")
        } else if trends.isEmpty {
            insufficiencyMessage = "Keep tracking for 14+ days to see health trends."
            log.append("[Analysis] Data insufficiency: not enough data for trend analysis (need 14+ days)")
        } else {
            log.append("[Analysis] Data sufficiency: OK (\(trends.count) trend metrics available)")
        }

        log.append("[Analysis] ========== Analysis Complete ==========")
        log.append("[Analysis] Final: score=\(finalScore), status=\(status), metrics=\(metricAnalyses.count), trends=\(trends.count), alerts=\(correlationAlerts.count), projections=\(projections.count)")

        return HealthAnalysisResult(
            score: finalScore,
            status: status,
            metricAnalyses: metricAnalyses,
            correlationAlerts: correlationAlerts,
            dataInsufficiencyMessage: insufficiencyMessage,
            timestamp: Date(),
            logEntries: log,
            projections: projections,
            projectedScores: projectedScores
        )
    }

    private func recentAverage(
        key: String,
        bp: [(systolic: Int, diastolic: Int)],
        pulse: [Int],
        glucose: [Double],
        sleep: [Double],
        weight: [Double],
        height: [Double]
    ) -> Double? {
        switch key {
        case "bp":
            guard !bp.isEmpty else { return nil }
            let recent = bp.suffix(7)
            return Double(recent.map { $0.systolic }.reduce(0, +)) / Double(recent.count)
        case "pulse":
            guard !pulse.isEmpty else { return nil }
            let recent = pulse.suffix(7)
            return Double(recent.reduce(0, +)) / Double(recent.count)
        case "glucose":
            guard !glucose.isEmpty else { return nil }
            let recent = glucose.suffix(7)
            return recent.reduce(0, +) / Double(recent.count)
        case "sleep":
            guard !sleep.isEmpty else { return nil }
            let recent = sleep.suffix(7)
            return recent.reduce(0, +) / Double(recent.count)
        case "bmi":
            guard !weight.isEmpty, !height.isEmpty else { return nil }
            let w = weight.suffix(7).reduce(0, +) / Double(min(7, weight.count))
            let h = height.last ?? 0
            guard h > 0 else { return nil }
            return w / ((h / 100) * (h / 100))
        default:
            return nil
        }
    }

    func clearAllModels() {
        TrendAnalyzer.shared.clearCache()
        CrossMetricAnalyzer.shared.clearCache()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = docs.appendingPathComponent("MLModels")
        try? FileManager.default.removeItem(at: modelsDir)
        print("[Analysis] All ML caches and models cleared")
    }
}
