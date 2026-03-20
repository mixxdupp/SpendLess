import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    
    // Animation State
    @State private var appearStage = false
    @State private var appearLogo = false
    @State private var appearForm = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email
        case password
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. The Emerald Stage (Volumetric Depth)
                ZStack {
                    Color.black
                    
                    // The Spotlight
                    RadialGradient(
                        colors: [Color.emerald0.opacity(0.15), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 700
                    )
                    .opacity(appearStage ? 1 : 0)
                    .animation(.easeOut(duration: 1.5), value: appearStage)
                }
                .ignoresSafeArea()
                .onTapGesture {
                    focusedField = nil
                }
                
                // 2. Main Content
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Prismatic Cart Header
                    VStack(spacing: 24) {
                        // The Neon Cart
                        PrismaticCartLogo()
                            .scaleEffect(appearLogo ? 1 : 0.8)
                            .opacity(appearLogo ? 1 : 0)
                            .offset(y: appearLogo ? 0 : -20)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: appearLogo)
                        
                        VStack(spacing: 8) {
                            Text("SpendLess")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .tracking(0.5)
                            
                            Text(isSignUp ? "Shop smarter. Save more." : "Welcome back.")
                                .font(.subheadline)
                                .foregroundStyle(Color(white: 0.5))
                        }
                        .offset(y: appearLogo ? 0 : 20)
                        .opacity(appearLogo ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: appearLogo)
                    }
                    .padding(.bottom, 48)
                    
                    // Input Block (Matte Gray)
                    VStack(spacing: 16) {
                        // Email
                        MinimalInput(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email,
                            isFocused: focusedField == .email
                        )
                        .focused($focusedField, equals: .email)
                        
                        // Password
                        MinimalSecureInput(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $password,
                            showPassword: $showPassword,
                            isFocused: focusedField == .password
                        )
                        .focused($focusedField, equals: .password)
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.red.opacity(0.9))
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Mode Switcher
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Member?" : "New here?")
                                    .foregroundStyle(Color(white: 0.4))
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            .font(.system(size: 14))
                        }
                        .padding(.top, 12)
                        .offset(y: appearForm ? 0 : 20)
                        .opacity(appearForm ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appearForm)
                    }
                    .padding(.horizontal, 24)
                    .offset(y: appearForm ? 0 : 50)
                    .opacity(appearForm ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: appearForm)
                    
                    Spacer()
                    
                    // Bottom Action (Mechanical)
                    VStack(spacing: 24) {
                        Button {
                            Task { await authenticate() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white)
                                
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    HStack {
                                        Text(isSignUp ? "Create Account" : "Sign In")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(.black)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(.black)
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            .frame(height: 56)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .buttonStyle(MechanicalButtonStyle())
                        
                        Button {
                            Task {
                                focusedField = nil
                                await authService.enableDemoMode()
                            }
                        } label: {
                            Text("Try Demo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(white: 0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .offset(y: appearForm ? 0 : 30)
                    .opacity(appearForm ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: appearForm)
                }
            }
            .onAppear {
                // Orchestral Opening Sequence
                Task {
                    // 1. Lights (The Stage)
                    withAnimation {
                        appearStage = true
                    }
                    
                    try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
                    
                    // 2. Camera (The Logo)
                    withAnimation {
                        appearLogo = true
                    }
                    
                    try? await Task.sleep(nanoseconds: 300_000_000) // +0.3s
                    
                    // 3. Action (The Inputs)
                    withAnimation {
                        appearForm = true
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func authenticate() async {
        HapticManager.shared.softImpact()
        isLoading = true
        errorMessage = nil
        focusedField = nil
        try? await Task.sleep(nanoseconds: 300_000_000)
        defer { isLoading = false }
        
        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
            HapticManager.shared.notification(type: .success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
    }
}

// MARK: - The Neon Cart

struct PrismaticCartLogo: View {
    @State private var rotate = false
    
    var body: some View {
        ZStack {
            // 1. Center Glow (Emerald)
            Circle()
                .fill(Color.emerald0.opacity(0.2)) // Slightly dimmer for "Dark Mode" feel
                .frame(width: 120, height: 120)
                .blur(radius: 40)
            
            // 2. Prismatic Cart Construction
            ZStack {
                // Background Layer (Depth)
                Image(systemName: "cart.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.emerald3)
                    .offset(x: 4, y: 4)
                    .blur(radius: 2)
                
                // Middle Layer (Body)
                Image(systemName: "cart.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.emerald2, .emerald1],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                
                // Top Layer (Highlights/Neon)
                Image(systemName: "cart")
                    .font(.system(size: 54, weight: .bold)) // Outline for neon effect
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.5), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(x: -2, y: -2)
                    .shadow(color: .emerald0.opacity(0.8), radius: 8, y: 0) // Neon Glow
            }
            // 3. Levitation Physics
            .rotation3DEffect(.degrees(rotate ? 10 : -10), axis: (x: 0, y: 1, z: 0)) // Y-axis rotation
            .offset(y: rotate ? -8 : 8) // Floating up/down
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: rotate)
        }
        .onAppear {
            rotate = true
        }
    }
}

// MARK: - Minimalist Components (Persisted)

struct MinimalInput: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isFocused ? .white : Color(white: 0.5))
                .frame(width: 20)
            
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color(white: 0.3)))
                .foregroundStyle(.white)
                .font(.system(size: 17))
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding()
        .frame(height: 56)
        .background(Color(white: 0.11)) // #1C1C1E
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.emerald1 : Color.white.opacity(0.05), lineWidth: isFocused ? 1 : 1)
        )
        .animation(.easeOut(duration: 0.1), value: isFocused)
    }
}

struct MinimalSecureInput: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isFocused ? .white : Color(white: 0.5))
                .frame(width: 20)
            
            if showPassword {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color(white: 0.3)))
                    .foregroundStyle(.white)
                    .font(.system(size: 17))
            } else {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Color(white: 0.3)))
                    .foregroundStyle(.white)
                    .font(.system(size: 17))
            }
            
            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.4))
            }
        }
        .padding()
        .frame(height: 56)
        .background(Color(white: 0.11)) // #1C1C1E
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.emerald1 : Color.white.opacity(0.05), lineWidth: isFocused ? 1 : 1)
        )
        .animation(.easeOut(duration: 0.1), value: isFocused)
    }
}

struct MechanicalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Jewel Colors
fileprivate extension Color {
    static let emerald0 = Color(red: 0.2, green: 0.9, blue: 0.5) // Lightest
    static let emerald1 = Color(red: 0.0, green: 0.7, blue: 0.4)
    static let emerald2 = Color(red: 0.0, green: 0.5, blue: 0.3) // Base
    static let emerald3 = Color(red: 0.0, green: 0.3, blue: 0.2) // Shadow
}

#Preview {
    AuthView()
        .environmentObject(AuthService.shared)
}
