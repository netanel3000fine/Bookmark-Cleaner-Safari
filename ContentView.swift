import SwiftUI

struct ContentView: View {
    @StateObject private var model = BookmarkModel()
    @State private var searchText = ""
    @State private var selectedNodeIDs = Set<NodeInfo.ID>()
    
    @AppStorage("isLiquidGlass") private var isLiquidGlass: Bool = false
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingScanResult = false
    @State private var showingSaveSuccess = false
    @State private var showingChooseConfirmation = false
    @State private var showingNoChanges = false
    @State private var showingRepairChoice = false
    @State private var isConfiguringIconCheck = false
    
    @State private var isReviewingIcons = false
    @State private var currentReviewIndex = 0
    @State private var newExcludedFolder = ""
    
    var body: some View {
        ZStack {
            // Background Layer
            if isLiquidGlass {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                if let color = themeColor.color {
                    color.opacity(0.08).ignoresSafeArea()
                }
            } else if let color = themeColor.color {
                color.opacity(0.05).ignoresSafeArea()
            }
            
            
            // Main Content Layer
            NavigationSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(model.bookmarksPath.path)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.78))
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .padding(.bottom, 4)
                        
                        VStack(spacing: 12) {
                            LiquidButton(title: "Choose File", color: themeColor.color) {
                                if model.plistData != nil {
                                    showingChooseConfirmation = true
                                } else {
                                    chooseFile()
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Duplicate Management")
                                    .font(.system(.caption2, design: .rounded).bold())
                                    .foregroundStyle(.secondary.opacity(0.8))
                                
                                LiquidButton(title: "Scan Duplicate URL", color: themeColor.color) {
                                    model.analyzePlist()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if model.nodes.isEmpty {
                                            showingScanResult = true
                                        }
                                    }
                                }
                                
                                LiquidButton(title: "Delete Selected", color: .red, isRed: true) {
                                    model.deleteNodes(withIDs: selectedNodeIDs)
                                    selectedNodeIDs.removeAll()
                                }
                                .disabled(selectedNodeIDs.isEmpty)
                                .opacity(selectedNodeIDs.isEmpty ? 0.3 : 1.0)
                                
                                LiquidButton(title: "Apply Changes", color: themeColor.color) {
                                    if model.hasUnsavedChanges {
                                        model.savePlist()
                                        showingSaveSuccess = true
                                    } else {
                                        showingNoChanges = true
                                    }
                                }
                            }
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.04))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.06), lineWidth: 1)
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Icon Management")
                                    .font(.system(.caption2, design: .rounded).bold())
                                    .foregroundStyle(.secondary.opacity(0.8))
                                
                                LiquidButton(title: model.isCheckingIcons ? "Checking Icons..." : "Check Missing Icons", color: themeColor.color) {
                                    if model.plistData == nil {
                                        model.analyzePlist()
                                    }
                                    
                                    if model.plistData != nil {
                                        isConfiguringIconCheck = true
                                    }
                                }
                                .disabled(model.isCheckingIcons)
                            }
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.04))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.06), lineWidth: 1)
                            }
                        }
                        
                        Divider()
                            .overlay(Color.primary.opacity(0.08))
                        
                        Text("Stats")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            StatRow(title: "Duplicate URLs", value: "\(model.duplicateCount)", color: themeColor.color)
                            StatRow(title: "Empty Folders", value: "\(model.emptyCount)", color: themeColor.color)
                            StatRow(title: "Missing URLs", value: "\(model.missingCount)", color: themeColor.color)
                            StatRow(title: "Selected", value: "\(selectedNodeIDs.count)", color: .accentColor)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.never)
                .scrollContentBackground(.hidden)
                .background {
                    ZStack {
                        if isLiquidGlass {
                            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                        } else if colorScheme == .dark {
                            Color(red: 0.145, green: 0.145, blue: 0.155)
                        } else {
                            Color(NSColor.windowBackgroundColor)
                        }
                        
                        if let color = themeColor.color, isLiquidGlass {
                            color.opacity(0.025)
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 260)
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search bookmarks")
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08))
                        .frame(width: 1)
                }
            } detail: {
                Table(filteredNodes, selection: $selectedNodeIDs) {
                    TableColumn("Type", value: \.kind)
                        .width(min: 50, ideal: 80, max: 120)
                    TableColumn("Title", value: \.title)
                        .width(min: 100, ideal: 200, max: 600)
                    TableColumn("URL", value: \.url)
                        .width(min: 150, ideal: 300, max: 1000)
                    TableColumn("Path", value: \.path)
                        .width(min: 150, ideal: 300, max: 1000)
                    TableColumn("Reason", value: \.reason)
                        .width(min: 80, ideal: 120, max: 200)
                }
                .scrollContentBackground(isLiquidGlass ? .hidden : .automatic)
                .background(isLiquidGlass ? Color.clear : nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if model.nodes.isEmpty {
                        Text("No scan yet or no issues found.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
            
            // Overlay Layer (Popups)
            if model.isRepairing {
                RepairProgressOverlay(model: model) {
                    model.isRepairing = false
                    model.identifyMissingIcons()
                }
            }
            
            if isConfiguringIconCheck {
                IconCheckOptionsOverlay(model: model, onClose: { isConfiguringIconCheck = false }) {
                    isConfiguringIconCheck = false
                    model.identifyMissingIcons()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if !model.iconsToReview.isEmpty {
                            showingRepairChoice = true
                        }
                    }
                }
            }
        }
        .onAppear {
            model.analyzePlist()
        }
        .alert("Change File?", isPresented: $showingChooseConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Choose New File") { chooseFile() }
        } message: {
            Text("The app is currently managing a bookmarks file. Are you sure you want to choose a different one?")
        }
        .alert("Scan Results", isPresented: $showingScanResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No duplicate URLs or empty folders were found in your bookmarks.")
        }
        .alert("Changes Applied", isPresented: $showingSaveSuccess) {
            Button("Great!", role: .cancel) { }
        } message: {
            Text("Your Safari bookmarks have been successfully updated.")
        }
        .alert("No Changes", isPresented: $showingNoChanges) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No modifications were made to the bookmarks, so there is nothing to apply.")
        }
        .alert("Icon Check", isPresented: Binding<Bool>(
            get: { model.iconCheckError != nil },
            set: { _ in model.iconCheckError = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.iconCheckError ?? "")
        }
        .alert("Repair Icons?", isPresented: $showingRepairChoice) {
            Button("Yes, Repair in Safari") {
                model.repairIconsInSafari(bookmarks: model.iconsToReview)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Found \(model.iconsToReview.count) bookmarks with missing icons. Would you like to automatically repair them? If any icons cannot be found, you will be prompted to fix the URL manually.")
        }
    }
    
    func nextReviewItem() {
        if currentReviewIndex < model.iconsToReview.count - 1 {
            currentReviewIndex += 1
        } else {
            isReviewingIcons = false
        }
    }
    
    func searchReplacement(for bookmark: NodeInfo) {
        let query = bookmark.title.isEmpty ? bookmark.url : bookmark.title
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    var filteredNodes: [NodeInfo] {
        if searchText.isEmpty {
            return model.nodes
        } else {
            return model.allBookmarks.filter { node in
                node.title.localizedCaseInsensitiveContains(searchText) ||
                node.url.localizedCaseInsensitiveContains(searchText) ||
                node.path.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.bookmarksPath = url
            model.analyzePlist()
        }
    }
}



struct StatRow: View {
    let title: String
    let value: String
    let color: Color?
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color ?? .primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
}

struct LiquidButton: View {
    let title: String
    let color: Color?
    var isRed: Bool = false
    var action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded).weight(.heavy))
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(LiquidButtonStyle(color: color, isRed: isRed, isHovered: isHovered))
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

struct LiquidButtonStyle: ButtonStyle {
    let color: Color?
    var isRed: Bool = false
    let isHovered: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isRed ? Color.red : (color ?? .primary)).opacity(configuration.isPressed ? 0.4 : (isHovered ? 0.3 : 0.15)),
                                    (isRed ? Color.red : (color ?? .primary)).opacity(configuration.isPressed ? 0.3 : (isHovered ? 0.2 : 0.08))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(isHovered ? 0.2 : 0.12), .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                    
                    if isHovered {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill((isRed ? Color.red : (color ?? .primary)).opacity(0.1))
                            .blur(radius: 8)
                    }
                    
                    VisualEffectView(material: .selection, blendingMode: .withinWindow)
                        .opacity(configuration.isPressed ? 0.5 : (isHovered ? 0.4 : 0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                (isRed ? Color.red : (color ?? .primary)).opacity(isHovered ? 0.8 : 0.4),
                                (isRed ? Color.red : (color ?? .primary)).opacity(isHovered ? 0.4 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 0.8
                    )
            }
            .foregroundStyle(isRed ? .red : (color ?? .primary))
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

struct ReviewOverlay: View {
    let bookmark: NodeInfo
    let index: Int
    let total: Int
    let themeColor: Color?
    var onSkip: () -> Void
    var onDelete: () -> Void
    var onSearch: () -> Void
    var onValidate: (String, @escaping (String) -> Void) -> Void
    var onFetchIcon: (String, @escaping (NSImage?) -> Void) -> Void
    var onSaveURL: (String) -> Void
    var onClose: () -> Void
    
    @State private var editedURL: String = ""
    @State private var validationStatus: String? = nil
    @State private var isValidating = false
    @State private var fetchedIcon: NSImage? = nil
    @State private var isFetchingIcon = false
    @State private var hasTriedFetching = false
    
    init(bookmark: NodeInfo, index: Int, total: Int, themeColor: Color?, onSkip: @escaping () -> Void, onDelete: @escaping () -> Void, onSearch: @escaping () -> Void, onValidate: @escaping (String, @escaping (String) -> Void) -> Void, onFetchIcon: @escaping (String, @escaping (NSImage?) -> Void) -> Void, onSaveURL: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.bookmark = bookmark
        self.index = index
        self.total = total
        self.themeColor = themeColor
        self.onSkip = onSkip
        self.onDelete = onDelete
        self.onSearch = onSearch
        self.onValidate = onValidate
        self.onFetchIcon = onFetchIcon
        self.onSaveURL = onSaveURL
        self.onClose = onClose
        self._editedURL = State(initialValue: bookmark.url)
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            VStack(spacing: 0) {
                HStack {
                    Text("Missing Icon Review")
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    Text("\(index + 1) of \(total)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.primary.opacity(0.05))
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            if let icon = fetchedIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: "globe")
                                            .foregroundStyle(.secondary)
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookmark.title.isEmpty ? "Untitled Bookmark" : bookmark.title)
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundStyle(.secondary)
                            
                            TextField("URL", text: $editedURL)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                                .onChange(of: editedURL) { _ in
                                    validationStatus = nil
                                }
                        }
                        
                        if let status = validationStatus {
                            HStack {
                                Image(systemName: status.contains("200") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                Text(status)
                            }
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(status.contains("200") ? .green : .orange)
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    
                    Text("This bookmark has no icon in Safari's cache. You can verify the link, fix the URL, or search for a replacement.")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            if validationStatus != "200 OK" {
                                ReviewButton(title: isValidating ? "Checking..." : "Verify Link", color: .purple) {
                                    isValidating = true
                                    onValidate(editedURL) { status in
                                        validationStatus = status
                                        isValidating = false
                                        if status == "200 OK" && editedURL != bookmark.url {
                                            onSaveURL(editedURL)
                                        }
                                    }
                                }
                                .disabled(isValidating)
                            } else {
                                ReviewButton(title: "Verified!", color: .green) { }
                                    .disabled(true)
                            }
                            
                            if editedURL != bookmark.url {
                                ReviewButton(title: "Save URL", color: .orange) {
                                    onSaveURL(editedURL)
                                }
                            }
                            
                            ReviewButton(title: "Search Web", color: themeColor ?? .accentColor, action: onSearch)
                        }
                        
                        if validationStatus == "200 OK" {
                            if hasTriedFetching && fetchedIcon == nil {
                                VStack(spacing: 8) {
                                    Text("No icon could be retrieved from this homepage.")
                                        .font(.system(.caption, design: .rounded).bold())
                                        .foregroundStyle(.red.opacity(0.8))
                                    
                                    ReviewButton(title: "Delete Bookmark", color: .red) {
                                        onDelete()
                                    }
                                    
                                    ReviewButton(title: "Skip Anyway", color: .gray) {
                                        onSkip()
                                    }
                                }
                                .padding()
                                .background(Color.red.opacity(0.05))
                                .cornerRadius(12)
                            } else if fetchedIcon != nil {
                                ReviewButton(title: "Next Bookmark", color: .green) {
                                    validationStatus = nil
                                    fetchedIcon = nil
                                    hasTriedFetching = false
                                    onSkip()
                                }
                                .padding(.top, 4)
                            } else {
                                ReviewButton(title: isFetchingIcon ? "Fetching Icon..." : "Fetch Icon from Homepage", color: .teal) {
                                    isFetchingIcon = true
                                    onFetchIcon(editedURL) { icon in
                                        fetchedIcon = icon
                                        isFetchingIcon = false
                                        hasTriedFetching = true
                                    }
                                }
                                .disabled(isFetchingIcon)
                                .padding(.top, 4)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            ReviewButton(title: "Skip", color: .gray, action: {
                                validationStatus = nil
                                onSkip()
                            })
                            ReviewButton(title: "Delete", color: .red, action: onDelete)
                        }
                    }
                }
                .padding(24)
            }
            .frame(width: 450)
            .background {
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    Color.white.opacity(0.05)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 20)
        }
        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
        .onAppear {
            isValidating = true
            onValidate(editedURL) { status in
                validationStatus = status
                isValidating = false
            }
        }
    }
}

struct ReviewButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded).weight(.bold))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(isHovered ? 0.2 : 0.1))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(color.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .onHover { h in isHovered = h }
    }
}

struct RepairProgressOverlay: View {
    @ObservedObject var model: BookmarkModel
    var onDone: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                if model.showRepairSummary {
                    // Summary Screen
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        VStack(spacing: 8) {
                            Text("Repair Complete")
                                .font(.system(.title, design: .rounded).bold())
                            
                            HStack(spacing: 15) {
                                VStack(spacing: 4) {
                                    Text("\(model.repairRecoveredCount)")
                                        .font(.system(.title3, design: .rounded).bold())
                                        .foregroundStyle(.green)
                                    Text("Safari")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                                
                                VStack(spacing: 4) {
                                    Text("\(model.repairManualCount)")
                                        .font(.system(.title3, design: .rounded).bold())
                                        .foregroundStyle(.teal)
                                    Text("Manual")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.teal.opacity(0.1))
                                .cornerRadius(10)
                                
                                VStack(spacing: 4) {
                                    Text("\(model.repairFailedCount)")
                                        .font(.system(.title3, design: .rounded).bold())
                                        .foregroundStyle(.red)
                                    Text("Failed")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .frame(width: 320)
                        }
                        
                        Text("Safari icons were refreshed by opening pages. Bookmarks that failed both Safari and manual fetching are listed as 'Failed'.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            if model.repairFailedCount > 0 {
                                LiquidButton(title: "Delete \(model.repairFailedCount) Remaining Failed", color: .red, isRed: true) {
                                    model.deleteFailedRepairBookmarks()
                                    onDone()
                                }
                            }
                            
                            LiquidButton(title: "Finish", color: .teal) {
                                onDone()
                            }
                        }
                        .frame(width: 320)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Progress Screen
                    VStack(spacing: 24) {
                        // Icon Display
                        ZStack {
                            Circle()
                                .stroke(Color.teal.opacity(0.2), lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            if let icon = model.repairFetchedImage {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                                    .cornerRadius(8)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.teal)
                                    .symbolEffect(.pulse)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text("Safari Background Repair")
                                .font(.system(.title2, design: .rounded).bold())
                            
                            Text("Refreshing icon cache...")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 12) {
                            ProgressView(value: model.repairProgress)
                                .progressViewStyle(.linear)
                                .tint(.teal)
                                .frame(width: 320)
                            
                            HStack {
                                Text("\(model.repairProcessedCount) / \(model.repairTotalCount)")
                                    .font(.system(.caption, design: .monospaced).bold())
                                Spacer()
                                Text("\(Int(model.repairProgress * 100))%")
                                    .font(.system(.caption, design: .monospaced).bold())
                            }
                            .frame(width: 320)
                        }
                        
                        // Live Data & Manual Repair Form
                        VStack(spacing: 0) {
                            // Current Status Info
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Current:")
                                        .font(.system(.caption2, design: .rounded).bold())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(model.repairStatuses[model.currentRepairURL] ?? "Refreshing...")
                                        .font(.system(.caption2, design: .rounded).bold())
                                        .foregroundStyle(model.repairStatuses[model.currentRepairURL] == "Recovered!" || model.repairStatuses[model.currentRepairURL] == "Found (Manual)" ? .green : .secondary)
                                }
                                
                                Text(model.currentRepairTitle)
                                    .font(.system(.body, design: .rounded).bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Text(model.currentRepairURL)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.teal)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding()
                            
                            if model.isWaitingForManualFix, let bookmark = model.currentFailedBookmark {
                                Divider()
                                InlineManualFixForm(model: model, bookmark: bookmark)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else {
                                Button(action: { model.skipCurrentRepair() }) {
                                    HStack {
                                        Text("Skip Current Bookmark")
                                        Image(systemName: "forward.end.fill")
                                    }
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.primary.opacity(0.05))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: 320)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 20)
            .animation(.spring(), value: model.showRepairSummary)
            .animation(.spring(), value: model.isWaitingForManualFix)
        }
    }
}

struct InlineManualFixForm: View {
    @ObservedObject var model: BookmarkModel
    let bookmark: NodeInfo
    
    @State private var editedURL: String = ""
    @State private var validationStatus: String? = nil
    @State private var isValidating = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Manual Fix Required")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(.orange)
                
                TextField("URL", text: $editedURL)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(8)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: editedURL) { _ in
                        validationStatus = nil
                    }
                
                if let status = validationStatus {
                    HStack {
                        Image(systemName: status == "200 OK" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        Text(status)
                    }
                    .font(.system(.caption2, design: .rounded).bold())
                    .foregroundStyle(status == "200 OK" ? .green : .red)
                }
            }
            
            HStack(spacing: 8) {
                Button(action: { model.searchWeb(for: bookmark) }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(.caption, design: .rounded).bold())
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                
                Button(action: {
                    isValidating = true
                    model.validateURL(editedURL) { status in
                        validationStatus = status
                        isValidating = false
                        if status == "200 OK" && editedURL != bookmark.url {
                            model.updateURL(withID: bookmark.id, newURL: editedURL)
                        }
                    }
                }) {
                    Text(isValidating ? "..." : "Verify")
                        .font(.system(.caption, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isValidating)
                
                Button(action: {
                    model.deleteNode(withID: bookmark.id)
                    model.resolveManualRepairFix(didDelete: true)
                }) {
                    Text("Delete")
                        .font(.system(.caption, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                
                Button(action: {
                    model.resolveManualRepairFix()
                }) {
                    Text("Skip")
                        .font(.system(.caption, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            if validationStatus == "200 OK" {
                Button(action: {
                    model.resolveManualRepairFix()
                }) {
                    Text("Continue with New URL")
                        .font(.system(.caption, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .onAppear {
            editedURL = bookmark.url
        }
    }
}

struct IconCheckOptionsOverlay: View {
    @ObservedObject var model: BookmarkModel
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    var onClose: () -> Void
    var onStart: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            
            VStack(spacing: 0) {
                HStack {
                    Text("Configure Icon Check")
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.primary.opacity(0.05))
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Exclude Folders", systemImage: "folder.badge.minus")
                            .font(.system(.subheadline, design: .rounded).bold())
                        
                        Text("Select folders that should be ignored during the icon scan.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(model.allFolderNames, id: \.self) { folder in
                                    Button(action: {
                                        if model.excludedFolders.contains(folder) {
                                            model.excludedFolders.remove(folder)
                                        } else {
                                            model.excludedFolders.insert(folder)
                                        }
                                    }) {
                                        HStack {
                                            Text(folder)
                                                .font(.system(.body, design: .rounded))
                                            Spacer()
                                            if model.excludedFolders.contains(folder) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(themeColor.color ?? .teal)
                                            } else {
                                                Circle()
                                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                                    .frame(width: 18, height: 18)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .contentShape(Rectangle())
                                        .background(model.excludedFolders.contains(folder) ? (themeColor.color ?? .teal).opacity(0.1) : Color.black.opacity(0.001))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                        }
                        .frame(height: 250)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(12)
                    }
                    
                    LiquidButton(title: "Start Scan", color: themeColor.color) {
                        onStart()
                    }
                }
                .padding(24)
            }
            .frame(width: 400)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 20)
        }
    }
}
