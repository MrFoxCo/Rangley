import Foundation
import SQLite3



public final class DbManager {
    public static let shared = DbManager()

    private let dbURL   : URL
    private var db      : OpaquePointer?
    private let queue = DispatchQueue(label: "DbManager.sqlite.serial") // serialize access

    
    private enum SQLiteOpenError: Error {
        case cantOpen(String)
    }

    private func openSQLite(at url: URL) throws {
        // Ensure parent dir exists & writable
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(url.path, &db, flags, nil)
        guard rc == SQLITE_OK else {
            let err = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if db != nil { sqlite3_close(db); db = nil }
            throw SQLiteOpenError.cantOpen(err)
        }
    }

    
    // MARK: - Init / Open
    private init() {
        // Prefer Application Support, ensure it exists
        let fm = FileManager.default
        let base = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.dbURL = base.appendingPathComponent("rangley.sqlite")

        queue.sync {
            openAndBootstrap()
        }
    }

    deinit {
        queue.sync {
            if db != nil { sqlite3_close(db) }
        }
    }

    public var database: OpaquePointer? { queue.sync { db } }

    // If you want to run any DB task safely on the serial queue:
    @discardableResult
    public func sync<T>(_ body: (OpaquePointer?) -> T) -> T {
        queue.sync { body(db) }
    }
}

// MARK: - Open & Bootstrap

private extension DbManager {
    func openAndBootstrap()
    {
        do {
            try openSQLite(at: dbURL)
        } catch {
            // If opening failed, try a hard reset once
            print("Open failed: \(error). Attempting DB reset…")
            if resetDatabase() == false {
                fatalError("Database reset failed: \(error)")
            }
            do {
                try openSQLite(at: dbURL)
            } catch {
                fatalError("Failed to open database after reset: \(error)")
            }
        }

        if let cPath = sqlite3_db_filename(db, "main") {
            print("DB PATH (main): \(String(cString: cPath))")
        } else {
            print("DB PATH (main): <nil>")
        }

        setPragmas()

        if isDatabaseEmpty() {
            print("Database is new - creating tables/views")
            createSchema()
        } else {
            print("Database exists - connecting to existing data")
        }
    }

}

// MARK: - Pragmas / Helpers

private extension DbManager {
    func setPragmas()
    {
        _ = execSQL("PRAGMA journal_mode=WAL;")
        _ = execSQL("PRAGMA synchronous = NORMAL;")
        _ = execSQL("PRAGMA busy_timeout = 5000;")
        _ = execSQL("PRAGMA temp_store = MEMORY;")
        _ = execSQL("PRAGMA foreign_keys = OFF;") // by design in your project
    }

    func isDatabaseEmpty() -> Bool
    {
        // treat "no user tables" as empty (views don’t count)
        let sql = """
        SELECT name FROM sqlite_master
        WHERE type='table' AND name NOT LIKE 'sqlite_%' LIMIT 1;
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return true }
        return sqlite3_step(stmt) != SQLITE_ROW
    }

    @discardableResult
    func execSQL(_ sql: String) -> Bool
    {
        var errMsg: UnsafeMutablePointer<Int8>? = nil
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        defer { if errMsg != nil { sqlite3_free(errMsg) } }
        if rc == SQLITE_OK { return true }
        if let e = errMsg { print("SQL error: \(String(cString: e)) for: \(sql.prefix(200))") }
        else { print("SQL error code \(rc) for: \(sql.prefix(200))") }
        return false
    }

    func runInTransaction(_ body: () -> Bool)
    {
        guard execSQL("BEGIN IMMEDIATE TRANSACTION;") else { return }
        if body() { _ = execSQL("COMMIT;") } else { _ = execSQL("ROLLBACK;") }
    }
}

// MARK: - Schema Creation (tables + views)

private extension DbManager {
    func createSchema()
    {
        print("=== CREATING SCHEMA ===")
        let allTables = TableSchema.lookupTables + TableSchema.normalTables

        // 1) Base lookups (single-table views; no dependencies on other views)
        let allViews: [String] = [
            Views.vwFeatures,            // tdFeatures
            Views.vwMeetCategory,        // tdMeetCategory
            Views.vwSubCategory,         // tdSubCategory
            Views.vwMeetStatus,          // tdMeetStatus
            Views.vwParticpantStatus,    // tdParticpantStatus
            Views.vwNotificationType,    // tdNotificationType
            Views.vwMeetIcon,            // tdMeetIcon

            // 2) Base entities (single-table views; no dependencies on other views)
            Views.vwUsers,               // tbUsers
            Views.vwMeetAddresses,       // tbMeetAddresses
            Views.vwMeetIDs,             // tbMeetIDs  (ensure its SQL ends with ';')
            Views.vwMeets,               // tbMeets
            Views.vwMeetChangeStamps,    // tbMeetChangeStamps
            Views.vwMeetParticipants,    // tbMeetParticipants
            Views.vwNotifications,       // tbNotifications
            Views.vwUserInboxes,         // tbUserInboxes

            // 3) Dependent views (must come after the above)
            Views.vwLatestMeetVersions,   // depends on: vwMeets
            Views.vwMeetCategoryIDAndName,// depends on: vwMeetCategory
            Views.vwMeetCardData          // depends on: vwLatestMeetVersions, vwMeets, vwMeetIDs, vwMeetAddresses, vwUsers, vwMeetCategory
        ]

        runInTransaction {
            var ok = true

            // Create tables
            for (i, sql) in allTables.enumerated() {
                if !execSQL(sql) {
                    print("Failed creating table #\(i + 1):\n\(sql)")
                    ok = false; break
                }
            }

            guard ok else { return false }

            // Create views
            for (i, sql) in allViews.enumerated() {
                if !execSQL(sql) {
                    print("Failed creating view #\(i + 1)")
                    ok = false; break
                }
            }
            print("=== SCHEMA CREATION COMPLETE ===")
            return ok
        }

        // (Optional) Kick a WAL checkpoint right after first boot
        _ = execSQL("PRAGMA wal_checkpoint(TRUNCATE);")
    }
    
    /// Nukes the main file + WAL/SHM, then returns true if all deletes succeeded.
    @discardableResult
    func resetDatabase() -> Bool
    {
        if db != nil { sqlite3_close(db); db = nil }

        let fm = FileManager.default
        let dir = dbURL.deletingLastPathComponent()
        do {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            let main = dbURL
            let wal  = dir.appendingPathComponent(dbURL.lastPathComponent + "-wal")
            let shm  = dir.appendingPathComponent(dbURL.lastPathComponent + "-shm")

            for url in [main, wal, shm] {
                if fm.fileExists(atPath: url.path) {
                    try fm.removeItem(at: url)
                }
            }
            print("Database reset: removed \(main.lastPathComponent), \(wal.lastPathComponent), \(shm.lastPathComponent)")
            return true
        } catch {
            print("Database reset failed: \(error)")
            return false
        }
    }


}
