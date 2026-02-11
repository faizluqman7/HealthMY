import Foundation
import CreateML
import CoreML

class TrendAnalyzer {
    static let shared = TrendAnalyzer()

    private let minimumDays = 14
    private let retrainIntervalSeconds: TimeInterval = 86400 // 24 hours

    private var modelDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("MLModels/trends")
    }

    struct TrendResult {
        var direction: TrendDirection
        var slopePerDay: Double
        var message: String
        var projection: HealthProjection?
    }

    func analyzeTrends(
        bp: [(systolic: Int, diastolic: Int, date: Date)],
        pulse: [(value: Int, date: Date)],
        glucose: [(value: Double, date: Date)],
        sleep: [(hours: Double, date: Date)],
        weight: [(value: Double, date: Date)]
    ) -> (results: [String: TrendResult], log: [String]) {
        var results: [String: TrendResult] = [:]
        var log: [String] = []

        log.append("[Trend] Starting trend analysis...")

        if let sysResult = analyzeSingleMetric(
            name: "bp_systolic",
            data: bp.map { (Double($0.systolic), $0.date) },
            log: &log
        ) {
            results["bp"] = sysResult
        }

        if let pulseResult = analyzeSingleMetric(
            name: "pulse",
            data: pulse.map { (Double($0.value), $0.date) },
            log: &log
        ) {
            results["pulse"] = pulseResult
        }

        if let glucoseResult = analyzeSingleMetric(
            name: "glucose",
            data: glucose.map { ($0.value, $0.date) },
            log: &log
        ) {
            results["glucose"] = glucoseResult
        }

        if let sleepResult = analyzeSingleMetric(
            name: "sleep",
            data: sleep.map { ($0.hours, $0.date) },
            log: &log
        ) {
            results["sleep"] = sleepResult
        }

        if let weightResult = analyzeSingleMetric(
            name: "weight",
            data: weight.map { ($0.value, $0.date) },
            log: &log
        ) {
            results["weight"] = weightResult
        }

        log.append("[Trend] Completed: \(results.count) metrics with trends, \(5 - results.count) insufficient data")
        return (results, log)
    }

    private func analyzeSingleMetric(name: String, data: [(Double, Date)], log: inout [String]) -> TrendResult? {
        guard data.count >= 5 else {
            log.append("[Trend] \(name): \(data.count) points (need >=5), skipped")
            return nil
        }

        let sorted = data.sorted { $0.1 < $1.1 }
        guard let earliest = sorted.first?.1, let latest = sorted.last?.1 else { return nil }

        let daySpan = Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 0
        guard daySpan >= minimumDays else {
            log.append("[Trend] \(name): \(data.count) points over \(daySpan) days (need >=\(minimumDays)), skipped")
            return nil
        }

        // Check if retraining needed
        if !shouldRetrain(metricName: name) {
            if let cached = loadCachedResult(metricName: name) {
                log.append("[Trend] \(name): \(data.count) pts, \(daySpan) days, CACHE HIT -> \(cached.direction.rawValue) (slope=\(String(format: "%.4f", cached.slopePerDay))/day)")
                // On cache hit, try to load compiled model from disk for projections
                let projection = loadProjectionsFromModel(name: name, data: sorted, earliest: earliest, totalDays: daySpan, currentAvg: sorted.suffix(7).map { $0.0 }.reduce(0, +) / Double(min(7, sorted.count)), log: &log)
                if projection != nil {
                    var result = cached
                    result.projection = projection
                    return result
                }
                return cached
            }
        }

        // Train linear regression using CreateML
        let result = trainLinearTrend(name: name, data: sorted, earliest: earliest, log: &log)
        if let result = result {
            cacheResult(metricName: name, result: result)
            setLastTrained(metricName: name)
        }
        return result
    }

    private func trainLinearTrend(name: String, data: [(Double, Date)], earliest: Date, log: inout [String]) -> TrendResult? {
        var dayIndices: [Double] = []
        var values: [Double] = []
        for (value, date) in data {
            let days = Double(Calendar.current.dateComponents([.day], from: earliest, to: date).day ?? 0)
            dayIndices.append(days)
            values.append(value)
        }

        let n = Double(dayIndices.count)
        let sumY = values.reduce(0, +)
        let meanY = sumY / n
        let totalDays = dayIndices.last ?? 0
        let recentAvg = data.suffix(7).map { $0.0 }.reduce(0, +) / Double(min(7, data.count))

        // Try CreateML MLLinearRegressor
        var mlProjection: HealthProjection? = nil
        do {
            let table = try MLDataTable(dictionary: [
                "dayIndex": dayIndices,
                "value": values
            ])
            let regressor = try MLLinearRegressor(trainingData: table, targetColumn: "value")

            // Save model
            let modelDir = modelDirectoryURL
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
            let modelURL = modelDir.appendingPathComponent("\(name).mlmodel")
            try regressor.write(to: modelURL)

            // Compile and predict future values
            let compiledURL = try MLModel.compileModel(at: modelURL)
            let model = try MLModel(contentsOf: compiledURL)

            let futureDays: [(String, Double)] = [
                ("oneWeek", totalDays + 7),
                ("oneMonth", totalDays + 30),
                ("threeMonths", totalDays + 90)
            ]

            var predictions: [String: Double] = [:]
            for (label, dayIdx) in futureDays {
                let provider = try MLDictionaryFeatureProvider(dictionary: ["dayIndex": MLFeatureValue(double: dayIdx)])
                let prediction = try model.prediction(from: provider)
                if let val = prediction.featureValue(for: "value")?.doubleValue {
                    predictions[label] = val
                }
            }

            if let w = predictions["oneWeek"], let m = predictions["oneMonth"], let t = predictions["threeMonths"] {
                let metricKey = name == "bp_systolic" ? "bp" : name
                mlProjection = HealthProjection(metric: metricKey, currentAvg: recentAvg, oneWeek: w, oneMonth: m, threeMonths: t)
            }

            // Extract slope from ML predictions
            let predStart = try MLDictionaryFeatureProvider(dictionary: ["dayIndex": MLFeatureValue(double: 0)])
            let predEnd = try MLDictionaryFeatureProvider(dictionary: ["dayIndex": MLFeatureValue(double: totalDays)])
            let startVal = try model.prediction(from: predStart).featureValue(for: "value")?.doubleValue ?? 0
            let endVal = try model.prediction(from: predEnd).featureValue(for: "value")?.doubleValue ?? 0
            let mlSlope = totalDays > 0 ? (endVal - startVal) / totalDays : 0

            let normalizedSlope = meanY != 0 ? mlSlope / meanY : mlSlope
            let direction: TrendDirection
            let message: String

            if normalizedSlope > 0.005 {
                direction = .worsening
                message = "\(name) is trending upward."
            } else if normalizedSlope < -0.005 {
                if name == "sleep" {
                    direction = .worsening
                    message = "Sleep duration is trending downward."
                } else {
                    direction = .improving
                    message = "\(name) is trending downward."
                }
            } else {
                direction = .stable
                message = "\(name) is stable."
            }

            log.append("[Trend] \(name): \(data.count) pts, \(Int(totalDays)) days, MLLinearRegressor trained, slope=\(String(format: "%.4f", mlSlope))/day, normalized=\(String(format: "%.5f", normalizedSlope)), direction=\(direction.rawValue)")

            return TrendResult(direction: direction, slopePerDay: mlSlope, message: message, projection: mlProjection)
        } catch {
            log.append("[Trend] \(name): MLLinearRegressor failed (\(error.localizedDescription)), falling back to manual regression")
        }

        // Fallback: hand-rolled linear regression
        let sumX = dayIndices.reduce(0, +)
        let sumXY = zip(dayIndices, values).map(*).reduce(0, +)
        let sumX2 = dayIndices.map { $0 * $0 }.reduce(0, +)

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else {
            log.append("[Trend] \(name): denominator=0 in regression, skipped")
            return nil
        }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        let normalizedSlope = meanY != 0 ? slope / meanY : slope
        let direction: TrendDirection
        let message: String

        let daySpan = Int(totalDays)

        if normalizedSlope > 0.005 {
            direction = .worsening
            message = "\(name) is trending upward."
        } else if normalizedSlope < -0.005 {
            if name == "sleep" {
                direction = .worsening
                message = "Sleep duration is trending downward."
            } else {
                direction = .improving
                message = "\(name) is trending downward."
            }
        } else {
            direction = .stable
            message = "\(name) is stable."
        }

        // Compute fallback projections from slope
        let metricKey = name == "bp_systolic" ? "bp" : name
        let fallbackProjection = HealthProjection(
            metric: metricKey,
            currentAvg: recentAvg,
            oneWeek: intercept + slope * (totalDays + 7),
            oneMonth: intercept + slope * (totalDays + 30),
            threeMonths: intercept + slope * (totalDays + 90)
        )

        log.append("[Trend] \(name): \(data.count) pts, \(daySpan) days, slope=\(String(format: "%.4f", slope))/day, normalized=\(String(format: "%.5f", normalizedSlope)), mean=\(String(format: "%.1f", meanY)), direction=\(direction.rawValue) (CACHE MISS, fallback regression)")

        return TrendResult(direction: direction, slopePerDay: slope, message: message, projection: fallbackProjection)
    }

    private func loadProjectionsFromModel(name: String, data: [(Double, Date)], earliest: Date, totalDays: Int, currentAvg: Double, log: inout [String]) -> HealthProjection? {
        let modelURL = modelDirectoryURL.appendingPathComponent("\(name).mlmodel")
        guard FileManager.default.fileExists(atPath: modelURL.path) else { return nil }

        do {
            let compiledURL = try MLModel.compileModel(at: modelURL)
            let model = try MLModel(contentsOf: compiledURL)
            let td = Double(totalDays)

            let futureDays: [(String, Double)] = [
                ("oneWeek", td + 7),
                ("oneMonth", td + 30),
                ("threeMonths", td + 90)
            ]

            var predictions: [String: Double] = [:]
            for (label, dayIdx) in futureDays {
                let provider = try MLDictionaryFeatureProvider(dictionary: ["dayIndex": MLFeatureValue(double: dayIdx)])
                let prediction = try model.prediction(from: provider)
                if let val = prediction.featureValue(for: "value")?.doubleValue {
                    predictions[label] = val
                }
            }

            if let w = predictions["oneWeek"], let m = predictions["oneMonth"], let t = predictions["threeMonths"] {
                let metricKey = name == "bp_systolic" ? "bp" : name
                log.append("[Trend] \(name): loaded compiled model for projections")
                return HealthProjection(metric: metricKey, currentAvg: currentAvg, oneWeek: w, oneMonth: m, threeMonths: t)
            }
        } catch {
            log.append("[Trend] \(name): failed to load model for projections (\(error.localizedDescription))")
        }
        return nil
    }

    // Persistence helpers

    private func shouldRetrain(metricName: String) -> Bool {
        let key = "ml_lastTrained_trend_\(metricName)"
        guard let lastTrained = UserDefaults.standard.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastTrained) > retrainIntervalSeconds
    }

    private func setLastTrained(metricName: String) {
        let key = "ml_lastTrained_trend_\(metricName)"
        UserDefaults.standard.set(Date(), forKey: key)
    }

    private func cacheResult(metricName: String, result: TrendResult) {
        let key = "ml_trendCache_\(metricName)"
        let dict: [String: Any] = [
            "direction": result.direction.rawValue,
            "slope": result.slopePerDay,
            "message": result.message
        ]
        UserDefaults.standard.set(dict, forKey: key)
    }

    private func loadCachedResult(metricName: String) -> TrendResult? {
        let key = "ml_trendCache_\(metricName)"
        guard let dict = UserDefaults.standard.dictionary(forKey: key),
              let dirStr = dict["direction"] as? String,
              let direction = TrendDirection(rawValue: dirStr),
              let slope = dict["slope"] as? Double,
              let message = dict["message"] as? String else {
            return nil
        }
        return TrendResult(direction: direction, slopePerDay: slope, message: message, projection: nil)
    }

    func clearCache() {
        let metrics = ["bp_systolic", "pulse", "glucose", "sleep", "weight"]
        for m in metrics {
            UserDefaults.standard.removeObject(forKey: "ml_lastTrained_trend_\(m)")
            UserDefaults.standard.removeObject(forKey: "ml_trendCache_\(m)")
        }
    }
}
