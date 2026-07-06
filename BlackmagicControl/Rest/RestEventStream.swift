import Foundation

struct RestEventMessage: Decodable, Equatable {
    struct Payload: Decodable, Equatable {
        let action: String
        let property: String?
    }

    let data: Payload
    let type: String
}

protocol RestWebSocketTask: AnyObject {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func receive(
        completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    )
}

extension URLSessionWebSocketTask: RestWebSocketTask {}

final class RestEventStream {
    private let baseURL: URL
    private let urlSession: URLSession
    private let webSocketTaskFactory: ((URL) -> RestWebSocketTask)?
    private var webSocketTask: RestWebSocketTask?

    init(
        baseURL: URL,
        urlSession: URLSession = .shared,
        webSocketTaskFactory: ((URL) -> RestWebSocketTask)? = nil
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.webSocketTaskFactory = webSocketTaskFactory
    }

    func connect(onEvent: @escaping (RestEventMessage) -> Void) {
        disconnect()

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = webSocketScheme(for: components?.scheme)
        components?.path = "/control/api/v1/event/websocket"

        guard let webSocketURL = components?.url else {
            return
        }

        let task = webSocketTaskFactory?(webSocketURL) ?? urlSession.webSocketTask(with: webSocketURL)
        webSocketTask = task
        task.resume()
        receive(onEvent: onEvent)
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func receive(onEvent: @escaping (RestEventMessage) -> Void) {
        guard let task = webSocketTask else {
            return
        }

        task.receive { [weak self] result in
            guard let self = self, self.webSocketTask === task else {
                return
            }

            switch result {
            case .success(let message):
                if case let .string(json) = message,
                   let data = json.data(using: .utf8),
                   let event = try? JSONDecoder().decode(RestEventMessage.self, from: data) {
                    onEvent(event)
                }
            case .failure:
                self.webSocketTask = nil
                return
            }

            guard self.webSocketTask === task else {
                return
            }

            self.receive(onEvent: onEvent)
        }
    }

    private func webSocketScheme(for scheme: String?) -> String? {
        switch scheme {
        case "http":
            return "ws"
        case "https":
            return "wss"
        default:
            return scheme
        }
    }
}
