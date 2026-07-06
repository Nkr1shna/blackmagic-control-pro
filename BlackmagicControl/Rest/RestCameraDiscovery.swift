import Foundation

struct RestCameraEndpoint: Equatable {
    let baseURL: URL
}

final class RestCameraDiscovery {
    private let session: URLSession
    private let candidates: [URL]

    init(
        session: URLSession = .shared,
        candidates: [URL] = RestCameraDiscovery.defaultCandidates
    ) {
        self.session = session
        self.candidates = candidates
    }

    func discover() async -> RestCameraEndpoint? {
        for candidate in candidates {
            if await responds(to: candidate) {
                return RestCameraEndpoint(baseURL: candidate)
            }
        }

        return nil
    }

    private func responds(to baseURL: URL) async -> Bool {
        if await responds(to: baseURL, path: "/control/documentation.html") { return true }

        return await responds(to: baseURL, path: "/control/api/v1/system/product") { statusCode in
            (200..<300).contains(statusCode) || statusCode == 501
        }
    }

    private func responds(
        to baseURL: URL,
        path: String,
        accepts statusCodeIsReachable: (Int) -> Bool = { (200..<300).contains($0) }
    ) async -> Bool {
        var request = URLRequest(url: makeURL(baseURL: baseURL, path: path))
        request.timeoutInterval = 1.5

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return statusCodeIsReachable(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    private func makeURL(baseURL: URL, path: String) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.query = nil
        return components.url!
    }

    static let defaultCandidates: [URL] = [
        URL(string: "http://192.168.7.1")!,
        URL(string: "http://192.168.6.1")!,
        URL(string: "http://10.0.0.1")!,
        URL(string: "http://blackmagic.local")!
    ]
}
