import SwiftUI
import Supabase

struct SyncExtensionView: View {
    @EnvironmentObject var authService: AuthService
    @State private var syncData: String = ""
    @State private var isCopied = false
    
    var body: some View {
        List {
            Section {
                Text("To sync your account with the Chrome Extension:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("1. Open the Chrome Extension")
                        Spacer()
                        Image(systemName: "puzzlepiece.extension")
                    }
                    
                    HStack {
                        Text("2. Click 'Sync with iOS App'")
                        Spacer()
                        Image(systemName: "cursorarrow.click")
                    }
                    
                    HStack {
                        Text("3. Paste the data below")
                        Spacer()
                        Image(systemName: "doc.on.clipboard")
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("Your Sync Data") {
                if syncData.isEmpty {
                    ProgressView()
                } else {
                    Text(syncData)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(4)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        UIPasteboard.general.string = syncData
                        isCopied = true
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isCopied = false
                        }
                    } label: {
                        Label(isCopied ? "Copied!" : "Copy to Clipboard", systemImage: isCopied ? "checkmark" : "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isCopied ? .green : .accentColor)
                }
            }
        }
        .navigationTitle("Sync Extension")
        .task {
            await generateSyncData()
        }
    }
    
    // Generate the JSON payload for the extension
    private func generateSyncData() async {
        guard let session = try? await SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        ).auth.session else {
            return
        }
        
        // We need to access the session from AuthService, but since it's private,
        // we'll fetch the current session again or rely on what we can get.
        // Ideally AuthService should expose the session or a method to get tokens.
        
        let data: [String: String] = [
            "access_token": session.accessToken,
            "refresh_token": session.refreshToken,
            "user_id": session.user.id.uuidString
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            syncData = jsonString
        }
    }
}

#Preview {
    NavigationView {
        SyncExtensionView()
            .environmentObject(AuthService.shared)
    }
}
