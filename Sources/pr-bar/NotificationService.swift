import Foundation
import UserNotifications

/// Local notifications. Requires a real `.app` bundle (see make-app.sh) —
/// `UNUserNotificationCenter` derives its identity from the bundle identifier.
enum NotificationService {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Posts one banner per newly-requested review. Tapping it opens the PR.
    static func notifyNewReviewRequests(_ prs: [PullRequest]) {
        for pr in prs {
            let content = UNMutableNotificationContent()
            content.title = "Review requested"
            content.body = "\(pr.repository.nameWithOwner) #\(pr.number) — \(pr.title)"
            content.sound = .default
            content.userInfo = ["url": pr.url]
            let request = UNNotificationRequest(identifier: pr.id, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Posts one banner per PR whose CI just turned red. Tapping it opens the PR.
    static func notifyBrokenCI(_ prs: [PullRequest]) {
        for pr in prs {
            let content = UNMutableNotificationContent()
            content.title = "CI failing ❌"
            content.body = "\(pr.repository.nameWithOwner) #\(pr.number) — \(pr.title)"
            content.sound = .default
            content.userInfo = ["url": pr.url]
            let request = UNNotificationRequest(identifier: "ci-\(pr.id)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Posts one banner per freshly-submitted review on your PRs. Tapping it opens the PR.
    static func notifyReceivedReviews(_ reviews: [ReceivedReview]) {
        for received in reviews {
            let content = UNMutableNotificationContent()
            content.title = received.title
            content.body = "\(received.reviewerLogin) — \(received.pullRequest.repository.nameWithOwner) #\(received.pullRequest.number)"
            content.sound = .default
            content.userInfo = ["url": received.pullRequest.url]
            let request = UNNotificationRequest(identifier: "review-\(received.review.id)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

}
