import Foundation
import SQLite3

/// Minimal wrapper over the system SQLite library. Not thread-safe on its own;
/// it is only used from inside the `LibraryStore` actor.
final class Database {
    struct SQLError: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    private var handle: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(handle)
            throw SQLError(message: "Could not open the library database: \(message)")
        }
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA foreign_keys = ON")
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(error)
            throw SQLError(message: message)
        }
    }

    /// Runs `sql` with positional `?` parameters. Calls `row` for each result row.
    func run(_ sql: String, _ params: [SQLValue] = [], row: ((Row) throws -> Void)? = nil) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else { throw lastError() }
        defer { sqlite3_finalize(stmt) }
        for (i, param) in params.enumerated() {
            let index = Int32(i + 1)
            switch param {
            case .null: sqlite3_bind_null(stmt, index)
            case .int(let v): sqlite3_bind_int64(stmt, index, v)
            case .double(let v): sqlite3_bind_double(stmt, index, v)
            case .text(let v): sqlite3_bind_text(stmt, index, v, -1, SQLITE_TRANSIENT)
            case .blob(let v):
                _ = v.withUnsafeBytes { sqlite3_bind_blob(stmt, index, $0.baseAddress, Int32(v.count), SQLITE_TRANSIENT) }
            }
        }
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                try row?(Row(stmt: stmt))
            } else if rc == SQLITE_DONE {
                return
            } else {
                throw lastError()
            }
        }
    }

    var lastInsertRowID: Int64 { sqlite3_last_insert_rowid(handle) }

    var userVersion: Int {
        get {
            var v = 0
            try? run("PRAGMA user_version") { v = Int($0.int(0)) }
            return v
        }
        set { try? execute("PRAGMA user_version = \(newValue)") }
    }

    func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func lastError() -> SQLError {
        SQLError(message: String(cString: sqlite3_errmsg(handle)))
    }

    struct Row {
        let stmt: OpaquePointer?
        func isNull(_ i: Int32) -> Bool { sqlite3_column_type(stmt, i) == SQLITE_NULL }
        func int(_ i: Int32) -> Int64 { sqlite3_column_int64(stmt, i) }
        func double(_ i: Int32) -> Double { sqlite3_column_double(stmt, i) }
        func optionalInt(_ i: Int32) -> Int64? { isNull(i) ? nil : int(i) }
        func optionalDouble(_ i: Int32) -> Double? { isNull(i) ? nil : double(i) }
        func optionalDate(_ i: Int32) -> Date? { optionalDouble(i).map(Date.init(timeIntervalSince1970:)) }
        func text(_ i: Int32) -> String {
            guard let c = sqlite3_column_text(stmt, i) else { return "" }
            return String(cString: c)
        }
        func optionalText(_ i: Int32) -> String? { isNull(i) ? nil : text(i) }
        func blob(_ i: Int32) -> Data? {
            guard !isNull(i), let p = sqlite3_column_blob(stmt, i) else { return nil }
            return Data(bytes: p, count: Int(sqlite3_column_bytes(stmt, i)))
        }
    }
}

enum SQLValue {
    case null, int(Int64), double(Double), text(String), blob(Data)

    static func date(_ d: Date?) -> SQLValue { d.map { .double($0.timeIntervalSince1970) } ?? .null }
    static func optional(_ v: Double?) -> SQLValue { v.map { .double($0) } ?? .null }
    static func optional(_ v: Int?) -> SQLValue { v.map { .int(Int64($0)) } ?? .null }
    static func optional(_ v: String?) -> SQLValue { v.map { .text($0) } ?? .null }
}

/// SQLite's "copy this string now" destructor constant, which Swift can't import directly.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
