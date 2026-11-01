import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Uploads a finished walk so the web history can show it.
@MainActor
protocol WalkSyncing: AnyObject {
    /// True when there is both a Firebase configuration and someone signed in.
    var canUpload: Bool { get }
    func upload(_ walk: Walk) async throws
    func delete(walkID: UUID) async throws
}

@MainActor
final class FirestoreWalkSync: WalkSyncing {
    enum SyncError: LocalizedError {
        case signedOut
        case nothingToUpload

        var errorDescription: String? {
            switch self {
            case .signedOut:
                return "Iniciá sesión para tener tus caminatas en la web."
            case .nothingToUpload:
                return "Esa caminata no registró nada para subir."
            }
        }
    }

    private let account: CloudAccounting

    init(account: CloudAccounting) {
        self.account = account
    }

    var canUpload: Bool { account.isAvailable && account.userID != nil }

    func upload(_ walk: Walk) async throws {
        guard account.userID != nil else { throw SyncError.signedOut }
        guard let cloud = CloudWalk(walk: walk) else { throw SyncError.nothingToUpload }

        // Merged rather than overwritten, so a name typed on the web survives a
        // later upload of the same walk from the phone.
        try await document(cloud.id).setData(cloud.firestoreData, merge: true)
    }

    func delete(walkID: UUID) async throws {
        guard account.userID != nil else { throw SyncError.signedOut }
        try await document(walkID).delete()
    }

    /// One collection for the household. Who recorded a walk is deliberately
    /// not part of where it lives: both of us see all of them.
    private func document(_ walkID: UUID) -> DocumentReference {
        Firestore.firestore().collection("walks").document(walkID.uuidString)
    }
}

extension CloudWalk {
    /// The document the web reads. Dates go as Firestore timestamps so the
    /// browser gets them back as real dates rather than numbers to guess at.
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "startedAt": Timestamp(date: startedAt),
            "endedAt": Timestamp(date: endedAt),
            "distance": distance,
            "movingTime": movingTime,
            "elevationGain": elevationGain,
            "pointCount": pointCount,
            "route": route,
            "uploadedAt": FieldValue.serverTimestamp()
        ]
        // Left out rather than written as null when there is none, so a name
        // typed on the web is not wiped by a later upload of the same walk.
        if let name, !name.isEmpty {
            data["name"] = name
        }
        if let routeColor, RouteColor.isValid(routeColor) {
            data["routeColor"] = routeColor
        }
        // Always written, even empty: the upload merges, so a walk uploaded
        // again after a change must replace any breaks it had before.
        data["breaks"] = breaks
        return data
    }
}
