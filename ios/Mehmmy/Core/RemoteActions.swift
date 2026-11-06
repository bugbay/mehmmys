import Foundation

// writes that go to the backend; listeners bring the results back into AppState
@MainActor
protocol RemoteActions: AnyObject {
    func logRide(crewID: String, driverID: String, from: Place, to: Place, meters: Int)
    func sendRequest(crewID: String, from: Place, to: Place, when: RequestWhen)
    func claim(crewID: String, requestID: String)
    func redeem(crewID: String, tier: RewardTier)
    func addPlace(crewID: String, place: Place)
    func removePlace(crewID: String, placeID: String)
    func removeMember(crewID: String, memberID: String)
    func setCoOwner(crewID: String, memberID: String, on: Bool)
    func linkLegacyMember(crewID: String, stubID: String, memberID: String)
    func updateTiers(crewID: String, tiers: [RewardTier])
    func leaveCrew(crewID: String)
    func setUnit(_ unit: DistanceUnit)
    func saveProfile(name: String, emoji: String, colorHex: String) async throws
    func createCrew(name: String) async throws
    func joinCrew(code: String) async throws
    func signInWithGoogle() async throws
    func signOut()
    func deleteAccount() async throws
    func requestPushPermission()
}
