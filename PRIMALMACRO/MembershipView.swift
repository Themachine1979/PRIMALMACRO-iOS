import SwiftUI
import AuthenticationServices
import StoreKit
import Combine
import CryptoKit

// PRIMALMACRO v0.2: Apple-only sign-in. Google can be added later.
@MainActor
final class AppleMemberSession: ObservableObject {
    @Published private(set) var signedIn = false
    @Published var errorMessage: String?
    private let userIDKey = "primalmacro.apple.user.id"

    var userID: String? { UserDefaults.standard.string(forKey: userIDKey) }

    var accountToken: UUID? {
        guard let userID else { return nil }
        var bytes = Array(SHA256.hash(data: Data("primalmacro.storekit.v1:\(userID)".utf8)).prefix(16))
        bytes[6] = (bytes[6] & 15) | 128
        bytes[8] = (bytes[8] & 63) | 128
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    func restore() async {
        guard let id = UserDefaults.standard.string(forKey: userIDKey) else { return }
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: id)
            guard userID == id else { return }
            signedIn = state == .authorized
            if state == .revoked || state == .notFound { signOut() }
        } catch {
            if userID == id { signedIn = false }
        }
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  credential.identityToken != nil else {
                errorMessage = "Apple did not return a valid sign-in credential."
                return
            }
            if userID != credential.user { ScannerSession.clear() }
            UserDefaults.standard.set(credential.user, forKey: userIDKey)
            signedIn = true
            errorMessage = nil
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
            }
        }
    }

    func signOut() {
        ScannerSession.clear()
        UserDefaults.standard.removeObject(forKey: userIDKey)
        signedIn = false
    }
}

@MainActor
final class MembershipPlans: ObservableObject {
    static let monthlyID = "uk.themachine1979.primalmacro.monthly"
    static let yearlyID = "uk.themachine1979.primalmacro.yearly"
    private static let ids: Set<String> = [monthlyID, yearlyID]

    @Published private(set) var ready = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var trialEligibleIDs: Set<String> = []
    @Published private(set) var activeTransactions: [StoreKit.Transaction] = []
    @Published private(set) var loadingProducts = false

    func hasEntitlement(for token: UUID?) -> Bool {
        activeTransactions.contains { $0.appAccountToken == nil || $0.appAccountToken == token }
    }

    func scanTransaction(for token: UUID) -> StoreKit.Transaction? {
        activeTransactions.first { $0.appAccountToken == token && $0.ownershipType == .purchased }
    }
    @Published var selectedID = yearlyID
    @Published var purchasing = false
    @Published var message: String?
    private var transactionTask: Task<Void, Never>?

    func start() async {
        guard !ready else { return }
        if transactionTask == nil {
            transactionTask = Task { [weak self] in
                for await update in StoreKit.Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlement()
                }
            }
        }
        await refreshEntitlement()
        await loadProducts()
        ready = true
    }

    func loadProducts() async {
        guard !loadingProducts else { return }
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            products = try await Product.products(for: Array(Self.ids))
            if product(selectedID) == nil, let available = products.first {
                selectedID = available.id
            }
            if products.isEmpty {
                message = "Monthly and yearly plans haven't been configured in App Store Connect yet."
            } else {
                message = nil
            }
            var eligible: Set<String> = []
            for product in products {
                guard let subscription = product.subscription,
                      let offer = subscription.introductoryOffer,
                      offer.paymentMode == .freeTrial,
                      offer.period.unit == .week,
                      offer.period.value == 2 else { continue }
                let isEligible = await subscription.isEligibleForIntroOffer
                if isEligible {
                    eligible.insert(product.id)
                }
            }
            trialEligibleIDs = eligible
        } catch {
            products = []
            trialEligibleIDs = []
            message = "Couldn't load Apple subscription prices. Check your internet connection."
        }
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    func refreshEntitlement() async {
        var active: [StoreKit.Transaction] = []
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  Self.ids.contains(transaction.productID),
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            if transaction.expirationDate.map({ $0 > Date() }) ?? false {
                active.append(transaction)
            }
        }
        activeTransactions = active
    }

    func purchase(accountToken: UUID) async {
        guard !purchasing, let selected = product(selectedID) else { return }
        purchasing = true
        message = nil
        defer { purchasing = false }
        do {
            let result = try await selected.purchase(options: [.appAccountToken(accountToken)])
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlement()
                case .unverified:
                    message = "Apple couldn't verify this transaction. Access wasn't enabled."
                }
            case .pending:
                message = "Purchase is pending approval. Access starts once Apple confirms it."
            case .userCancelled:
                break
            @unknown default:
                message = "The purchase couldn't be completed."
            }
        } catch {
            message = "Subscription couldn't be completed: \(error.localizedDescription)"
        }
    }

    func restorePurchases(accountToken: UUID?) async {
        guard !purchasing else { return }
        purchasing = true
        message = nil
        defer { purchasing = false }
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlement()
            if !hasEntitlement(for: accountToken) {
                message = "No active PRIMALMACRO subscription was found for this Apple account."
            }
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }
}

struct MembershipGateView: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var member: AppleMemberSession
    @EnvironmentObject private var plans: MembershipPlans
    @State private var booting = true

    var body: some View {
        Group {
            if booting {
                VStack(spacing: 16) {
                    PMBrand()
                    ProgressView("Loading membership")
                        .tint(PM.orange)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PM.background)
            } else if !member.signedIn || !plans.hasEntitlement(for: member.accountToken) {
                MembershipLandingView()
            } else if appStore.profile == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task {
            await member.restore()
            await plans.start()
            booting = false
        }
    }
}

private struct MembershipLandingView: View {
    @EnvironmentObject private var member: AppleMemberSession
    @EnvironmentObject private var plans: MembershipPlans

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .padding(.top, 24)
                PMBrand()
                Text("FUEL THE BEAST")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("SCAN FOOD · MASTER MACROS · TRACK PROGRESS")
                    .font(.caption.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(PM.orange)
                    .multilineTextAlignment(.center)
                PMPanel {
                    VStack(alignment: .leading, spacing: 11) {
                        Label("AI photo scanning: meals, menus and packaging", systemImage: "camera.viewfinder")
                        Label("Personal daily calorie and protein targets", systemImage: "target")
                        Label("Nutrition diary and body-weight progress", systemImage: "chart.xyaxis.line")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("CHOOSE YOUR PLAN")
                        .font(.headline.weight(.black))
                        .foregroundStyle(PM.orange)
                    planButton(id: MembershipPlans.monthlyID, title: "MONTHLY", caption: "Billed monthly")
                    planButton(id: MembershipPlans.yearlyID, title: "YEARLY", caption: "Billed annually")
                    if let selected = plans.product(plans.selectedID) {
                        if plans.trialEligibleIDs.contains(selected.id) {
                            Text("14 DAYS FREE, THEN \(selected.displayPrice) PER \(plans.selectedID == MembershipPlans.monthlyID ? "MONTH" : "YEAR")")
                                .foregroundStyle(PM.orange)
                                .font(.subheadline.weight(.heavy))
                        } else {
                            Text("Renews at \(selected.displayPrice) per \(plans.selectedID == MembershipPlans.monthlyID ? "month" : "year"). The free trial is available only when Apple confirms eligibility.")
                                .font(.caption)
                                .foregroundStyle(PM.secondary)
                        }
                    } else {
                        Text("Waiting for subscription prices from Apple. No purchase will be offered until prices are available.")
                            .font(.caption).foregroundStyle(PM.secondary)
                    }
                }
                .padding(16)
                .background(PM.surface, in: RoundedRectangle(cornerRadius: 18))

                if !member.signedIn {
                    SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: member.completeAppleSignIn)
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Sign in securely with Apple to continue")
                        .font(.caption).foregroundStyle(PM.secondary)
                } else {
                    PMLargeButton(
                        title: plans.product(plans.selectedID).map {
                            plans.trialEligibleIDs.contains($0.id) ? "START 14-DAY FREE TRIAL" : "SUBSCRIBE FOR \($0.displayPrice)"
                        } ?? "PLANS NOT AVAILABLE",
                        icon: "bolt.fill",
                        enabled: plans.product(plans.selectedID) != nil && !plans.purchasing
                    ) {
                        guard let accountToken = member.accountToken else { return }
                        Task { await plans.purchase(accountToken: accountToken) }
                    }
                }

                if let error = member.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if let message = plans.message {
                    Text(message).font(.caption).foregroundStyle(PM.secondary)
                }
                HStack {
                    Button("Restore Purchases") {
                        Task { await plans.restorePurchases(accountToken: member.accountToken) }
                    }
                    .disabled(plans.purchasing || !member.signedIn)
                    Spacer()
                    if member.signedIn {
                        Button("Sign out") { member.signOut() }
                    }
                    if plans.products.count < 2 {
                        Button("Retry Prices") { Task { await plans.loadProducts() } }
                            .disabled(plans.loadingProducts)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PM.orange)
                Text("Subscriptions renew automatically unless cancelled. The Apple purchase screen confirms pricing and any trial before you subscribe. Manage or cancel in iPhone Settings → Subscriptions.")
                    .font(.caption)
                    .foregroundStyle(PM.secondary)
                    .multilineTextAlignment(.center)
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.caption)
                Text("For adults 18+. Nutrition scans are estimates, not medical advice.")
                    .font(.caption2)
                    .foregroundStyle(PM.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .background(PM.background)
    }

    @ViewBuilder
    private func planButton(id: String, title: String, caption: String) -> some View {
        let selected = plans.selectedID == id
        Button {
            plans.selectedID = id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(PM.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline.weight(.heavy))
                    Text(caption).font(.caption).foregroundStyle(PM.secondary)
                }
                Spacer()
                if let product = plans.product(id) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice).font(.headline.weight(.heavy))
                        if plans.trialEligibleIDs.contains(id) {
                            Text("14 DAYS FREE")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(PM.orange)
                        }
                    }
                } else {
                    Text("Unavailable").font(.caption).foregroundStyle(PM.secondary)
                }
            }
            .padding(15)
            .foregroundStyle(.white)
            .background(selected ? PM.elevated : PM.background,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? PM.orange : PM.elevated, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(plans.product(id) == nil || plans.purchasing)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
