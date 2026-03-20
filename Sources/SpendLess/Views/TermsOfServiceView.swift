import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Last Updated: February 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Section("Acceptance of Terms") {
                        Text("""
                        By using SpendLess, you agree to these Terms of Service. If you do not agree, please do not use the app.
                        """)
                    }
                    
                    Section("Description of Service") {
                        Text("""
                        SpendLess is a personal finance tool that helps you:
                        • Track product prices across online stores.
                        • Receive alerts when prices drop.
                        • Get AI-powered advice to make mindful spending decisions.
                        """)
                    }
                    
                    Section("User Accounts") {
                        Text("""
                        • You must provide accurate information when creating an account.
                        • You are responsible for maintaining the security of your account.
                        • You must be at least 13 years old to use this service.
                        """)
                    }
                    
                    Section("Acceptable Use") {
                        Text("""
                        You agree NOT to:
                        • Use the app for any illegal purpose.
                        • Attempt to bypass security measures.
                        • Abuse the AI features or attempt to manipulate responses.
                        • Interfere with the operation of the service.
                        """)
                    }
                    
                    Section("Subscriptions & Payments") {
                        Text("""
                        • Free tier includes limited product tracking.
                        • Premium features require a subscription or one-time purchase.
                        • Subscriptions auto-renew unless cancelled.
                        • Refunds are subject to Apple's App Store policies.
                        """)
                    }
                    
                    Section("AI Disclaimer") {
                        Text("""
                        The AI-powered "Rationalist" feature provides general spending advice and is NOT financial advice. Decisions about purchases are your own responsibility. We are not liable for any financial decisions made based on AI suggestions.
                        """)
                    }
                    
                    Section("Limitation of Liability") {
                        Text("""
                        SpendLess is provided "as is" without warranties. We are not responsible for:
                        • Inaccurate price data from third-party websites.
                        • Service interruptions or data loss.
                        • Decisions made based on app recommendations.
                        """)
                    }
                    
                    Section("Changes to Terms") {
                        Text("""
                        We may update these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.
                        """)
                    }
                    
                    Section("Contact") {
                        Text("Questions? Contact: **support@stopimpulsebuying.com**")
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
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
    TermsOfServiceView()
}
