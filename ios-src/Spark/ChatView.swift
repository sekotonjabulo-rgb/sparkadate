import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable {
    let id: String
    let content: String
    let senderId: String
    let sentAt: Date
    var editedAt: Date?
    var replyToId: String?

    var isSent: Bool {
        let userId = UserDefaults.standard.data(forKey: "sparkUser")
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            .flatMap { $0["id"] as? String } ?? ""
        return senderId == userId
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.editedAt == rhs.editedAt
    }
}

// MARK: - Chat View Model
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var partnerName: String = ""
    @Published var partnerStatus: String = "Offline"
    @Published var isPartnerTyping = false
    @Published var isLoading = true
    @Published var revealBadge = false
    @Published var revealStatus: String = "can-request"

    private let api = SparkAPIService.shared
    var matchId: String = ""
    private var messagePollTimer: Timer?
    private var statusPollTimer: Timer?
    private var typingPollTimer: Timer?
    private var heartbeatTimer: Timer?
    private var displayedIds = Set<String>()

    func loadInitialData(matchData: [String: Any]?) {
        if let match = matchData {
            matchId = match["id"] as? String ?? ""
            partnerName = match["name"] as? String ?? "Unknown"
        }
        loadMessages()
        updatePartnerStatus()
        sendHeartbeat()
        startPolling()
    }

    func loadMessages() {
        Task {
            do {
                let result = try await api.apiRequest("/messages/\(matchId)")
                await MainActor.run {
                    if let msgs = result["messages"] as? [[String: Any]] {
                        let userId = self.getCurrentUserId()
                        var newMessages: [ChatMessage] = []
                        for msg in msgs {
                            let id = msg["id"] as? String ?? UUID().uuidString
                            if !self.displayedIds.contains(id) {
                                self.displayedIds.insert(id)
                                let sentAt = Self.parseDate(msg["sent_at"] as? String)
                                let editedAt = Self.parseDate(msg["edited_at"] as? String)
                                newMessages.append(ChatMessage(
                                    id: id,
                                    content: msg["content"] as? String ?? "",
                                    senderId: msg["sender_id"] as? String ?? "",
                                    sentAt: sentAt,
                                    editedAt: editedAt,
                                    replyToId: msg["reply_to_id"] as? String
                                ))
                            }
                        }
                        self.messages.append(contentsOf: newMessages)
                        self.messages.sort { $0.sentAt < $1.sentAt }
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    static func parseDate(_ string: String?) -> Date {
        guard let string = string else { return Date() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? Date()
    }

    func sendMessage(_ content: String, replyToId: String? = nil) {
        let tempId = "temp-\(Date().timeIntervalSince1970)"
        let tempMsg = ChatMessage(
            id: tempId,
            content: content,
            senderId: getCurrentUserId(),
            sentAt: Date(),
            replyToId: replyToId
        )
        messages.append(tempMsg)
        displayedIds.insert(tempId)

        Task {
            do {
                var body: [String: Any] = ["content": content]
                if let replyId = replyToId { body["reply_to_id"] = replyId }
                let result = try await api.apiRequest("/messages/\(matchId)", method: "POST", body: body)
                await MainActor.run {
                    if let msg = result["message"] as? [String: Any],
                       let newId = msg["id"] as? String {
                        self.displayedIds.remove(tempId)
                        self.displayedIds.insert(newId)
                        if let idx = self.messages.firstIndex(where: { $0.id == tempId }) {
                            self.messages[idx] = ChatMessage(
                                id: newId,
                                content: content,
                                senderId: self.getCurrentUserId(),
                                sentAt: Date(),
                                replyToId: replyToId
                            )
                        }
                    }
                }
                try? await api.apiRequest("/typing/\(matchId)", method: "POST", body: ["is_typing": false])
            } catch {
                print("Send message error: \(error)")
            }
        }
    }

    func editMessage(id: String, content: String) {
        Task {
            do {
                let _ = try await api.apiRequest("/messages/\(matchId)/\(id)", method: "PUT", body: ["content": content])
                await MainActor.run {
                    if let idx = self.messages.firstIndex(where: { $0.id == id }) {
                        var updated = ChatMessage(
                            id: id,
                            content: content,
                            senderId: self.messages[idx].senderId,
                            sentAt: self.messages[idx].sentAt,
                            editedAt: Date(),
                            replyToId: self.messages[idx].replyToId
                        )
                        self.messages[idx] = updated
                    }
                }
            } catch {
                print("Edit message error: \(error)")
            }
        }
    }

    func deleteMessage(id: String) {
        Task {
            do {
                let _ = try await api.apiRequest("/messages/\(matchId)/\(id)", method: "DELETE")
                await MainActor.run {
                    self.messages.removeAll { $0.id == id }
                    self.displayedIds.remove(id)
                }
            } catch {
                print("Delete message error: \(error)")
            }
        }
    }

    func setTyping(_ typing: Bool) {
        Task {
            try? await api.apiRequest("/typing/\(matchId)", method: "POST", body: ["is_typing": typing])
        }
    }

    func updatePartnerStatus() {
        Task {
            do {
                let result = try await api.apiRequest("/presence/match/\(matchId)")
                await MainActor.run {
                    let isOnline = result["isOnline"] as? Bool ?? false
                    if isOnline {
                        self.partnerStatus = "Online"
                    } else if let lastSeen = result["lastSeen"] as? String {
                        self.partnerStatus = "Last seen \(Self.formatLastSeen(lastSeen))"
                    } else {
                        self.partnerStatus = "Offline"
                    }
                }
            } catch {}
        }
    }

    static func formatLastSeen(_ dateStr: String) -> String {
        let date = parseDate(dateStr)
        let diff = Date().timeIntervalSince(date)
        let mins = Int(diff / 60)
        let hours = Int(diff / 3600)
        let days = Int(diff / 86400)

        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    func sendHeartbeat() {
        Task { try? await api.apiRequest("/presence/heartbeat", method: "POST") }
    }

    func checkRevealRequest() {
        Task {
            do {
                let result = try await api.apiRequest("/matches/current")
                await MainActor.run {
                    if let match = result["match"] as? [String: Any] {
                        let partnerLeft = match["partner_left"] as? Bool ?? false
                        if partnerLeft {
                            // Will be handled by navigation
                            return
                        }
                        let status = match["status"] as? String ?? ""
                        let userId = self.getCurrentUserId()
                        let seenBy = match["revealed_seen_by"] as? [String] ?? []

                        if status == "revealed" && !seenBy.contains(userId) {
                            self.revealStatus = "revealed-unseen"
                        } else if status == "revealed" {
                            self.revealStatus = "already-revealed"
                            self.revealBadge = false
                        } else if let requestedBy = match["reveal_requested_by"] as? String,
                                  requestedBy != userId {
                            self.revealBadge = true
                            self.revealStatus = "pending-request"
                        } else {
                            self.revealBadge = false
                            self.revealStatus = "can-request"
                        }
                    }
                }
            } catch {}
        }
    }

    func startPolling() {
        messagePollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollNewMessages()
        }
        statusPollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updatePartnerStatus()
            self?.sendHeartbeat()
        }
        typingPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPartnerTyping()
        }
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkRevealRequest()
        }
    }

    private func pollNewMessages() {
        Task {
            do {
                let result = try await api.apiRequest("/messages/\(matchId)")
                await MainActor.run {
                    if let msgs = result["messages"] as? [[String: Any]] {
                        var hasNew = false
                        for msg in msgs {
                            let id = msg["id"] as? String ?? ""
                            if !self.displayedIds.contains(id) {
                                self.displayedIds.insert(id)
                                let sentAt = Self.parseDate(msg["sent_at"] as? String)
                                let editedAt = Self.parseDate(msg["edited_at"] as? String)
                                self.messages.append(ChatMessage(
                                    id: id,
                                    content: msg["content"] as? String ?? "",
                                    senderId: msg["sender_id"] as? String ?? "",
                                    sentAt: sentAt,
                                    editedAt: editedAt,
                                    replyToId: msg["reply_to_id"] as? String
                                ))
                                hasNew = true
                            }
                        }
                        if hasNew {
                            self.messages.sort { $0.sentAt < $1.sentAt }
                        }
                    }
                }
            } catch {}
        }
    }

    private func checkPartnerTyping() {
        Task {
            do {
                let result = try await api.apiRequest("/typing/\(matchId)")
                await MainActor.run {
                    self.isPartnerTyping = result["isTyping"] as? Bool ?? false
                }
            } catch {}
        }
    }

    func cleanup() {
        messagePollTimer?.invalidate()
        statusPollTimer?.invalidate()
        typingPollTimer?.invalidate()
        heartbeatTimer?.invalidate()
    }

    func getCurrentUserId() -> String {
        if let userData = UserDefaults.standard.data(forKey: "sparkUser"),
           let user = try? JSONSerialization.jsonObject(with: userData) as? [String: Any],
           let id = user["id"] as? String {
            return id
        }
        return ""
    }
}

// MARK: - Chat View
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var replyToMessage: ChatMessage? = nil
    @State private var editingMessage: ChatMessage? = nil
    @State private var showMenu = false
    @State private var selectedMessage: ChatMessage? = nil
    @State private var typingTimeout: DispatchWorkItem? = nil
    @FocusState private var isInputFocused: Bool

    var matchData: [String: Any]?
    var onNavigateToTimer: (() -> Void)?
    var onNavigateToReveal: (() -> Void)?
    var onNavigateToRevealRequest: (() -> Void)?
    var onNavigateToSettings: (() -> Void)?
    var onNavigateToPlan: (() -> Void)?
    var onNavigateToRevealed: (() -> Void)?
    var onNavigateToLeft: (() -> Void)?
    var onLogout: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                chatHeader

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(groupedMessages, id: \.0) { dateKey, msgs in
                                dateSeparator(dateKey)
                                ForEach(msgs) { msg in
                                    MessageBubbleView(
                                        message: msg,
                                        replyMessage: msg.replyToId.flatMap { id in viewModel.messages.first(where: { $0.id == id }) },
                                        onReply: { startReply(msg) },
                                        onEdit: { startEdit(msg) },
                                        onDelete: { viewModel.deleteMessage(id: msg.id) }
                                    )
                                    .id(msg.id)
                                }
                            }

                            if viewModel.isPartnerTyping {
                                typingIndicator
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Reply/Edit bar
                if replyToMessage != nil {
                    replyBar
                }
                if editingMessage != nil {
                    editBar
                }

                // Input
                chatInputBar
            }
            .frame(maxWidth: .infinity)

            // Menu overlay
            if showMenu {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture { showMenu = false }
            }
        }
        .onAppear {
            viewModel.loadInitialData(matchData: matchData)
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.revealStatus) { status in
            if status == "revealed-unseen" {
                onNavigateToRevealed?()
            }
        }
    }

    // MARK: - Grouped Messages
    private var groupedMessages: [(String, [ChatMessage])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var groups: [(String, [ChatMessage])] = []
        var currentKey = ""
        var currentGroup: [ChatMessage] = []

        for msg in viewModel.messages {
            let key = formatter.string(from: msg.sentAt)
            if key != currentKey {
                if !currentGroup.isEmpty {
                    groups.append((currentKey, currentGroup))
                }
                currentKey = key
                currentGroup = [msg]
            } else {
                currentGroup.append(msg)
            }
        }
        if !currentGroup.isEmpty {
            groups.append((currentKey, currentGroup))
        }
        return groups
    }

    // MARK: - Header
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.partnerName)
                    .font(.customFont("CabinetGrotesk-Medium", size: 16))
                    .foregroundColor(.white)
                Text(viewModel.partnerStatus)
                    .font(.customFont("CabinetGrotesk-Medium", size: 12))
                    .foregroundColor(Color.white.opacity(0.65))
            }

            Spacer()

            HStack(spacing: 6) {
                // Timer button
                Button(action: { onNavigateToTimer?() }) {
                    headerIconButton(systemName: "clock")
                }

                // Reveal button
                Button(action: { handleRevealTap() }) {
                    ZStack(alignment: .topTrailing) {
                        headerIconButton(systemName: "eye")
                        if viewModel.revealBadge {
                            Circle()
                                .fill(Color(red: 1, green: 0.23, blue: 0.19))
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Text("1")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 4, y: -4)
                        }
                    }
                }

                // Menu button
                Menu {
                    Button(action: { onNavigateToSettings?() }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                    Button(action: { onNavigateToPlan?() }) {
                        Label("Upgrade to Pro", systemImage: "star")
                    }
                    Divider()
                    Button(role: .destructive, action: { onLogout?() }) {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    headerIconButton(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    private func headerIconButton(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .overlay(
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private func handleRevealTap() {
        switch viewModel.revealStatus {
        case "pending-request":
            onNavigateToRevealRequest?()
        case "can-request":
            onNavigateToReveal?()
        default:
            break
        }
    }

    // MARK: - Date Separator
    private func dateSeparator(_ dateKey: String) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: dateKey) ?? Date()
        let displayText = formatDateSeparator(date)

        return HStack {
            Spacer()
            Text(displayText)
                .font(.customFont("CabinetGrotesk-Medium", size: 11))
                .foregroundColor(Color.white.opacity(0.65))
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func formatDateSeparator(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Typing Indicator
    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    TypingDot(delay: Double(index) * 0.2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.18))
            .cornerRadius(20)
            Spacer()
        }
    }

    // MARK: - Reply Bar
    private var replyBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to")
                    .font(.customFont("CabinetGrotesk-Medium", size: 11))
                    .foregroundColor(Color.white.opacity(0.65))
                Text(replyToMessage?.content.prefix(100) ?? "")
                    .font(.customFont("CabinetGrotesk-Medium", size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { replyToMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Edit Bar
    private var editBar: some View {
        HStack {
            Text("Editing message")
                .font(.customFont("CabinetGrotesk-Medium", size: 13))
                .foregroundColor(Color.white.opacity(0.65))
            Spacer()
            Button(action: { cancelEdit() }) {
                Text("Cancel")
                    .font(.customFont("CabinetGrotesk-Medium", size: 12))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
    }

    // MARK: - Input Bar
    private var chatInputBar: some View {
        HStack(spacing: 8) {
            TextField("", text: $messageText)
                .placeholder(when: messageText.isEmpty) {
                    Text("Type a message...").foregroundColor(Color.white.opacity(0.65))
                }
                .font(.customFont("CabinetGrotesk-Medium", size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.trailing, 44)
                .frame(height: 46)
                .background(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .cornerRadius(24)
                .focused($isInputFocused)
                .onChange(of: messageText) { _ in handleTypingInput() }
                .onSubmit { handleSend() }
                .overlay(alignment: .trailing) {
                    if !messageText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: { handleSend() }) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 5)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: messageText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    // MARK: - Actions
    private func startReply(_ msg: ChatMessage) {
        cancelEdit()
        replyToMessage = msg
        isInputFocused = true
    }

    private func startEdit(_ msg: ChatMessage) {
        replyToMessage = nil
        editingMessage = msg
        messageText = msg.content
        isInputFocused = true
    }

    private func cancelEdit() {
        editingMessage = nil
        messageText = ""
    }

    private func handleSend() {
        let content = messageText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        if let editing = editingMessage {
            viewModel.editMessage(id: editing.id, content: content)
            cancelEdit()
        } else {
            viewModel.sendMessage(content, replyToId: replyToMessage?.id)
            replyToMessage = nil
            messageText = ""
        }
    }

    private func handleTypingInput() {
        viewModel.setTyping(true)
        typingTimeout?.cancel()
        let item = DispatchWorkItem { [self] in
            viewModel.setTyping(false)
        }
        typingTimeout = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    let replyMessage: ChatMessage?
    var onReply: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showActions = false

    var body: some View {
        VStack(alignment: message.isSent ? .trailing : .leading, spacing: 4) {
            // Reply preview
            if let reply = replyMessage {
                Text(String(reply.content.prefix(50)))
                    .font(.customFont("CabinetGrotesk-Medium", size: 12))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 2)
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
            }

            // Message bubble with context menu
            HStack(spacing: 6) {
                if message.isSent { Spacer(minLength: 60) }

                Text(message.content)
                    .font(.customFont("CabinetGrotesk-Medium", size: 15))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isSent
                        ? Color.white.opacity(0.12)
                        : Color.white.opacity(0.18))
                    .cornerRadius(18)
                    .contextMenu {
                        Button(action: onReply) {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                        }
                        if message.isSent {
                            Button(action: onEdit) {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: onDelete) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                if !message.isSent { Spacer(minLength: 60) }
            }

            // Time + edited label
            HStack(spacing: 4) {
                Text(formatTime(message.sentAt))
                    .font(.customFont("CabinetGrotesk-Medium", size: 10))
                    .foregroundColor(Color.white.opacity(0.45))
                if message.editedAt != nil {
                    Text("(edited)")
                        .font(.customFont("CabinetGrotesk-Medium", size: 10))
                        .foregroundColor(Color.white.opacity(0.35))
                        .italic()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isSent ? .trailing : .leading)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Typing Dot Animation
struct TypingDot: View {
    let delay: Double
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.65))
            .frame(width: 6, height: 6)
            .offset(y: animating ? -4 : 0)
            .opacity(animating ? 1 : 0.4)
            .animation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: animating
            )
            .onAppear { animating = true }
    }
}
