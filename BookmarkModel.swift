import Foundation
import SQLite3
import LinkPresentation

struct NodeInfo: Identifiable, Hashable {
    let id: String
    let path: String
    let kind: String
    let reason: String
    let title: String
    let url: String
}

class BookmarkModel: ObservableObject {
    @Published var nodes: [NodeInfo] = []
    @Published var duplicateCount = 0
    @Published var emptyCount = 0
    @Published var missingCount = 0
    @Published var allBookmarks: [NodeInfo] = []
    
    @Published var iconsToReview: [NodeInfo] = []
    @Published var isCheckingIcons = false
    @Published var iconCheckError: String? = nil
    
    @Published var hasUnsavedChanges = false
    @Published var excludedFolders: Set<String> = []
    @Published var allFolderNames: [String] = []
    
    @Published var isRepairing = false
    @Published var repairProgress: Double = 0
    @Published var currentRepairURL: String = ""
    @Published var currentRepairTitle: String = ""
    @Published var repairProcessedCount: Int = 0
    @Published var repairTotalCount: Int = 0
    @Published var repairRecoveredCount: Int = 0
    @Published var repairManualCount: Int = 0
    @Published var repairFailedCount: Int = 0
    @Published var repairStatuses: [String: String] = [:] // url -> status text
    @Published var repairFetchedImage: NSImage? = nil
    @Published var isWaitingForManualFix: Bool = false
    @Published var currentFailedBookmark: NodeInfo? = nil
    @Published var showRepairSummary: Bool = false
    
    var onManualFixResolved: (() -> Void)? = nil
    private var currentProcess: Process? = nil
    private var isManualSkipTriggered: Bool = false
    private var currentRepairToken: UUID? = nil
    
    var plistData: [String: Any]?
    @Published var bookmarksPath: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Safari/Bookmarks.plist")
    
    func analyzePlist() {
        guard let data = try? Data(contentsOf: bookmarksPath),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
            print("Failed to load plist")
            return
        }
        
        injectUUID(&plist)
        analyzeData(plist)
    }
    
    private func analyzeData(_ plist: [String: Any]) {
        self.plistData = plist
        
        var seenUrls: [String: Bool] = [:]
        var newNodes: [NodeInfo] = []
        var foundFolders: Set<String> = []
        var dCount = 0
        var mCount = 0
        var eCount = 0
        
        func safeTitle(_ node: [String: Any]) -> String {
            if let title = node["Title"] as? String { return title }
            if let uriDict = node["URIDictionary"] as? [String: Any], let title = uriDict["title"] as? String { return title }
            if node["WebBookmarkType"] as? String == "WebBookmarkTypeProxy" {
                return node["WebBookmarkIdentifier"] as? String ?? "Proxy"
            }
            return "(untitled)"
        }
        
        func isLeaf(_ node: [String: Any]) -> Bool {
            return node["WebBookmarkType"] as? String == "WebBookmarkTypeLeaf"
        }
        
        func isList(_ node: [String: Any]) -> Bool {
            return node["WebBookmarkType"] as? String == "WebBookmarkTypeList"
        }
        
        func buildPath(_ parentTitles: [String], _ title: String) -> String {
            var parts = parentTitles.filter { !$0.isEmpty }
            if !title.isEmpty { parts.append(title) }
            return parts.joined(separator: " / ")
        }
        
        func normalizeURL(_ urlString: String) -> String {
            let raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty { return "" }
            guard let url = URL(string: raw) else { return raw }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.fragment = nil
            if let host = components?.host { components?.host = host.lowercased() }
            if let scheme = components?.scheme { components?.scheme = scheme.lowercased() }
            var p = components?.path ?? ""
            if p == "/" { p = "" }
            if p.hasSuffix("/") { p.removeLast() }
            components?.path = p
            return components?.url?.absoluteString ?? raw
        }
        
        var allItems: [NodeInfo] = []
        
        func walk(_ node: [String: Any], parentTitles: [String]) {
            let title = safeTitle(node)
            if isList(node) && !title.isEmpty { foundFolders.insert(title) }
            
            let path = (parentTitles.isEmpty && title.isEmpty) ? "" : buildPath(parentTitles, title)
            let id = node["__uuid__"] as! String
            
            if isLeaf(node) {
                let urlRaw = node["URLString"] as? String ?? ""
                let url = normalizeURL(urlRaw)
                
                let info = NodeInfo(id: id, path: path, kind: "Bookmark", reason: "", title: title, url: urlRaw)
                allItems.append(info)
                
                if url.isEmpty {
                    newNodes.append(NodeInfo(id: id, path: path, kind: "Bookmark", reason: "Missing URL", title: title, url: ""))
                    mCount += 1
                } else if seenUrls[url] != nil {
                    newNodes.append(NodeInfo(id: id, path: path, kind: "Bookmark", reason: "Duplicate URL", title: title, url: urlRaw))
                    dCount += 1
                } else {
                    seenUrls[url] = true
                }
                return
            }
            
            if isList(node) {
                if let children = node["Children"] as? [[String: Any]] {
                    for child in children {
                        walk(child, parentTitles: parentTitles + [title])
                    }
                }
                return
            }
        }
        
        walk(plist, parentTitles: [])
        
        func folderHasBookmark(_ node: [String: Any]) -> Bool {
            if isLeaf(node) { return true }
            if isList(node) {
                if let children = node["Children"] as? [[String: Any]] {
                    for child in children {
                        if folderHasBookmark(child) { return true }
                    }
                }
            }
            return false
        }
        
        func markEmpty(_ node: [String: Any], parentTitles: [String], isRoot: Bool) {
            let title = safeTitle(node)
            let path = (parentTitles.isEmpty && title.isEmpty) ? "" : buildPath(parentTitles, title)
            let id = node["__uuid__"] as! String
            
            if isList(node) {
                if !isRoot && !folderHasBookmark(node) {
                    newNodes.append(NodeInfo(id: id, path: path, kind: "Folder", reason: "Empty folder", title: title, url: ""))
                    eCount += 1
                }
                if let children = node["Children"] as? [[String: Any]] {
                    for child in children {
                        markEmpty(child, parentTitles: parentTitles + [title], isRoot: false)
                    }
                }
            }
        }
        
        markEmpty(plist, parentTitles: [], isRoot: true)
        
        DispatchQueue.main.async {
            self.nodes = newNodes
            self.allBookmarks = allItems
            self.duplicateCount = dCount
            self.emptyCount = eCount
            self.missingCount = mCount
            self.allFolderNames = foundFolders.sorted()
        }
    }
    
    private func injectUUID(_ node: inout [String: Any]) {
        node["__uuid__"] = UUID().uuidString
        if var children = node["Children"] as? [[String: Any]] {
            for i in 0..<children.count {
                injectUUID(&children[i])
            }
            node["Children"] = children
        }
    }
    
    private func removeUUID(_ node: inout [String: Any]) {
        node.removeValue(forKey: "__uuid__")
        if var children = node["Children"] as? [[String: Any]] {
            for i in 0..<children.count {
                removeUUID(&children[i])
            }
            node["Children"] = children
        }
    }
    
    private func filterNodes(_ node: inout [String: Any], idsToRemove: Set<String>) {
        if var children = node["Children"] as? [[String: Any]] {
            children.removeAll { child in
                if let id = child["__uuid__"] as? String, idsToRemove.contains(id) {
                    return true
                }
                return false
            }
            for i in 0..<children.count {
                filterNodes(&children[i], idsToRemove: idsToRemove)
            }
            node["Children"] = children
        }
    }
    
    func deleteNodes(withIDs ids: Set<String>) {
        guard var root = plistData else { return }
        filterNodes(&root, idsToRemove: ids)
        self.hasUnsavedChanges = true
        analyzeData(root)
    }
    
    func deleteNode(withID id: String) {
        guard var root = plistData else { return }
        filterNodes(&root, idsToRemove: [id])
        self.hasUnsavedChanges = true
        analyzeData(root)
    }
    
    func updateURL(withID id: String, newURL: String) {
        guard var root = plistData else { return }
        
        func walkAndUpdate(_ node: inout [String: Any]) {
            if let nodeID = node["__uuid__"] as? String, nodeID == id {
                node["URLString"] = newURL
                return
            }
            if var children = node["Children"] as? [[String: Any]] {
                for i in 0..<children.count {
                    walkAndUpdate(&children[i])
                }
                node["Children"] = children
            }
        }
        
        walkAndUpdate(&root)
        self.hasUnsavedChanges = true
        analyzeData(root)
    }
    
    func resetBookmark(withID id: String) {
        guard var root = plistData else { return }
        
        var bookmarkData: [String: Any]?
        var parentUUID: String?
        var indexInParent: Int?
        
        func findParentAndIndex(_ node: [String: Any]) {
            if let children = node["Children"] as? [[String: Any]] {
                for (i, child) in children.enumerated() {
                    if let childID = child["__uuid__"] as? String, childID == id {
                        bookmarkData = child
                        parentUUID = node["__uuid__"] as? String
                        indexInParent = i
                        return
                    }
                    findParentAndIndex(child)
                    if bookmarkData != nil { return }
                }
            }
        }
        
        findParentAndIndex(root)
        
        guard let data = bookmarkData, let pUUID = parentUUID, let idx = indexInParent else {
            print("Reset Hack: Could not find bookmark or its parent.")
            return
        }
        
        // Step 1: Remove and Save
        filterNodes(&root, idsToRemove: [id])
        self.plistData = root
        savePlist() // Save to flush Safari
        
        // Step 2: Re-insert and Save
        func reinsert(_ node: inout [String: Any]) {
            if let nodeID = node["__uuid__"] as? String, nodeID == pUUID {
                if var children = node["Children"] as? [[String: Any]] {
                    children.insert(data, at: idx)
                    node["Children"] = children
                }
                return
            }
            if var children = node["Children"] as? [[String: Any]] {
                for i in 0..<children.count {
                    reinsert(&children[i])
                }
                node["Children"] = children
            }
        }
        
        reinsert(&root)
        self.plistData = root
        savePlist()
        
        // Re-analyze to refresh UI nodes
        analyzeData(root)
    }
    
    func identifyMissingIcons() {
        self.isCheckingIcons = true
        self.iconCheckError = nil
        
        // Find all bookmarks (leaves)
        var allBookmarks: [NodeInfo] = []
        
        func collectBookmarks(_ node: [String: Any], path: String) {
            let title = node["Title"] as? String ?? (node["URIDictionary"] as? [String: Any])?["title"] as? String ?? ""
            let id = node["__uuid__"] as? String ?? ""
            
            if node["WebBookmarkType"] as? String == "WebBookmarkTypeLeaf" {
                let url = node["URLString"] as? String ?? ""
                if !url.isEmpty && !url.hasPrefix("favorites://") && !url.hasPrefix("readinglist://") {
                    // Check if any part of the path is in excluded folders
                    let pathParts = path.split(separator: " / ").map(String.init)
                    let isExcluded = pathParts.contains { excludedFolders.contains($0) }
                    
                    if !isExcluded {
                        allBookmarks.append(NodeInfo(id: id, path: path, kind: "Bookmark", reason: "", title: title, url: url))
                    }
                }
            } else if node["WebBookmarkType"] as? String == "WebBookmarkTypeList" {
                if let children = node["Children"] as? [[String: Any]] {
                    for child in children {
                        collectBookmarks(child, path: path + (path.isEmpty ? "" : " / ") + title)
                    }
                }
            }
        }
        
        if let root = plistData {
            collectBookmarks(root, path: "")
        }
        
        if allBookmarks.isEmpty {
            self.isCheckingIcons = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let paths = [
                home.appendingPathComponent("Library/Safari/Favicon Cache/favicons.db").path,
                home.appendingPathComponent("Library/Safari/WebpageIcons.db").path,
                "/Users/\(NSUserName())/Library/Safari/Favicon Cache/favicons.db"
            ]
            
            var db: OpaquePointer?
            var cachedUrls = Set<String>()
            var success = false
            var errorMessage: String? = nil
            
            for path in paths {
                if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                    let query = "SELECT url FROM page_url"
                    var statement: OpaquePointer?
                    
                    if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                        success = true
                        while sqlite3_step(statement) == SQLITE_ROW {
                            if let cString = sqlite3_column_text(statement, 0) {
                                cachedUrls.insert(String(cString: cString))
                            }
                        }
                    }
                    sqlite3_finalize(statement)
                    sqlite3_close(db)
                    if success { break }
                } else {
                    errorMessage = "Operation not permitted. Please grant 'Full Disk Access' to the app in System Settings > Privacy & Security."
                }
            }
            
            if !success {
                DispatchQueue.main.async {
                    self.iconCheckError = errorMessage ?? "Could not find Safari icon database."
                    self.isCheckingIcons = false
                }
                return
            }
            
            // Filter bookmarks that are NOT in the cache
            let missing = allBookmarks.filter { bookmark in
                let url = bookmark.url
                // Check exact, with slash, and without slash
                if cachedUrls.contains(url) { return false }
                
                let withSlash = url.hasSuffix("/") ? url : url + "/"
                if cachedUrls.contains(withSlash) { return false }
                
                let withoutSlash = url.hasSuffix("/") ? String(url.dropLast()) : url
                if cachedUrls.contains(withoutSlash) { return false }
                
                // Try removing scheme
                let noScheme = url.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
                if cachedUrls.contains(where: { $0.contains(noScheme) }) { return false }
                
                return true
            }
            
            DispatchQueue.main.async {
                self.iconsToReview = missing
                self.isCheckingIcons = false
                if missing.isEmpty {
                    self.iconCheckError = "No bookmarks with missing icons found!"
                }
            }
        }
    }
    
    func checkIconRecovery(for urlString: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let paths = [
            home.appendingPathComponent("Library/Safari/Favicon Cache/favicons.db").path,
            home.appendingPathComponent("Library/Safari/WebpageIcons.db").path
        ]
        
        for path in paths {
            var db: OpaquePointer?
            if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                let query = "SELECT 1 FROM page_url WHERE url = ? OR url = ? OR url = ?"
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, urlString, -1, nil)
                    let withSlash = urlString.hasSuffix("/") ? urlString : urlString + "/"
                    sqlite3_bind_text(statement, 2, withSlash, -1, nil)
                    let withoutSlash = urlString.hasSuffix("/") ? String(urlString.dropLast()) : urlString
                    sqlite3_bind_text(statement, 3, withoutSlash, -1, nil)
                    
                    let found = (sqlite3_step(statement) == SQLITE_ROW)
                    sqlite3_finalize(statement)
                    sqlite3_close(db)
                    if found { return true }
                } else {
                    sqlite3_close(db)
                }
            }
        }
        return false
    }
    
    func repairIconsInSafari(bookmarks: [NodeInfo]) {
        self.isRepairing = true
        self.showRepairSummary = false
        self.repairProgress = 0
        self.repairProcessedCount = 0
        self.repairRecoveredCount = 0
        self.repairManualCount = 0
        self.repairFailedCount = 0
        self.repairStatuses = [:]
        self.repairFetchedImage = nil
        self.isWaitingForManualFix = false
        self.currentFailedBookmark = nil
        self.repairTotalCount = bookmarks.count
        
        let total = Double(bookmarks.count)
        var current = 0.0
        var resetAttemptedIDs: Set<String> = []
        
        func processNext() {
            guard current < total else {
                DispatchQueue.main.async {
                    self.showRepairSummary = true
                }
                return
            }
            
            let bookmark = bookmarks[Int(current)]
            let taskToken = UUID()
            self.currentRepairToken = taskToken
            
            func checkSkip() -> Bool {
                if self.isManualSkipTriggered || self.currentRepairToken != taskToken {
                    finishFailure()
                    return true
                }
                return false
            }
            
            func runSafariRefresh(completion: @escaping (Bool) -> Void) {
                if checkSkip() { return }
                
                DispatchQueue.main.async {
                    self.currentRepairURL = bookmark.url
                    self.currentRepairTitle = bookmark.title.isEmpty ? "Untitled" : bookmark.title
                    self.repairStatuses[bookmark.url] = "Safari Refresh..."
                }
                
                let script = """
                tell application "Safari"
                    if not (exists window 1) then
                        make new document
                    end if
                    tell window 1
                        set newTab to (make new tab with properties {URL:"\(bookmark.url)"})
                        delay 8
                        close newTab
                    end tell
                end tell
                """
                
                let process = Process()
                self.currentProcess = process
                process.launchPath = "/usr/bin/osascript"
                process.arguments = ["-e", script]
                
                process.terminationHandler = { _ in
                    self.currentProcess = nil
                    if self.isManualSkipTriggered || self.currentRepairToken != taskToken { 
                        DispatchQueue.main.async { finishFailure() }
                        return 
                    }
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                        if self.currentRepairToken != taskToken { return }
                        completion(self.checkIconRecovery(for: bookmark.url))
                    }
                }
                process.launch()
            }
            
            func handleFailure() {
                if checkSkip() { return }
                
                self.validateURL(bookmark.url) { status in
                    if checkSkip() { return }
                    
                    if status == "200 OK" {
                        if !resetAttemptedIDs.contains(bookmark.id) {
                            resetAttemptedIDs.insert(bookmark.id)
                            DispatchQueue.main.async {
                                self.repairStatuses[bookmark.url] = "Safari Reset Hack..."
                                self.resetBookmark(withID: bookmark.id)
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    if checkSkip() { return }
                                    runSafariRefresh { success in
                                        if self.currentRepairToken != taskToken { return }
                                        if success {
                                            finishSuccess()
                                        } else {
                                            tryManualFetch()
                                        }
                                    }
                                }
                            }
                        } else {
                            tryManualFetch()
                        }
                    } else {
                        tryManualFetch()
                    }
                }
            }
            
            func tryManualFetch() {
                if checkSkip() { return }
                
                DispatchQueue.main.async {
                    self.repairStatuses[bookmark.url] = "Manual Fallback..."
                    var targetURL = bookmark.url
                    if let url = URL(string: bookmark.url), let scheme = url.scheme, let host = url.host {
                        targetURL = "\(scheme)://\(host)/"
                    }
                    
                    self.fetchMetadata(for: targetURL) { image in
                        if checkSkip() { return }
                        if self.currentRepairToken != taskToken { return }
                        
                        DispatchQueue.main.async {
                            if self.currentRepairToken != taskToken { return }
                            if let image = image {
                                self.repairFetchedImage = image
                                self.repairManualCount += 1
                                self.repairStatuses[bookmark.url] = "Found (Manual)"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { 
                                    if self.currentRepairToken == taskToken && !self.isManualSkipTriggered { 
                                        finishSuccess() 
                                    }
                                }
                            } else {
                                finishFailure()
                            }
                        }
                    }
                }
            }
            
            func finishSuccess() {
                guard self.currentRepairToken == taskToken else { return }
                self.currentRepairToken = nil
                
                current += 1
                DispatchQueue.main.async {
                    self.repairProcessedCount = Int(current)
                    self.repairRecoveredCount += 1
                    self.repairStatuses[bookmark.url] = "Recovered!"
                    self.repairProgress = current / total
                    processNext()
                }
            }
            
            func finishFailure() {
                guard self.currentRepairToken == taskToken else { return }
                self.currentRepairToken = nil
                
                DispatchQueue.main.async {
                    if self.isManualSkipTriggered {
                        self.isManualSkipTriggered = false
                        current += 1
                        self.repairStatuses[bookmark.url] = "Skipped"
                        self.repairProcessedCount = Int(current)
                        self.repairProgress = current / total
                        processNext()
                    } else {
                        self.repairStatuses[bookmark.url] = "Needs manual check"
                        self.currentFailedBookmark = bookmark
                        self.isWaitingForManualFix = true
                        self.repairFailedCount += 1
                        self.onManualFixResolved = {
                            self.isWaitingForManualFix = false
                            self.currentFailedBookmark = nil
                            self.repairFetchedImage = nil
                            current += 1
                            self.repairProcessedCount = Int(current)
                            self.repairProgress = current / total
                            processNext()
                        }
                    }
                }
            }
            
            runSafariRefresh { success in
                if self.currentRepairToken != taskToken { return }
                if success {
                    finishSuccess()
                } else {
                    handleFailure()
                }
            }
        }
        
        processNext()
    }
    
    func resolveManualRepairFix(didDelete: Bool = false) {
        if didDelete {
            // Already handled by deleteNode call if called from UI
        }
        onManualFixResolved?()
    }
    
    func skipCurrentRepair() {
        self.isManualSkipTriggered = true
        self.currentRepairToken = nil // Invalidate immediately
        self.currentProcess?.terminate()
        
        // Force loop to continue immediately on next main thread cycle
        DispatchQueue.main.async {
            self.resolveManualRepairFix() // This will trigger onManualFixResolved if waiting, or finishFailure logic
        }
    }
    
    func searchWeb(for bookmark: NodeInfo) {
        let query = bookmark.title.isEmpty ? bookmark.url : bookmark.title
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func deleteFailedRepairBookmarks() {
        // Collect IDs of bookmarks where status is "Failed"
        let failedURLs = repairStatuses.filter { $0.value == "Failed" }.map { $0.key }
        let idsToDelete = nodes.filter { failedURLs.contains($0.url) }.map { $0.id }
        deleteNodes(withIDs: Set(idsToDelete))
    }
    
    func validateURL(_ urlString: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: urlString) else {
            completion("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion("Error: \(error.localizedDescription)")
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let status = httpResponse.statusCode
                DispatchQueue.main.async {
                    if status == 200 {
                        completion("200 OK")
                    } else {
                        completion("Status: \(status)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion("Unknown Response")
                }
            }
        }
        task.resume()
    }
    
    func fetchMetadata(for urlString: String, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // Ensure completion is called on main thread and only once
        var isDone = false
        let safeCompletion: (NSImage?) -> Void = { image in
            DispatchQueue.main.async {
                if !isDone {
                    isDone = true
                    completion(image)
                }
            }
        }
        
        // Robust 15-second timeout for the entire fetch + load process
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            safeCompletion(nil)
        }
        
        DispatchQueue.main.async {
            let provider = LPMetadataProvider()
            provider.timeout = 12
            
            provider.startFetchingMetadata(for: url) { metadata, error in
                if isDone { return }
                
                guard let metadata = metadata else {
                    safeCompletion(nil)
                    return
                }
                
                if let iconProvider = metadata.iconProvider {
                    iconProvider.loadObject(ofClass: NSImage.self) { image, _ in
                        safeCompletion(image as? NSImage)
                    }
                } else {
                    safeCompletion(nil)
                }
            }
        }
    }
    
    func savePlist() {
        guard var root = plistData else { return }
        removeUUID(&root)
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
            try data.write(to: bookmarksPath)
            self.hasUnsavedChanges = false
            print("Saved successfully to \(bookmarksPath)")
        } catch {
            print("Failed to save: \(error)")
        }
    }
}
