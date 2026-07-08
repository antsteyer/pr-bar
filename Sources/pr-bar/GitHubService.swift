import Foundation

enum GitHubError: LocalizedError {
    case process(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .process(let message): return message
        case .decoding(let message): return "Unreadable response: \(message)"
        }
    }
}

/// Thin wrapper around the already-authenticated `gh` CLI.
/// A GUI app does not inherit the shell `PATH`, so we use an absolute path.
struct GitHubService: Sendable {
    var ghPath = "/opt/homebrew/bin/gh"

    func fetch() throws -> PRBuckets {
        let me = try login()
        let data = try run([
            "api", "graphql",
            "-f", "query=\(Self.query(login: me))",
        ])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let response = try decoder.decode(GraphQLResponse.self, from: data)
            return PRBuckets(
                reviewRequested: response.data.reviewRequested.nodes,
                authored: response.data.authored.nodes,
                me: me
            )
        } catch {
            throw GitHubError.decoding(error.localizedDescription)
        }
    }

    private func login() throws -> String {
        let data = try run(["api", "user", "--jq", ".login"])
        let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value
    }

    private func run(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw GitHubError.process("Could not launch gh (\(ghPath)): \(error.localizedDescription)")
        }

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let message = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw GitHubError.process(message?.isEmpty == false ? message! : "gh failed (code \(process.terminationStatus))")
        }
        return output
    }

    private static func query(login: String) -> String {
        """
        query {
          reviewRequested: search(query: "is:open is:pr review-requested:\(login) -author:\(login)", type: ISSUE, first: 40) {
            nodes { ...prFields }
          }
          authored: search(query: "is:open is:pr author:\(login)", type: ISSUE, first: 40) {
            nodes { ...prFields }
          }
        }
        fragment prFields on PullRequest {
          number
          title
          url
          createdAt
          isDraft
          mergeable
          reviewDecision
          headRefName
          baseRefName
          repository { nameWithOwner }
          author { login }
          commits(last: 1) {
            nodes { commit { statusCheckRollup { state } } }
          }
          assignees(first: 5) {
            nodes { login avatarUrl }
          }
          reviewRequests(first: 5) {
            nodes { requestedReviewer { ... on User { login avatarUrl } } }
          }
          reviews(last: 50) {
            nodes { id state author { login } }
          }
        }
        """
    }
}
