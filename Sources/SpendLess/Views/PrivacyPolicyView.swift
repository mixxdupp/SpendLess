import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Last Updated: February 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Section("Information We Collect") {
                        Text("""
                        • **Account Information**: Email address and password when you create an account.
                        • **Product Data**: URLs and details of products you choose to track.
                        • **Financial Preferences**: Monthly income (optional) to calculate purchase impact.
                        • **Usage Data**: App interactions to improve the experience.
                        """)
                    }
                    
                    Section("How We Use Your Data") {
                        Text("""
                        • Track product prices and send alerts when prices drop.
                        • Calculate how purchases impact your finances.
                        • Provide AI-powered spending guidance.
                        • Improve app functionality and user experience.
                        """)
                    }
                    
                    Section("AI Features") {
                        Text("""
                        SpendLess uses AI (powered by Groq) to provide personalized spending advice. Your product data is sent to our secure servers to generate responses. We do not store conversation history beyond your session.
                        """)
                    }
                    
                    Section("Data Security") {
                        Text("""
                        • All data is encrypted in transit using HTTPS.
                        • Passwords are hashed using industry-standard algorithms.
                        • We do not sell your personal information to third parties.
                        • You can delete your account and all associated data at any time.
                        """)
                    }
                    
                    Section("Third-Party Services") {
                        Text("""
                        • **Supabase**: Database and authentication.
                        • **Groq AI**: AI-powered spending advice.
                        • **RevenueCat**: In-app purchase management.
                        """)
                    }
                    
                    Section("Your Rights") {
                        Text("""
                        You have the right to:
                        • Access your personal data.
                        • Request deletion of your data.
                        • Opt out of optional data collection.
                        • Export your data.
                        """)
                    }
                    
                    Section("Contact Us") {
                        Text("For privacy concerns, contact: **support@stopimpulsebuying.com**")
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

fileprivate struct Section<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
