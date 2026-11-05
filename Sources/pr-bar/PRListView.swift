import SwiftUI

struct PRListView: View {
    @EnvironmentObject var store: PRStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = store.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }

                    section(title: "To review", prs: store.reviewRequested, emptyText: "Nothing to review 🎉") { $0.assigneePeople }

                    section(title: "My PRs", prs: store.authored, emptyText: "No open PRs", showsReviewsToAddress: true) { $0.reviewerPeople }
                }
                .padding(12)
            }

            Divider()

            footer
        }
        .frame(width: 360, height: 480)
    }

    private var header: some View {
        HStack {
            Text("Pull Requests")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button(action: store.refresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)
            .opacity(store.isLoading ? 0.4 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Text(store.lastUpdatedLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func section(title: String, prs: [PullRequest], emptyText: String, showsReviewsToAddress: Bool = false, people: @escaping (PullRequest) -> [Person]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if prs.isEmpty {
                Text(emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedByRepo(prs)) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(group.repo, systemImage: "folder")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        ForEach(group.prs) { pr in
                            PRRow(pr: pr, people: people(pr), reviewersToAddress: showsReviewsToAddress ? pr.reviewersAwaitingResponse : [])
                        }
                    }
                }
            }
        }
    }

    private func groupedByRepo(_ prs: [PullRequest]) -> [RepoGroup] {
        Dictionary(grouping: prs, by: { $0.repository.nameWithOwner })
            .map { RepoGroup(repo: $0.key, prs: $0.value) }
            .sorted { $0.repo < $1.repo }
    }
}

private struct RepoGroup: Identifiable {
    let repo: String
    let prs: [PullRequest]
    var id: String { repo }
}

private struct AvatarCluster: View {
    let people: [Person]
    @State private var hoveredLogin: String?

    var body: some View {
        HStack(spacing: 6) {
            if let hoveredLogin {
                Text(hoveredLogin)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: -5) {
                ForEach(people.prefix(4)) { person in
                    AsyncImage(url: URL(string: person.avatarUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1))
                    .onHover { inside in
                        if inside {
                            hoveredLogin = person.login
                        } else if hoveredLogin == person.login {
                            hoveredLogin = nil
                        }
                    }
                }

                if people.count > 4 {
                    Text("+\(people.count - 4)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 7)
                }
            }
        }
    }
}

private extension PRLabel {
    /// Parses GitHub's hex colour, falling back to grey when it is malformed.
    var components: (red: Double, green: Double, blue: Double) {
        var hex = color.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return (0.5, 0.5, 0.5) }
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }

    var swiftUIColor: Color {
        let (red, green, blue) = components
        return Color(red: red, green: green, blue: blue)
    }

    /// The same colour nudged toward the readable end of the current appearance:
    /// GitHub lets people pick near-black or near-white labels, which vanish otherwise.
    func readableColor(for scheme: ColorScheme) -> Color {
        let (red, green, blue) = components
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        if scheme == .dark, luminance < 0.45 {
            let mix = (0.45 - luminance) / 0.45
            return Color(
                red: red + (1 - red) * mix,
                green: green + (1 - green) * mix,
                blue: blue + (1 - blue) * mix
            )
        }
        if scheme == .light, luminance > 0.6 {
            let mix = (luminance - 0.6) / 0.4 * 0.6
            return Color(red: red * (1 - mix), green: green * (1 - mix), blue: blue * (1 - mix))
        }
        return Color(red: red, green: green, blue: blue)
    }
}

private struct LabelCluster: View {
    let labels: [PRLabel]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(labels.prefix(3)) { label in
                Text(label.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(label.readableColor(for: colorScheme))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(label.swiftUIColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(label.swiftUIColor.opacity(0.4), lineWidth: 0.5)
                    )
                    .help(label.name)
            }

            if labels.count > 3 {
                Text("+\(labels.count - 3)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help(labels.dropFirst(3).map(\.name).joined(separator: ", "))
            }
        }
    }
}

private struct ToAddressBadge: View {
    let reviewers: [String]

    private var text: String {
        let others = reviewers.count > 1 ? " +\(reviewers.count - 1)" : ""
        return "To address · \(reviewers[0])\(others)"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.bubble.fill")
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.black)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help("Waiting on you: \(reviewers.joined(separator: ", "))")
    }
}

private extension PullRequest.ReviewStatus {
    var icon: String {
        switch self {
        case .approved: return "checkmark.circle.fill"
        case .changesRequested: return "xmark.circle.fill"
        case .commented: return "bubble.left.fill"
        case .none: return ""
        }
    }

    var color: Color {
        switch self {
        case .approved: return .green
        case .changesRequested: return .red
        case .commented: return .secondary
        case .none: return .clear
        }
    }

    var label: String {
        switch self {
        case .approved: return "Approved"
        case .changesRequested: return "Changes requested"
        case .commented: return "Commented"
        case .none: return ""
        }
    }
}

private extension CheckState {
    var color: Color {
        switch self {
        case .success: return .green
        case .failure: return .red
        case .pending: return .orange
        case .none: return .gray
        }
    }

    var label: String {
        switch self {
        case .success: return "CI passing"
        case .failure: return "CI failing"
        case .pending: return "CI pending"
        case .none: return "No CI"
        }
    }
}

private struct PRRow: View {
    let pr: PullRequest
    let people: [Person]
    let reviewersToAddress: [String]
    @State private var showBranch = false

    var body: some View {
        Button {
            if let url = URL(string: pr.url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Group {
                    if pr.hasConflicts {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Merge conflicts")
                    } else {
                        Circle()
                            .fill(pr.checkState.color)
                            .frame(width: 9, height: 9)
                            .help(pr.checkState.label)
                    }
                }
                .frame(width: 12, height: 12)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pr.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !reviewersToAddress.isEmpty {
                        ToAddressBadge(reviewers: reviewersToAddress)
                    }

                    if !pr.labelList.isEmpty {
                        LabelCluster(labels: pr.labelList)
                    }

                    HStack(spacing: 6) {
                        Text("#\(pr.number)")

                        Image(systemName: "arrow.triangle.branch")
                            .padding(.horizontal, 2)
                            .onHover { showBranch = $0 }

                        if pr.isDraft {
                            Text("draft")
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        if pr.reviewStatus != .none {
                            Image(systemName: pr.reviewStatus.icon)
                                .foregroundStyle(pr.reviewStatus.color)
                                .help(pr.reviewStatus.label)
                        }

                        Spacer()

                        AvatarCluster(people: people)

                        Text(pr.relativeAge)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    if showBranch {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                            Text("\(pr.headRefName) → \(pr.baseRefName)")
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
