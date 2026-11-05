import Foundation
import SwiftUI
import UIKit
import UserNotifications
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging
import GoogleSignIn

struct BackendError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class FirebaseBackend: RemoteActions {
    private let state: AppState
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    private var membershipListener: ListenerRegistration?
    private var crewListeners: [String: [ListenerRegistration]] = [:]
    private var parts: [String: CrewParts] = [:]

    private var uid: String?
    private var userLoaded = false
    private var hasProfile = false
    private var pendingToken: String?
    private var currentNonce: String?

    private struct CrewParts {
        var doc: [String: Any]?
        var members: [Member] = []
        var places: [Place] = []
        var requests: [RideRequest] = []
        var activity: [ActivityItem] = []
    }

    init(state: AppState) {
        self.state = state
        state.phase = .loading
        state.remote = self
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.userChanged(user) }
        }
    }

    // MARK: auth

    private func userChanged(_ user: User?) {
        userListener?.remove()
        membershipListener?.remove()
        crewListeners.values.flatMap { $0 }.forEach { $0.remove() }
        crewListeners = [:]
        parts = [:]
        uid = user?.uid
        userLoaded = false
        hasProfile = false
        state.crews = []
        guard let user else { recomputePhase(); return }
        state.me.id = user.uid
        if state.suggestedName.isEmpty { state.suggestedName = user.displayName ?? "" }
        listenUser(user.uid)
        listenMemberships(user.uid)
        if let token = pendingToken { saveToken(token) }
        recomputePhase()
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) async throws {
        let auth = try result.get()
        guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken, let token = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else { throw BackendError(message: "Apple sign-in failed") }
        if let given = cred.fullName?.givenName, !given.isEmpty { state.suggestedName = given }
        let credential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: cred.fullName)
        try await Auth.auth().signIn(with: credential)
    }

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { throw BackendError(message: "Google sign-in is not configured") }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let root = Self.rootViewController() else { throw BackendError(message: "No window to present sign-in") }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
        guard let idToken = result.user.idToken?.tokenString else { throw BackendError(message: "Google sign-in failed") }
        if let given = result.user.profile?.givenName, !given.isEmpty { state.suggestedName = given }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        try await Auth.auth().signIn(with: credential)
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    func deleteAccount() async throws {
        _ = try await call("deleteAccount", [:])
        signOut()
    }

    // MARK: listeners

    private func listenUser(_ uid: String) {
        userListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self else { return }
                self.userLoaded = true
                if let data = snap?.data() {
                    let wasMissing = !self.hasProfile
                    self.hasProfile = true
                    if wasMissing, let token = self.pendingToken { self.saveToken(token) }
                    self.state.me.name = data["displayName"] as? String ?? self.state.me.name
                    self.state.me.emoji = data["emoji"] as? String ?? self.state.me.emoji
                    if let c = Color(hexString: data["color"] as? String ?? "") { self.state.me.color = c }
                    self.state.me.unit = DistanceUnit(rawValue: data["unit"] as? String ?? "auto") ?? .auto
                } else {
                    self.hasProfile = false
                }
                self.recomputePhase()
            }
        }
    }

    private func listenMemberships(_ uid: String) {
        membershipListener = db.collectionGroup("members").whereField("uid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self, let snap else { return }
                    let ids = Set(snap.documents.compactMap { $0.reference.parent.parent?.documentID })
                    for gone in Set(self.crewListeners.keys).subtracting(ids) {
                        self.crewListeners[gone]?.forEach { $0.remove() }
                        self.crewListeners[gone] = nil
                        self.parts[gone] = nil
                    }
                    for id in ids where self.crewListeners[id] == nil { self.attachCrew(id) }
                    self.rebuild()
                }
            }
    }

    private func attachCrew(_ id: String) {
        parts[id] = CrewParts()
        let ref = db.collection("crews").document(id)
        let update: (@escaping (inout CrewParts) -> Void) -> Void = { [weak self] change in
            Task { @MainActor in
                guard let self, self.parts[id] != nil else { return }
                change(&self.parts[id]!)
                self.rebuild()
            }
        }
        crewListeners[id] = [
            ref.addSnapshotListener { snap, _ in
                let data = snap?.data()
                update { $0.doc = data }
            },
            ref.collection("members").addSnapshotListener { snap, _ in
                let members = snap?.documents.compactMap { Member.from(id: $0.documentID, data: $0.data()) } ?? []
                update { $0.members = members }
            },
            ref.collection("places").order(by: "createdAt").addSnapshotListener { snap, _ in
                let places = snap?.documents.compactMap { Place.from(id: $0.documentID, data: $0.data()) } ?? []
                update { $0.places = places }
            },
            ref.collection("requests").order(by: "ts", descending: true).limit(to: 20).addSnapshotListener { snap, _ in
                let requests = snap?.documents.compactMap { d -> RideRequest? in
                    let data = d.data(with: .estimate)
                    return RideRequest.from(id: d.documentID, data: data, date: (data["ts"] as? Timestamp)?.dateValue() ?? .now)
                } ?? []
                update { $0.requests = requests }
            },
            ref.collection("activity").order(by: "ts", descending: true).limit(to: 50).addSnapshotListener { snap, _ in
                let items = snap?.documents.compactMap { d -> ActivityItem? in
                    let data = d.data(with: .estimate)
                    return ActivityItem.from(id: d.documentID, data: data, date: (data["ts"] as? Timestamp)?.dateValue() ?? .now)
                } ?? []
                update { $0.activity = items }
            },
        ]
    }

    private func rebuild() {
        guard let uid else { return }
        let crews: [Crew] = parts.compactMap { id, p in
            guard let doc = p.doc else { return nil }
            let tiers = (doc["rewardTiers"] as? [[String: Any]] ?? []).compactMap(RewardTier.from).sorted { $0.cost < $1.cost }
            return Crew(
                id: id,
                name: doc["name"] as? String ?? "Crew",
                ownerID: doc["ownerUid"] as? String ?? "",
                inviteCode: doc["inviteCode"] as? String ?? "",
                members: p.members,
                places: p.places,
                tiers: tiers,
                requests: p.requests,
                activity: p.activity
            )
        }
        .sorted { a, b in
            if (a.ownerID == uid) != (b.ownerID == uid) { return a.ownerID == uid }
            return a.name < b.name
        }
        state.crews = crews
        if !crews.contains(where: { $0.id == state.currentCrewID }) { state.currentCrewID = crews.first?.id ?? "" }
        recomputePhase()
    }

    private func recomputePhase() {
        guard uid != nil else { state.phase = .signedOut; return }
        guard userLoaded else { state.phase = .loading; return }
        let pendingCrews = parts.values.contains { $0.doc == nil }
        if hasProfile && state.crews.isEmpty && pendingCrews { state.phase = .loading; return }
        state.phase = AppPhase.derive(signedIn: true, hasProfile: hasProfile, crewCount: state.crews.count)
    }

    // MARK: profile and crews

    func saveProfile(name: String, emoji: String, colorHex: String) async throws {
        guard let uid else { throw BackendError(message: "Sign in first") }
        if hasProfile {
            _ = try await call("updateProfile", ["displayName": name, "emoji": emoji, "color": colorHex])
            return
        }
        var doc: [String: Any] = [
            "displayName": name, "emoji": emoji, "color": colorHex, "unit": "auto",
            "locale": String(Locale.current.identifier.prefix(20)), "fcmTokens": [String](),
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let email = Auth.auth().currentUser?.email { doc["email"] = email }
        try await db.collection("users").document(uid).setData(doc)
    }

    func createCrew(name: String) async throws {
        let result = try await call("createCrew", ["name": name])
        if let id = result["crewId"] as? String { state.currentCrewID = id }
    }

    func joinCrew(code: String) async throws {
        let result = try await call("joinCrew", ["code": code])
        if let id = result["crewId"] as? String { state.currentCrewID = id }
    }

    func leaveCrew(crewID: String) {
        fire("leaveCrew", ["crewId": crewID])
    }

    func removeMember(crewID: String, memberID: String) {
        fire("removeMember", ["crewId": crewID, "memberUid": memberID])
    }

    func setUnit(_ unit: DistanceUnit) {
        guard let uid else { return }
        db.collection("users").document(uid).updateData(["unit": unit.rawValue]) { [weak self] err in self?.report(err) }
    }

    // MARK: crew writes

    func logRide(crewID: String, driverID: String, from: Place, to: Place, meters: Int) {
        guard let uid else { return }
        crew(crewID).collection("rides").addDocument(data: [
            "driverUid": driverID, "fromPlaceId": from.id, "fromName": from.name,
            "toPlaceId": to.id, "toName": to.name, "meters": meters, "estimated": false,
            "ts": FieldValue.serverTimestamp(), "createdBy": uid,
        ]) { [weak self] err in self?.report(err) }
    }

    func sendRequest(crewID: String, from: Place, to: Place, when: RequestWhen) {
        guard let uid else { return }
        crew(crewID).collection("requests").addDocument(data: [
            "byUid": uid, "fromName": from.name, "toName": to.name, "when": when.rawValue,
            "ts": FieldValue.serverTimestamp(), "claimedBy": NSNull(), "claimedAt": NSNull(),
        ]) { [weak self] err in self?.report(err) }
    }

    func claim(crewID: String, requestID: String) {
        guard let uid else { return }
        crew(crewID).collection("requests").document(requestID).updateData([
            "claimedBy": uid, "claimedAt": FieldValue.serverTimestamp(),
        ]) { [weak self] err in self?.report(err) }
    }

    func redeem(crewID: String, tier: RewardTier) {
        guard let uid else { return }
        crew(crewID).collection("redemptions").addDocument(data: [
            "driverUid": uid, "tierId": tier.id, "title": tier.title, "cost": tier.cost,
            "ts": FieldValue.serverTimestamp(), "status": "pending",
        ]) { [weak self] err in self?.report(err) }
    }

    func addPlace(crewID: String, place: Place) {
        crew(crewID).collection("places").document(place.id).setData([
            "name": place.name, "lat": place.lat, "lng": place.lng, "createdAt": FieldValue.serverTimestamp(),
        ]) { [weak self] err in self?.report(err) }
    }

    func removePlace(crewID: String, placeID: String) {
        crew(crewID).collection("places").document(placeID).delete { [weak self] err in self?.report(err) }
    }

    func updateTiers(crewID: String, tiers: [RewardTier]) {
        crew(crewID).updateData(["rewardTiers": tiers.map(\.document)]) { [weak self] err in self?.report(err) }
    }

    // MARK: push

    func requestPushPermission() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func saveToken(_ token: String) {
        pendingToken = token
        guard let uid, hasProfile else { return }
        db.collection("users").document(uid).updateData(["fcmTokens": FieldValue.arrayUnion([token])]) { _ in }
    }

    // MARK: helpers

    private func crew(_ id: String) -> DocumentReference { db.collection("crews").document(id) }

    private func call(_ name: String, _ data: [String: Any]) async throws -> [String: Any] {
        do {
            let result = try await functions.httpsCallable(name).call(data)
            return result.data as? [String: Any] ?? [:]
        } catch {
            throw BackendError(message: (error as NSError).localizedDescription)
        }
    }

    private func fire(_ name: String, _ data: [String: Any]) {
        Task {
            do { _ = try await call(name, data) } catch { report(error) }
        }
    }

    private func report(_ error: Error?) {
        guard let error else { return }
        state.show(Toast(emoji: "⚠️", title: "Couldn't save that", subtitle: error.localizedDescription))
    }

    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
