import Foundation

/// The two buckets we surface in the menu bar.
struct PRBuckets {
    var reviewRequested: [PullRequest]
    var authored: [PullRequest]
    /// Our own login, so we can ignore reviews we posted ourselves.
    var me: String
}

/// A freshly-submitted review on one of your PRs, pairing the PR with the review.
struct ReceivedReview {
    let pullRequest: PullRequest
    let review: PullRequest.ReviewConnection.Review

    var reviewerLogin: String { review.author?.login ?? "Someone" }

    var title: String {
        switch review.state {
        case "APPROVED": return "Review approved ✅"
        case "CHANGES_REQUESTED": return "Changes requested 📝"
        case "COMMENTED": return "New review comment 💬"
        case "DISMISSED": return "Review dismissed"
        default: return "New review"
        }
    }
}

enum CheckState: Equatable {
    case success, failure, pending, none
}

struct Person: Decodable, Identifiable {
    let login: String
    let avatarUrl: String

    var id: String { login }
}

struct PullRequest: Identifiable, Decodable {
    let number: Int
    let title: String
    let url: String
    let createdAt: Date
    let isDraft: Bool
    let headRefName: String
    let baseRefName: String
    let repository: Repository
    let author: Author?
    let mergeable: String?
    let commits: CommitConnection
    let assignees: UserConnection
    let reviewRequests: ReviewRequestConnection
    let reviews: ReviewConnection

    var id: String { url }

    /// People assigned to the PR.
    var assigneePeople: [Person] { assignees.nodes }

    /// Users requested for review (Team reviewers, which have no avatar, are dropped).
    var reviewerPeople: [Person] {
        reviewRequests.nodes.compactMap { node in
            guard let login = node.requestedReviewer?.login,
                  let avatarUrl = node.requestedReviewer?.avatarUrl else { return nil }
            return Person(login: login, avatarUrl: avatarUrl)
        }
    }

    var hasConflicts: Bool { mergeable == "CONFLICTING" }

    var checkState: CheckState {
        guard let state = commits.nodes.first?.commit.statusCheckRollup?.state else { return .none }
        switch state {
        case "SUCCESS": return .success
        case "FAILURE", "ERROR": return .failure
        case "PENDING", "EXPECTED": return .pending
        default: return .none
        }
    }

    /// Compact age such as "3j", "5h" or "12m".
    var relativeAge: String {
        let seconds = Date().timeIntervalSince(createdAt)
        let days = Int(seconds / 86_400)
        if days > 0 {
            return "\(days)j"
        }
        let hours = Int(seconds / 3_600)
        if hours > 0 {
            return "\(hours)h"
        }
        let minutes = Int(seconds / 60)
        return "\(max(minutes, 1))m"
    }

    struct Repository: Decodable {
        let nameWithOwner: String
    }

    struct Author: Decodable {
        let login: String
    }

    struct UserConnection: Decodable {
        let nodes: [Person]
    }

    struct ReviewRequestConnection: Decodable {
        let nodes: [ReviewRequestNode]

        struct ReviewRequestNode: Decodable {
            let requestedReviewer: Reviewer?

            struct Reviewer: Decodable {
                let login: String?
                let avatarUrl: String?
            }
        }
    }

    struct ReviewConnection: Decodable {
        let nodes: [Review]

        struct Review: Decodable {
            let id: String
            let state: String
            let author: Author?
        }
    }

    struct CommitConnection: Decodable {
        let nodes: [CommitNode]

        struct CommitNode: Decodable {
            let commit: Commit

            struct Commit: Decodable {
                let statusCheckRollup: Rollup?

                struct Rollup: Decodable {
                    let state: String
                }
            }
        }
    }
}

/// Mirrors the GraphQL response envelope.
struct GraphQLResponse: Decodable {
    let data: DataField

    struct DataField: Decodable {
        let reviewRequested: SearchResult
        let authored: SearchResult
    }

    struct SearchResult: Decodable {
        let nodes: [PullRequest]
    }
}
