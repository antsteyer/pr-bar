import Combine
import Foundation

@MainActor
final class PRStore: ObservableObject {
    @Published var reviewRequested: [PullRequest] = []
    @Published var authored: [PullRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private var timer: Timer?
    /// nil until the first successful load, so we never notify for the initial backlog.
    private var knownReviewIds: Set<String>?
    /// Last seen CI state per authored PR, to notify only on a fresh transition to red.
    private var knownCIStates: [String: CheckState]?
    /// Seen review ids per authored PR, to notify only on newly-submitted reviews.
    private var knownReviewIdsByPR: [String: Set<String>]?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    var lastUpdatedLabel: String {
        guard let lastUpdated else { return "Never synced" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Updated at \(formatter.string(from: lastUpdated))"
    }

    func refresh() {
        Task { await load() }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let buckets = try await Task.detached { try GitHubService().fetch() }.value
            notifyNewReviews(in: buckets.reviewRequested)
            notifyBrokenCI(in: buckets.authored)
            notifyReceivedReviews(in: buckets.authored, from: buckets.me)
            reviewRequested = buckets.reviewRequested
            authored = buckets.authored
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func notifyNewReviews(in incoming: [PullRequest]) {
        let currentIds = Set(incoming.map(\.id))
        if let knownReviewIds {
            let newPRs = incoming.filter { !knownReviewIds.contains($0.id) }
            if !newPRs.isEmpty {
                NotificationService.notifyNewReviewRequests(newPRs)
            }
        }
        knownReviewIds = currentIds
    }

    private func notifyBrokenCI(in incoming: [PullRequest]) {
        let currentStates = Dictionary(uniqueKeysWithValues: incoming.map { ($0.id, $0.checkState) })
        if let knownCIStates {
            let newlyBroken = incoming.filter { $0.checkState == .failure && knownCIStates[$0.id] != .failure }
            if !newlyBroken.isEmpty {
                NotificationService.notifyBrokenCI(newlyBroken)
            }
        }
        knownCIStates = currentStates
    }

    private func notifyReceivedReviews(in incoming: [PullRequest], from me: String) {
        let currentByPR = Dictionary(uniqueKeysWithValues: incoming.map { ($0.id, Set($0.reviews.nodes.map(\.id))) })
        if let knownReviewIdsByPR {
            let freshReviews = incoming.flatMap { pr -> [ReceivedReview] in
                guard let seen = knownReviewIdsByPR[pr.id] else { return [] }
                return pr.reviews.nodes
                    .filter { $0.author?.login != me && !seen.contains($0.id) }
                    .map { ReceivedReview(pullRequest: pr, review: $0) }
            }
            if !freshReviews.isEmpty {
                NotificationService.notifyReceivedReviews(freshReviews)
            }
        }
        knownReviewIdsByPR = currentByPR
    }
}
