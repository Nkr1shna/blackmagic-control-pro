import XCTest
@testable import BlackmagicControl

final class RestEventStreamTests: XCTestCase {
    func testReconnectCancelsPreviousWebSocketBeforeStartingNewOne() {
        var lifecycleEvents: [String] = []
        let firstTask = FakeRestWebSocketTask {
            lifecycleEvents.append("cancel first")
        }
        let secondTask = FakeRestWebSocketTask()
        var requestedURLs: [URL] = []
        var taskQueue: [FakeRestWebSocketTask] = [firstTask, secondTask]
        let stream = RestEventStream(
            baseURL: URL(string: "http://192.168.0.10")!,
            webSocketTaskFactory: { url in
                requestedURLs.append(url)
                lifecycleEvents.append("create task")
                return taskQueue.removeFirst()
            }
        )

        stream.connect { _ in XCTFail("Unexpected event") }
        stream.connect { _ in XCTFail("Unexpected event") }

        XCTAssertEqual(requestedURLs.map { $0.absoluteString }, [
            "ws://192.168.0.10/control/api/v1/event/websocket",
            "ws://192.168.0.10/control/api/v1/event/websocket"
        ])
        XCTAssertEqual(firstTask.resumeCallCount, 1)
        XCTAssertEqual(firstTask.cancelCode, .goingAway)
        XCTAssertNil(firstTask.cancelReason)
        XCTAssertEqual(secondTask.resumeCallCount, 1)
        XCTAssertNil(secondTask.cancelCode)
        XCTAssertEqual(lifecycleEvents, ["create task", "cancel first", "create task"])
    }

    func testReceiveFailureClearsCurrentTaskAndStopsReceiving() {
        let task = FakeRestWebSocketTask()
        let stream = RestEventStream(
            baseURL: URL(string: "https://192.168.0.10")!,
            webSocketTaskFactory: { _ in task }
        )

        stream.connect { _ in XCTFail("Unexpected event") }
        task.completeReceive(.failure(RestEventStreamTestError.receiveFailed))
        stream.disconnect()

        XCTAssertEqual(task.receiveCallCount, 1)
        XCTAssertNil(task.cancelCode)
    }

    func testConnectSendsCorePropertySubscription() throws {
        let task = FakeRestWebSocketTask()
        let stream = RestEventStream(
            baseURL: URL(string: "http://192.168.0.10")!,
            webSocketTaskFactory: { _ in task }
        )

        stream.connect { _ in XCTFail("Unexpected event") }

        XCTAssertEqual(task.sentStrings.count, 1)

        let data = try XCTUnwrap(task.sentStrings.first?.data(using: .utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messageData = try XCTUnwrap(json["data"] as? [String: Any])

        XCTAssertNil(json["action"])
        XCTAssertNil(json["properties"])
        XCTAssertEqual(json["type"] as? String, "request")
        XCTAssertEqual(messageData["action"] as? String, "subscribe")
        XCTAssertEqual(messageData["properties"] as? [String], [
            "/transports/0/record",
            "/transports/0/timecode",
            "/media/workingset",
            "/media/active",
            "/camera/power",
            "/video/iso",
            "/video/shutter",
            "/video/whiteBalance",
            "/video/whiteBalanceTint",
            "/lens/iris",
            "/lens/focus",
            "/lens/focus/description"
        ])
    }

    func testEventMessageDecodesActionPropertyDataAndType() throws {
        let json = """
        {
            "data": {
                "action": "update",
                "property": "camera.whiteBalance"
            },
            "type": "property"
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(RestEventMessage.self, from: json)

        XCTAssertEqual(
            message,
            RestEventMessage(
                data: RestEventMessage.Payload(
                    action: "update",
                    property: "camera.whiteBalance"
                ),
                type: "property"
            )
        )
    }

    func testEventMessageAllowsMissingProperty() throws {
        let json = """
        {
            "data": {
                "action": "ping"
            },
            "type": "heartbeat"
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(RestEventMessage.self, from: json)

        XCTAssertEqual(message.data.action, "ping")
        XCTAssertNil(message.data.property)
        XCTAssertEqual(message.type, "heartbeat")
    }
}

private final class FakeRestWebSocketTask: RestWebSocketTask {
    private let onCancel: () -> Void
    private var receiveCompletions: [(Result<URLSessionWebSocketTask.Message, Error>) -> Void] = []
    private(set) var receiveCallCount = 0
    private(set) var resumeCallCount = 0
    private(set) var cancelCode: URLSessionWebSocketTask.CloseCode?
    private(set) var cancelReason: Data?
    private(set) var sentStrings: [String] = []

    init(onCancel: @escaping () -> Void = {}) {
        self.onCancel = onCancel
    }

    func resume() {
        resumeCallCount += 1
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        cancelCode = closeCode
        cancelReason = reason
        onCancel()
    }

    func receive(
        completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    ) {
        receiveCallCount += 1
        receiveCompletions.append(completionHandler)
    }

    func send(
        _ message: URLSessionWebSocketTask.Message,
        completionHandler: @escaping (Error?) -> Void
    ) {
        if case let .string(string) = message {
            sentStrings.append(string)
        }
        completionHandler(nil)
    }

    func completeReceive(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        guard !receiveCompletions.isEmpty else {
            XCTFail("No pending receive completion")
            return
        }

        let completion = receiveCompletions.removeFirst()
        completion(result)
    }
}

private enum RestEventStreamTestError: Error {
    case receiveFailed
}
