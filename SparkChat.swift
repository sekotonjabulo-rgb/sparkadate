import SwiftUI
import PlaygroundSupport

// MARK: - Color Theme
extension Color {
    static let sparkBackground = Color(red: 0, green: 0, blue: 0)
    static let sparkSurface = Color.white
    static let sparkTextPrimary = Color.white
    static let sparkTextSecondary = Color.white.opacity(0.65)
    static let sparkInputBg = Color.white.opacity(0.08)
    static let sparkInputBorder = Color.white.opacity(0.12)
    static let sparkBubbleSent = Color.white.opacity(0.12)
    static let sparkBubbleReceived = Color.white.opacity(0.18)
    static let sparkNotification = Color(red: 1, green: 0.231, blue: 0.188)
}

// MARK: - Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isSent: Bool
    let timestamp: Date
    var isEdited: Bool = false
    var replyTo: String? = nil
}

// MARK: - Chat View Model
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var messageText = ""
    @Published var isPartnerTyping = false
    @Published var partnerName = "Alex"
    @Published var partnerStatus = "Online"
    @Published var showRevealNotification = true
    @Published var replyingTo: ChatMessage? = nil
    @Published var editingMessage: ChatMessage? = nil
    @Published var showMenu = false

    init() {
        // Sample messages for demo
        messages = [
            ChatMessage(content: "Hey! How are you doing today?", isSent: false, timestamp: Date().addingTimeInterval(-3600)),
            ChatMessage(content: "I'm doing great, thanks for asking! Just finished work.", isSent: true, timestamp: Date().addingTimeInterval(-3500)),
            ChatMessage(content: "That's awesome! Any plans for the weekend?", isSent: false, timestamp: Date().addingTimeInterval(-3400)),
            ChatMessage(content: "Thinking about going hiking. Want to join?", isSent: true, timestamp: Date().addingTimeInterval(-3300)),
            ChatMessage(content: "That sounds like so much fun! I'd love to!", isSent: false, timestamp: Date().addingTimeInterval(-3200)),
        ]
    }

    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let newMessage = ChatMessage(
            content: messageText,
            isSent: true,
            timestamp: Date(),
            replyTo: replyingTo?.content
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(newMessage)
        }

        messageText = ""
        replyingTo = nil

        // Simulate partner typing and response
        simulatePartnerResponse()
    }

    func simulatePartnerResponse() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                self.isPartnerTyping = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.isPartnerTyping = false
                let responses = [
                    "That's interesting! Tell me more.",
                    "I totally agree with you!",
                    "Sounds great! 😊",
                    "What do you think about tomorrow?",
                    "I was just thinking the same thing!"
                ]
                let response = ChatMessage(
                    content: responses.randomElement() ?? "Nice!",
                    isSent: false,
                    timestamp: Date()
                )
                self.messages.append(response)
            }
        }
    }

    func startReply(to message: ChatMessage) {
        replyingTo = message
        editingMessage = nil
    }

    func cancelReply() {
        replyingTo = nil
    }
}

// MARK: - Header View
struct ChatHeaderView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var showDropdown = false

    var body: some View {
        HStack {
            // User info
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.partnerName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.sparkTextPrimary)

                Text(viewModel.partnerStatus)
                    .font(.system(size: 12))
                    .foregroundColor(.sparkTextSecondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 6) {
                // Timer button
                HeaderIconButton(systemName: "clock") {
                    print("Timer tapped")
                }

                // Reveal button with notification
                ZStack(alignment: .topTrailing) {
                    HeaderIconButton(systemName: "eye") {
                        print("Reveal tapped")
                    }

                    if viewModel.showRevealNotification {
                        Text("1")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.sparkNotification)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }

                // Menu button
                HeaderIconButton(systemName: "ellipsis") {
                    withAnimation {
                        showDropdown.toggle()
                    }
                }
                .overlay(
                    Group {
                        if showDropdown {
                            MenuDropdownView(showDropdown: $showDropdown)
                                .offset(y: 45)
                        }
                    },
                    alignment: .topTrailing
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
        )
    }
}

struct HeaderIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundColor(.sparkTextPrimary)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.sparkInputBorder, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MenuDropdownView: View {
    @Binding var showDropdown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuDropdownItem(icon: "gearshape", title: "Settings") {
                showDropdown = false
            }

            MenuDropdownItem(icon: "star", title: "Upgrade to Pro") {
                showDropdown = false
            }

            MenuDropdownItem(icon: "questionmark.circle", title: "Help & Support") {
                showDropdown = false
            }

            Divider()
                .background(Color.sparkInputBorder)
                .padding(.vertical, 4)

            MenuDropdownItem(icon: "rectangle.portrait.and.arrow.right", title: "Log out", isDestructive: true) {
                showDropdown = false
            }
        }
        .padding(4)
        .frame(width: 180)
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 16)
    }
}

struct MenuDropdownItem: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14))
                Spacer()
            }
            .foregroundColor(isDestructive ? .red : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    let onReply: () -> Void
    @State private var showActions = false

    var body: some View {
        VStack(alignment: message.isSent ? .trailing : .leading, spacing: 4) {
            // Reply preview if exists
            if let replyTo = message.replyTo {
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2)

                    Text(replyTo)
                        .font(.system(size: 12))
                        .foregroundColor(.sparkTextSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(4)
            }

            // Message row with action button
            HStack(spacing: 6) {
                if message.isSent {
                    Spacer()

                    if showActions {
                        MessageActionButton {
                            onReply()
                        }
                    }
                }

                // Message bubble
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.sparkTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isSent ? Color.sparkBubbleSent : Color.sparkBubbleReceived)
                    .cornerRadius(18)

                if !message.isSent {
                    if showActions {
                        MessageActionButton {
                            onReply()
                        }
                    }

                    Spacer()
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showActions = hovering
                }
            }

            // Timestamp
            HStack(spacing: 4) {
                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.sparkTextSecondary)

                if message.isEdited {
                    Text("(edited)")
                        .font(.system(size: 10))
                        .italic()
                        .foregroundColor(.sparkTextSecondary.opacity(0.7))
                }
            }
            .opacity(showActions ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: message.isSent ? .trailing : .leading)
        .padding(.horizontal, 20)
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "ellipsis")
                .font(.system(size: 14))
                .foregroundColor(.sparkTextSecondary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Typing Indicator View
struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.sparkTextSecondary)
                    .frame(width: 6, height: 6)
                    .offset(y: animationOffset(for: index))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.sparkBubbleReceived)
        .cornerRadius(20)
        .onAppear {
            withAnimation(
                Animation
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
            ) {
                animationOffset = -4
            }
        }
    }

    func animationOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.2
        return animationOffset * (1 - delay)
    }
}

// MARK: - Reply Preview Bar
struct ReplyPreviewBar: View {
    let message: ChatMessage
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to")
                    .font(.system(size: 11))
                    .foregroundColor(.sparkTextSecondary)

                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundColor(.sparkTextPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.sparkTextSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
    }
}

// MARK: - Input Bar View
struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TextField("Type a message...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.sparkTextPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(Color.sparkInputBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.sparkInputBorder, lineWidth: 1)
                )
                .cornerRadius(24)
                .onSubmit {
                    if !text.isEmpty {
                        onSend()
                    }
                }

            // Send button (visible when text is not empty)
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: onSend) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, -42)
                .padding(.trailing, 5)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 26)
        .background(
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text)
    }
}

// MARK: - Date Separator View
struct DateSeparatorView: View {
    let date: Date

    var body: some View {
        Text(formatDate(date))
            .font(.system(size: 11))
            .foregroundColor(.sparkTextSecondary)
            .padding(.vertical, 12)
    }

    func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Scroll to Bottom Button
struct ScrollToBottomButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 40, height: 40)
                .background(Color(white: 0.1))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.6), radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Main Chat View
struct SparkChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showScrollButton = false

    var body: some View {
        ZStack {
            // Background
            Color.sparkBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ChatHeaderView(viewModel: viewModel)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            // Date separator for demo
                            DateSeparatorView(date: Date())

                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message) {
                                    viewModel.startReply(to: message)
                                }
                                .id(message.id)
                            }

                            // Typing indicator
                            if viewModel.isPartnerTyping {
                                HStack {
                                    TypingIndicatorView()
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            if let lastMessage = viewModel.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Reply preview bar
                if let replyingTo = viewModel.replyingTo {
                    ReplyPreviewBar(message: replyingTo) {
                        viewModel.cancelReply()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Input bar
                ChatInputBar(text: $viewModel.messageText) {
                    viewModel.sendMessage()
                }
            }

            // Scroll to bottom button
            if showScrollButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ScrollToBottomButton {
                            // Scroll action would go here
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 400, height: 700)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20)
    }
}

// MARK: - Preview / Playground
struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            SparkChatView()
        }
    }
}

// Set up Playground live view
PlaygroundPage.current.setLiveView(ContentView())
