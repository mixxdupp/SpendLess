import SwiftUI

struct RationalityChatView: View {
    let productTitle: String
    let productPrice: Double
    let productImageUrl: String?
    let daysToEarn: Double?
    let percentOfIncome: Double?
    let currency: String
    @Environment(\.dismiss) var dismiss
    
    @State private var messages: [RationalityService.ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isInitialLoad: Bool = true
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            // OLED Black Background with Red Glow
            Color.black.ignoresSafeArea()
            
            RadialGradient(
                colors: [DesignSystem.Colors.profit.opacity(0.15), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(white: 0.3)) // Subtle dismiss
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("The Rationalist")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("Your Anti-Salesman AI")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.clear)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Chat Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Header Info Card
                            productHeader
                                .padding(.bottom, 20)
                            
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if isLoading {
                                TypingIndicator()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading)
                                    .id("typing")
                            }
                            
                            // Spacer for keyboard
                            Color.clear.frame(height: 10)
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { 
                        withAnimation {
                            if let lastId = messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isLoading) { 
                        if isLoading {
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Area
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        TextField("Reply...", text: $inputText, axis: .vertical)
                            .padding(12)
                            .background(Color(white: 0.1))
                            .cornerRadius(20)
                            .foregroundStyle(.white)
                            .focused($isInputFocused)
                            .submitLabel(.send)
                            .onSubmit {
                                sendMessage()
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(inputText.isEmpty ? Color.white.opacity(0.3) : .red)
                        }
                        .disabled(inputText.isEmpty || isLoading)
                    }
                    .padding()
                }
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            if isInitialLoad {
                startConsultation()
                isInitialLoad = false
            }
        }
    }
    
    private var productHeader: some View {
        HStack(spacing: 12) {
            if let imageUrl = productImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "cart.fill")
                    .frame(width: 50, height: 50)
                    .background(Color(white: 0.1))
                    .foregroundStyle(.white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(productTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Text("\(currency)\(String(format: "%.2f", productPrice))")
                    .font(.headline)
                    .foregroundStyle(.red) // Red Price
                + Text(" • \(String(format: "%.1f", daysToEarn ?? 0)) Days")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(white: 0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.profit.opacity(0.3), lineWidth: 1) // Subtle Green Border
        )
    }
    
    func startConsultation() {
        isLoading = true
        Task {
            let response = await RationalityService.shared.consult(
                title: productTitle,
                price: productPrice,
                imageUrl: productImageUrl,
                daysToEarn: daysToEarn,
                percentOfIncome: percentOfIncome,
                currency: currency,
                messages: []
            )
            
            await MainActor.run {
                withAnimation(.spring()) {
                    messages.append(.init(role: "model", text: response))
                    isLoading = false
                    HapticManager.shared.notification(type: .success)
                }
            }
        }
    }
    
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMsg = RationalityService.ChatMessage(role: "user", text: text)
        withAnimation {
            messages.append(userMsg)
            inputText = ""
            isLoading = true
        }
        HapticManager.shared.impact(style: .light)
        
        // Call API
        Task {
            let response = await RationalityService.shared.consult(
                title: productTitle,
                price: productPrice,
                imageUrl: productImageUrl,
                daysToEarn: daysToEarn,
                percentOfIncome: percentOfIncome,
                currency: currency,
                messages: messages // Send full history including just added user msg
            )
            
            await MainActor.run {
                withAnimation(.spring()) {
                    messages.append(.init(role: "model", text: response))
                    isLoading = false
                    HapticManager.shared.notification(type: .success)
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: RationalityService.ChatMessage
    
    var isUser: Bool { message.role == "user" }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer()
            }
            
            // Avatar for AI
            if !isUser {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle().stroke(Color.black, lineWidth: 2)
                    )
            }
            
            Text(message.text)
                .font(.body)
                .padding(14)
                .foregroundStyle(.white)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                // Add subtle red glow to AI messages? or Border?
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isUser ? Color.clear : DesignSystem.Colors.profit.opacity(0.3), lineWidth: isUser ? 0 : 1)
                )
            
            if isUser {
                // User bubble
            } else {
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    var bubbleBackground: some View {
        if isUser {
            // User Green/Neutral
            Color(white: 0.2)
        } else {
            // AI Black with Red Tint
            Color(red: 0.1, green: 0.02, blue: 0.02)
        }
    }
}

struct TypingIndicator: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(DesignSystem.Colors.profit.opacity(0.7)) // Green Dots
                    .frame(width: 6, height: 6)
                    .offset(y: offset)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: offset
                    )
            }
        }
        .padding(12)
        .background(Color(red: 0.1, green: 0.02, blue: 0.02)) // Red Tint Background
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(DesignSystem.Colors.profit.opacity(0.3), lineWidth: 1)
        )
        .onAppear { offset = -5 }
    }
}
