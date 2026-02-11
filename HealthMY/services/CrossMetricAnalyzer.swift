import Foundation
import CreateML
import CoreML

class CrossMetricAnalyzer {
    static let shared = CrossMetricAnalyzer()

    private let minimumDays = 14
    private let minimumMetricTypes = 2
    private let retrainIntervalSeconds: TimeInterval = 86400

    private var modelFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("MLModels/cross_metric.mlmodel")
    }

    struct AnalysisInput {
        var bp: [(systolic: Int, diastolic: Int, date: Date)]
        var pulse: [(value: Int, date: Date)]
        var glucose: [(value: Double, date: Date)]
        var sleep: [(hours: Double, date: Date)]
        var weight: [(value: Double, date: Date)]
        var height: [(value: Double, date: Date)]
    }

    func analyzeCorrelations(input: AnalysisInput, projections: [String: HealthProjection]) -> (alerts: [CorrelationAlert], mlPredictedScore: Int?, projectedScores: ProjectedScores?, log: [String]) {
        var log: [String] = []
        log.append("[CrossMetric] Starting cross-metric correlation analysis...")

        // Check minimum metric types with enough data
        var metricTypesWithData = 0
        var qualifiedMetrics: [String] = []
        if hasEnoughData(input.bp.map { $0.date }) { metricTypesWithData += 1; qualifiedMetrics.append("BP(\(input.bp.count))") }
        if hasEnoughData(input.pulse.map { $0.date }) { metricTypesWithData += 1; qualifiedMetrics.append("Pulse(\(input.pulse.count))") }
        if hasEnoughData(input.glucose.map { $0.date }) { metricTypesWithData += 1; qualifiedMetrics.append("Glucose(\(input.glucose.count))") }
        if hasEnoughData(input.sleep.map { $0.date }) { metricTypesWithData += 1; qualifiedMetrics.append("Sleep(\(input.sleep.count))") }
        if hasEnoughData(input.weight.map { $0.date }) { metricTypesWithData += 1; qualifiedMetrics.append("Weight(\(input.weight.count))") }

        log.append("[CrossMetric] Qualified metrics (\(metricTypesWithData)/\(minimumMetricTypes) needed): \(qualifiedMetrics.joined(separator: ", "))")

        guard metricTypesWithData >= minimumMetricTypes else {
            log.append("[CrossMetric] Not enough metric types, skipping correlation analysis")
            return ([], nil, nil, log)
        }

        // Check cache for alerts
        var cachedAlerts: [CorrelationAlert]? = nil
        if !shouldRetrain() {
            cachedAlerts = loadCachedAlerts()
            if let cached = cachedAlerts {
                log.append("[CrossMetric] CACHE HIT: \(cached.count) cached alerts")
                for alert in cached {
                    log.append("[CrossMetric]   -> \(alert.metrics.joined(separator: " vs ")): \(alert.description) [\(alert.severity.rawValue)]")
                }
            }
        }

        // Build day-aligned feature rows
        let rows = buildFeatureRows(input: input)
        log.append("[CrossMetric] Built \(rows.count) day-aligned feature rows (need >=14)")
        guard rows.count >= 14 else {
            log.append("[CrossMetric] Not enough aligned rows, skipping")
            return (cachedAlerts ?? [], nil, nil, log)
        }

        // Compute correlation-based alerts (if no cache)
        let alerts: [CorrelationAlert]
        if let cached = cachedAlerts {
            alerts = cached
        } else {
            alerts = computeCorrelationAlerts(rows: rows, input: input, log: &log)
            cacheAlerts(alerts)
            setLastTrained()
            log.append("[CrossMetric] CACHE MISS, computed \(alerts.count) alerts (cached for 24h)")
        }

        // Train MLBoostedTreeRegressor for composite score prediction
        let (mlScore, projScores) = trainAndPredictCompositeScore(rows: rows, input: input, projections: projections, log: &log)

        return (alerts, mlScore, projScores, log)
    }

    private func trainAndPredictCompositeScore(rows: [FeatureRow], input: AnalysisInput, projections: [String: HealthProjection], log: inout [String]) -> (Int?, ProjectedScores?) {
        // Build training data with rule-based scores as target
        var featureSystolic: [Double] = []
        var featureDiastolic: [Double] = []
        var featurePulse: [Double] = []
        var featureGlucose: [Double] = []
        var featureSleep: [Double] = []
        var featureBmi: [Double] = []
        var targets: [Double] = []

        // Compute average height for BMI default
        let avgHeight: Double = input.height.isEmpty ? 170 : input.height.map { $0.value }.reduce(0, +) / Double(input.height.count)

        for row in rows {
            let sys = row.systolic ?? 120
            let dia = row.diastolic ?? 80
            let p = row.pulse ?? 72
            let g = row.glucose ?? 95
            let s = row.sleep ?? 7.5
            let b = row.bmi ?? 22.0

            featureSystolic.append(sys)
            featureDiastolic.append(dia)
            featurePulse.append(p)
            featureGlucose.append(g)
            featureSleep.append(s)
            featureBmi.append(b)

            // Compute simplified rule score for this row
            let rowScore = simplifiedRowScore(sys: sys, dia: dia, pulse: p, glucose: g, sleep: s, bmi: b)
            targets.append(Double(rowScore))
        }

        do {
            let table = try MLDataTable(dictionary: [
                "systolic": featureSystolic,
                "diastolic": featureDiastolic,
                "pulse": featurePulse,
                "glucose": featureGlucose,
                "sleep": featureSleep,
                "bmi": featureBmi,
                "ruleScore": targets
            ])

            let regressor = try MLBoostedTreeRegressor(trainingData: table, targetColumn: "ruleScore")

            // Save model
            let modelDir = modelFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
            try regressor.write(to: modelFileURL)

            // Compile and load
            let compiledURL = try MLModel.compileModel(at: modelFileURL)
            let model = try MLModel(contentsOf: compiledURL)

            // Predict current composite score using latest averages
            let latestSys = featureSystolic.suffix(7).reduce(0, +) / Double(min(7, featureSystolic.count))
            let latestDia = featureDiastolic.suffix(7).reduce(0, +) / Double(min(7, featureDiastolic.count))
            let latestPulse = featurePulse.suffix(7).reduce(0, +) / Double(min(7, featurePulse.count))
            let latestGlucose = featureGlucose.suffix(7).reduce(0, +) / Double(min(7, featureGlucose.count))
            let latestSleep = featureSleep.suffix(7).reduce(0, +) / Double(min(7, featureSleep.count))
            let latestBmi = featureBmi.suffix(7).reduce(0, +) / Double(min(7, featureBmi.count))

            let currentProvider = try MLDictionaryFeatureProvider(dictionary: [
                "systolic": MLFeatureValue(double: latestSys),
                "diastolic": MLFeatureValue(double: latestDia),
                "pulse": MLFeatureValue(double: latestPulse),
                "glucose": MLFeatureValue(double: latestGlucose),
                "sleep": MLFeatureValue(double: latestSleep),
                "bmi": MLFeatureValue(double: latestBmi)
            ])
            let currentPrediction = try model.prediction(from: currentProvider)
            let mlScore: Int? = {
                if let featureValue = currentPrediction.featureValue(for: "ruleScore") {
                    return max(0, min(100, Int(featureValue.doubleValue)))
                }
                return nil
            }()

            log.append("[CrossMetric] MLBoostedTreeRegressor trained, current predicted score: \(mlScore ?? -1)")

            // Predict future scores using projections
            var projectedScores: ProjectedScores? = nil
            if !projections.isEmpty {
                let futureSys = projections["bp"]
                let futurePulse = projections["pulse"]
                let futureGlucose = projections["glucose"]
                let futureSleep = projections["sleep"]
                let futureWeight = projections["weight"]

                func predictScore(getSysVal: (HealthProjection) -> Double, getPulseVal: (HealthProjection) -> Double, getGlucoseVal: (HealthProjection) -> Double, getSleepVal: (HealthProjection) -> Double, getWeightVal: (HealthProjection) -> Double) -> Int? {
                    let sys = futureSys.map(getSysVal) ?? latestSys
                    let dia = sys * (latestDia / max(latestSys, 1)) // maintain ratio
                    let pulse = futurePulse.map(getPulseVal) ?? latestPulse
                    let glucose = futureGlucose.map(getGlucoseVal) ?? latestGlucose
                    let sleep = futureSleep.map(getSleepVal) ?? latestSleep
                    let weightVal = futureWeight.map(getWeightVal) ?? latestBmi
                    let bmi = avgHeight > 0 ? weightVal / ((avgHeight / 100) * (avgHeight / 100)) : latestBmi
                    let adjustedBmi = futureWeight != nil ? bmi : latestBmi

                    let provider = try? MLDictionaryFeatureProvider(dictionary: [
                        "systolic": MLFeatureValue(double: sys),
                        "diastolic": MLFeatureValue(double: dia),
                        "pulse": MLFeatureValue(double: pulse),
                        "glucose": MLFeatureValue(double: glucose),
                        "sleep": MLFeatureValue(double: sleep),
                        "bmi": MLFeatureValue(double: adjustedBmi)
                    ])
                    guard let p = provider, let pred = try? model.prediction(from: p) else { return nil }
                    if let featureValue = pred.featureValue(for: "ruleScore") {
                        return max(0, min(100, Int(featureValue.doubleValue)))
                    }
                    return nil
                }

                let oneWeek = predictScore(
                    getSysVal: { $0.oneWeek }, getPulseVal: { $0.oneWeek },
                    getGlucoseVal: { $0.oneWeek }, getSleepVal: { $0.oneWeek }, getWeightVal: { $0.oneWeek }
                )
                let oneMonth = predictScore(
                    getSysVal: { $0.oneMonth }, getPulseVal: { $0.oneMonth },
                    getGlucoseVal: { $0.oneMonth }, getSleepVal: { $0.oneMonth }, getWeightVal: { $0.oneMonth }
                )
                let threeMonths = predictScore(
                    getSysVal: { $0.threeMonths }, getPulseVal: { $0.threeMonths },
                    getGlucoseVal: { $0.threeMonths }, getSleepVal: { $0.threeMonths }, getWeightVal: { $0.threeMonths }
                )

                if let w = oneWeek, let m = oneMonth, let t = threeMonths {
                    projectedScores = ProjectedScores(oneWeek: w, oneMonth: m, threeMonths: t)
                    log.append("[CrossMetric] Projected scores: 1w=\(w), 1m=\(m), 3m=\(t)")
                }
            }

            return (mlScore, projectedScores)
        } catch {
            log.append("[CrossMetric] MLBoostedTreeRegressor failed: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    private func simplifiedRowScore(sys: Double, dia: Double, pulse: Double, glucose: Double, sleep: Double, bmi: Double) -> Int {
        var score = 0.0
        var weights = 0.0

        // BP (30%)
        let bpScore: Double
        if sys >= 135 || dia >= 88 { bpScore = 40 }
        else if sys >= 125 || dia >= 82 { bpScore = 65 }
        else if sys < 90 || dia < 60 { bpScore = 60 }
        else { bpScore = 100 }
        score += bpScore * 30; weights += 30

        // Pulse (15%)
        let pulseScore: Double
        if pulse > 100 || pulse < 50 { pulseScore = 40 }
        else if pulse > 90 || pulse < 55 { pulseScore = 70 }
        else { pulseScore = 100 }
        score += pulseScore * 15; weights += 15

        // Glucose (20%)
        let glucoseScore: Double
        if glucose > 130 || glucose < 65 { glucoseScore = 40 }
        else if glucose > 110 { glucoseScore = 70 }
        else { glucoseScore = 100 }
        score += glucoseScore * 20; weights += 20

        // Sleep (20%)
        let sleepScore: Double
        if sleep < 5.5 || sleep > 10.5 { sleepScore = 40 }
        else if sleep < 6.5 || sleep > 9.5 { sleepScore = 70 }
        else { sleepScore = 100 }
        score += sleepScore * 20; weights += 20

        // BMI (15%)
        let bmiScore: Double
        if bmi > 30 || bmi < 17 { bmiScore = 40 }
        else if bmi > 27 || bmi < 18.5 { bmiScore = 70 }
        else { bmiScore = 100 }
        score += bmiScore * 15; weights += 15

        return max(0, min(100, Int(score / weights)))
    }

    private func hasEnoughData(_ dates: [Date]) -> Bool {
        guard dates.count >= 5 else { return false }
        let sorted = dates.sorted()
        guard let first = sorted.first, let last = sorted.last else { return false }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return days >= minimumDays
    }

    // Day-aligned feature row
    struct FeatureRow {
        var dayIndex: Int
        var systolic: Double?
        var diastolic: Double?
        var pulse: Double?
        var glucose: Double?
        var sleep: Double?
        var bmi: Double?
    }

    private func buildFeatureRows(input: AnalysisInput) -> [FeatureRow] {
        var allDates: [Date] = []
        allDates.append(contentsOf: input.bp.map { $0.date })
        allDates.append(contentsOf: input.pulse.map { $0.date })
        allDates.append(contentsOf: input.glucose.map { $0.date })
        allDates.append(contentsOf: input.sleep.map { $0.date })
        allDates.append(contentsOf: input.weight.map { $0.date })

        guard let earliest = allDates.min(), let latest = allDates.max() else { return [] }

        let totalDays = Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 0
        guard totalDays > 0 else { return [] }

        let cal = Calendar.current

        func dayIndex(for date: Date) -> Int {
            cal.dateComponents([.day], from: earliest, to: date).day ?? 0
        }

        var sysByDay: [Int: [Double]] = [:]
        var diaByDay: [Int: [Double]] = [:]
        var pulseByDay: [Int: [Double]] = [:]
        var glucoseByDay: [Int: [Double]] = [:]
        var sleepByDay: [Int: [Double]] = [:]
        var bmiByDay: [Int: [Double]] = [:]

        for r in input.bp {
            let d = dayIndex(for: r.date)
            sysByDay[d, default: []].append(Double(r.systolic))
            diaByDay[d, default: []].append(Double(r.diastolic))
        }
        for r in input.pulse {
            pulseByDay[dayIndex(for: r.date), default: []].append(Double(r.value))
        }
        for r in input.glucose {
            glucoseByDay[dayIndex(for: r.date), default: []].append(r.value)
        }
        for r in input.sleep {
            sleepByDay[dayIndex(for: r.date), default: []].append(r.hours)
        }

        let avgHeight: Double? = input.height.isEmpty ? nil : input.height.map { $0.value }.reduce(0, +) / Double(input.height.count)
        if let h = avgHeight, h > 0 {
            for r in input.weight {
                let bmi = r.value / ((h / 100) * (h / 100))
                bmiByDay[dayIndex(for: r.date), default: []].append(bmi)
            }
        }

        func avg(_ arr: [Double]?) -> Double? {
            guard let arr = arr, !arr.isEmpty else { return nil }
            return arr.reduce(0, +) / Double(arr.count)
        }

        var rows: [FeatureRow] = []
        for day in 0...totalDays {
            let row = FeatureRow(
                dayIndex: day,
                systolic: avg(sysByDay[day]),
                diastolic: avg(diaByDay[day]),
                pulse: avg(pulseByDay[day]),
                glucose: avg(glucoseByDay[day]),
                sleep: avg(sleepByDay[day]),
                bmi: avg(bmiByDay[day])
            )
            let nonNilCount = [row.systolic, row.diastolic, row.pulse, row.glucose, row.sleep, row.bmi].compactMap({ $0 }).count
            if nonNilCount >= 2 {
                rows.append(row)
            }
        }

        return rows
    }

    private func computeCorrelationAlerts(rows: [FeatureRow], input: AnalysisInput, log: inout [String]) -> [CorrelationAlert] {
        var alerts: [CorrelationAlert] = []

        let metricExtractors: [(String, (FeatureRow) -> Double?)] = [
            ("Blood Pressure", { $0.systolic }),
            ("Pulse", { $0.pulse }),
            ("Glucose", { $0.glucose }),
            ("Sleep", { $0.sleep }),
            ("BMI", { $0.bmi })
        ]

        var pairsChecked = 0
        for i in 0..<metricExtractors.count {
            for j in (i + 1)..<metricExtractors.count {
                let (nameA, extractA) = metricExtractors[i]
                let (nameB, extractB) = metricExtractors[j]

                var pairsA: [Double] = []
                var pairsB: [Double] = []
                for row in rows {
                    if let a = extractA(row), let b = extractB(row) {
                        pairsA.append(a)
                        pairsB.append(b)
                    }
                }

                guard pairsA.count >= 7 else {
                    log.append("[CrossMetric] \(nameA) vs \(nameB): \(pairsA.count) paired points (need >=7), skipped")
                    continue
                }

                pairsChecked += 1
                let corr = pearsonCorrelation(pairsA, pairsB)
                let absCorr = abs(corr)

                if absCorr >= 0.6 {
                    let direction = corr > 0 ? "positively" : "inversely"
                    let severity: MetricRisk = absCorr >= 0.8 ? .high : .elevated
                    alerts.append(CorrelationAlert(
                        metrics: [nameA, nameB],
                        description: "\(nameA) and \(nameB) appear \(direction) correlated in your readings.",
                        severity: severity
                    ))
                    log.append("[CrossMetric] \(nameA) vs \(nameB): r=\(String(format: "%.3f", corr)) (\(pairsA.count) pairs) -> ALERT (\(severity.rawValue), \(direction))")
                } else {
                    log.append("[CrossMetric] \(nameA) vs \(nameB): r=\(String(format: "%.3f", corr)) (\(pairsA.count) pairs) -> below threshold")
                }
            }
        }

        log.append("[CrossMetric] Checked \(pairsChecked) metric pairs, generated \(alerts.count) alerts")
        return alerts
    }

    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        guard n > 1 else { return 0 }

        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n

        var sumXY: Double = 0
        var sumX2: Double = 0
        var sumY2: Double = 0

        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            sumXY += dx * dy
            sumX2 += dx * dx
            sumY2 += dy * dy
        }

        let denominator = (sumX2 * sumY2).squareRoot()
        guard denominator > 0 else { return 0 }
        return sumXY / denominator
    }

    // Persistence

    private func shouldRetrain() -> Bool {
        let key = "ml_lastTrained_crossMetric"
        guard let lastTrained = UserDefaults.standard.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastTrained) > retrainIntervalSeconds
    }

    private func setLastTrained() {
        UserDefaults.standard.set(Date(), forKey: "ml_lastTrained_crossMetric")
    }

    private func cacheAlerts(_ alerts: [CorrelationAlert]) {
        let data = try? JSONEncoder().encode(alerts)
        UserDefaults.standard.set(data, forKey: "ml_crossMetricAlerts")
    }

    private func loadCachedAlerts() -> [CorrelationAlert]? {
        guard let data = UserDefaults.standard.data(forKey: "ml_crossMetricAlerts") else { return nil }
        return try? JSONDecoder().decode([CorrelationAlert].self, from: data)
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: "ml_lastTrained_crossMetric")
        UserDefaults.standard.removeObject(forKey: "ml_crossMetricAlerts")
    }
}
