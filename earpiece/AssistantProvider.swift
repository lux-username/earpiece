import Foundation

/// The thin provider seam (BUILDLOG Entry 5). The app talks to "an assistant"
/// through this protocol and never to a specific vendor directly. Pointing the
/// earpiece at a different backend later means writing ONE new type that conforms
/// to this — no changes to the recording loop or UI.
///
/// The three steps mirror the loop: hear it, think about it, say it back.
protocol AssistantProvider {
    /// Speech → text. Give it the recorded audio file; get back what was said.
    func transcribe(audioURL: URL) async throws -> String

    /// Text → text. The reasoning step (with web search, in the OpenAI impl).
    func respond(to question: String) async throws -> String

    /// Text → spoken audio, *streamed*. Yields raw PCM chunks as they're generated, so
    /// playback can begin on the first chunk instead of waiting for a whole file. The
    /// PCM is 16-bit signed, mono, little-endian, at `ttsSampleRate`.
    func synthesizeStream(_ text: String) -> AsyncThrowingStream<Data, Error>

    /// Sample rate (Hz) of the PCM that `synthesizeStream` yields.
    var ttsSampleRate: Double { get }
}

/// Failures we surface to the on-screen log during testing. `errorDescription`
/// is what shows up in the log line, so keep each one human-readable.
enum AssistantError: LocalizedError {
    case missingAPIKey
    case http(status: Int, body: String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No OpenAI API key set — paste yours into Secrets.swift."
        case .http(let status, let body):
            return "OpenAI HTTP \(status): \(body)"
        case .badResponse(let detail):
            return "Unexpected response: \(detail)"
        }
    }
}
