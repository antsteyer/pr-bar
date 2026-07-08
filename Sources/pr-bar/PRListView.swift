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

                    section(title: "My PRs", prs: store.authored, emptyText: "No open PRs") { $0.reviewerPeople }
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

    private func section(title: String, prs: [PullRequest], emptyText: String, people: @escaping (PullRequest) -> [Person]) -> some View {
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
                            PRRow(pr: pr, people: people(pr))
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
