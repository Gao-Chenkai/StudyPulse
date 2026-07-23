//
//  MemoryClimateHistoryStore.swift
//  StudyPulse
//

import Foundation
import os

nonisolated enum MemoryClimateHistoryStore {
    static let fileName = "memory_climate_history.json"
    static let retentionDays = 90
    static let currentVersion = 1

    private struct Envelope: Codable {
        let version: Int
        let snapshots: [MemoryClimateSnapshot]
    }

    static func fileURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent(fileName)
    }

    static func load(from explicitURL: URL? = nil) -> [MemoryClimateSnapshot] {
        guard let url = explicitURL ?? (try? fileURL()),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.version <= currentVersion else {
                Log.data.warning("Memory climate history uses a newer version: \(envelope.version, privacy: .public)")
                return []
            }
            return envelope.snapshots.sorted { $0.date > $1.date }
        } catch {
            Log.data.error("Memory climate history decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    static func save(
        _ snapshots: [MemoryClimateSnapshot],
        to explicitURL: URL? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard let url = explicitURL ?? (try? fileURL()) else { return }
        let retained = prune(snapshots, now: now, calendar: calendar)
        do {
            let data = try JSONEncoder().encode(
                Envelope(version: currentVersion, snapshots: retained)
            )
            try data.write(to: url, options: .atomic)
        } catch {
            Log.data.error("Memory climate history save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    static func upsert(
        _ snapshot: MemoryClimateSnapshot,
        at explicitURL: URL? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MemoryClimateSnapshot] {
        let day = calendar.startOfDay(for: snapshot.date)
        var history = load(from: explicitURL).filter {
            !(calendar.isDate($0.date, inSameDayAs: day) && $0.phaseId == snapshot.phaseId)
        }
        history.append(
            MemoryClimateSnapshot(date: day, phaseId: snapshot.phaseId, subjects: snapshot.subjects)
        )
        history = prune(history, now: now, calendar: calendar)
        save(history, to: explicitURL, now: now, calendar: calendar)
        return history
    }

    static func prune(
        _ snapshots: [MemoryClimateSnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MemoryClimateSnapshot] {
        let today = calendar.startOfDay(for: now)
        let cutoff = calendar.date(byAdding: .day, value: -(retentionDays - 1), to: today) ?? today
        return snapshots
            .filter { $0.date >= cutoff && $0.date <= now }
            .sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                return ($0.phaseId?.uuidString ?? "") < ($1.phaseId?.uuidString ?? "")
            }
    }
}
