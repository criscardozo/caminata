import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Uploads a finished walk so the web history can show it.
@MainActor
protocol WalkSyncing: AnyObject {
    /// True when there is both a Firebase configuration and someone signed in.
    var canUpload: Bool { get }
    func upload(_ walk: Walk) async throws
}

@MainActor
final class FirestoreWalkSync: WalkSyncing {
    enum SyncError: LocalizedError {
        case signedOut
        case nothingToUpload

        var errorDescription: String? {
            switch self {
            case .signedOut:
                return "Sign in to keep your walks on the web."
            case .nothingToUpload:
                return "That walk recorded nothing worth uploading."
            }
        }
    }

    private let account: CloudAccounting

    init(account: CloudAccounting) {
        self.account = account
    }

    var canUpload: Bool { account.isAvailable && account.userID != nil }

    func upload(_ walk: Walk) async throws {
        guard let userID = account.userID else { throw SyncError.signedOut }
        guard let cloud = CloudWalk(walk: walk) else { throw SyncError.nothingToUpload }

        try await Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("walks")
            .document(cloud.id.uuidString)
            .setData(cloud.firestoreData)
    }
}

extension CloudWalk {
    /// The document the web reads. Dates go as Firestore timestamps so the
    /// browser gets them back as real dates rather than numbers to guess at.
    var firestoreData: [String: Any] {
        [
            "startedAt": Timestamp(date: startedAt),
            "endedAt": Timestamp(date: endedAt),
            "distance": distance,
            "movingTime": movingTime,
            "elevationGain": elevationGain,
            "pointCount": pointCount,
            "route": route,
            "uploadedAt": FieldValue.serverTimestamp()
        ]
    }
}
