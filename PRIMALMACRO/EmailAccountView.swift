import SwiftUI

// Email and password sign-in through Firebase Authentication. Authentication
// and password reset are handled by Firebase, not stored by PRIMALMACRO.
struct EmailAccountView: View {
    @EnvironmentObject private var member: AppleMemberSession
    @Environment(\.dismiss) private var dismiss
    @State private var creatingAccount = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var working = false
    @State private var message: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PMBrand()
                        .padding(.top, 28)
                    Text(creatingAccount ? "CREATE YOUR ACCOUNT" : "WELCOME BACK")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                    Text("Track your meals and macros with your own secure PRIMALMACRO account.")
                        .font(.subheadline)
                        .foregroundStyle(PM.secondary)
                        .multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Email address", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        SecureField("Password", text: $password)
                            .textContentType(creatingAccount ? .newPassword : .password)
                            .textFieldStyle(.roundedBorder)
                        if creatingAccount {
                            SecureField("Confirm password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .textFieldStyle(.roundedBorder)
                            Text("Use at least 12 characters. We'll email you a verification link.")
                                .font(.caption)
                                .foregroundStyle(PM.secondary)
                        }
                    }
                    .padding(16)
                    .background(PM.surface, in: RoundedRectangle(cornerRadius: 16))

                    PMLargeButton(
                        title: working ? "PLEASE WAIT..." : creatingAccount ? "CREATE ACCOUNT" : "SIGN IN",
                        icon: creatingAccount ? "person.badge.plus" : "lock.open.fill",
                        enabled: !working && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        Task { await submit() }
                    }

                    Button(creatingAccount ? "Already have an account? Sign in" : "New here? Create account") {
                        creatingAccount.toggle()
                        message = nil
                        success = false
                        password = ""
                        confirmPassword = ""
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PM.orange)

                    Button("Forgot password? Email me a reset link") {
                        Task { await resetPassword() }
                    }
                    .font(.footnote)
                    .disabled(working)

                    if !creatingAccount {
                        Button("Resend email verification link") {
                            Task { await resendVerification() }
                        }
                        .font(.footnote)
                        .disabled(working || password.isEmpty)
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(success ? PM.orange : .red)
                            .multilineTextAlignment(.center)
                    }
                    Text("Your password is handled by Firebase Authentication and is never saved by this app.")
                        .font(.caption2)
                        .foregroundStyle(PM.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(PM.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func submit() async {
        guard !working else { return }
        working = true
        defer { working = false }
        success = false
        message = nil
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            if creatingAccount {
                guard password == confirmPassword else {
                    message = "Passwords don't match."
                    return
                }
                try await FirebaseEmailAuth.register(email: address, password: password)
                creatingAccount = false
                password = ""
                confirmPassword = ""
                success = true
                message = "Check your inbox for the verification link. After verifying, sign in here."
            } else {
                try await member.emailSignIn(email: address, password: password)
                dismiss()
            }
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func resetPassword() async {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard address.contains("@"), !working else {
            message = "Enter your email address first."
            return
        }
        working = true
        defer { working = false }
        await FirebaseEmailAuth.sendPasswordReset(email: address)
        success = true
        message = "If an account exists for this address, a password-reset email will arrive shortly."
    }

    @MainActor
    private func resendVerification() async {
        guard !working else { return }
        working = true
        defer { working = false }
        do {
            try await FirebaseEmailAuth.resendVerification(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password)
            success = true
            message = "Verification email requested. Check your inbox."
        } catch {
            success = false
            message = error.localizedDescription
        }
    }
}
