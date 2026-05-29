import Foundation

/// OpenAI implementation of `AssistantProvider`: the whole voice stack on one
/// vendor (BUILDLOG Entry 5). Three raw REST calls — no SDK — so there's nothing
/// to keep in sync but the endpoints themselves:
///   • audio/transcriptions  (speech → text)
///   • responses             (text → text, with the built-in web-search tool)
///   • audio/speech          (text → spoken audio)
///
/// Models are the "balanced, voice-first" tier: good speech models, cheap
/// reasoning. Each is a one-line constant — change it here, nowhere else.
struct OpenAIProvider: AssistantProvider {

    // MARK: Tuning knobs (swap any of these freely)
    static let transcriptionModel = "gpt-4o-mini-transcribe"
    static let reasoningModel     = "gpt-4o-mini"
    static let ttsModel           = "gpt-4o-mini-tts"
    static let ttsVoice           = "alloy"   // try "shimmer", "nova", "echo", …

    /// OpenAI's `pcm` TTS output is 24 kHz, 16-bit signed, mono, little-endian.
    var ttsSampleRate: Double { 24_000 }

    /// The reply will be HEARD, not read — so we steer the model away from its
    /// default lists-and-markdown style toward short, plain spoken sentences.
    static let systemPrompt = """
    You are the assistant inside a small, discreet earpiece. The user spoke a \
    question out loud and will HEAR your reply through the earpiece — they cannot \
    see a screen. Answer in one or two short, natural spoken sentences. Do not use \
    lists, markdown, headings, or emoji. If you needed the web, state the key fact \
    plainly. Never read out URLs, web addresses, or links — spoken aloud they're \
    just noise; if naming a source helps, say it in plain words (e.g. "according \
    to the BBC") but never spell out the address. If you don't know, say so \
    briefly rather than guessing.
    """

    private let baseURL = URL(string: "https://api.openai.com/v1/")!

    // MARK: AssistantProvider

    func transcribe(audioURL: URL) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try authorizedRequest(path: "audio/transcriptions")
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        // Build the multipart body: the model name, then the audio file.
        let audio = try Data(contentsOf: audioURL)
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.appendString("\(Self.transcriptionModel)\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n")
        body.appendString("Content-Type: audio/m4a\r\n\r\n")
        body.append(audio)
        body.appendString("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let data = try await perform(request)
        struct Transcription: Decodable { let text: String }
        guard let result = try? JSONDecoder().decode(Transcription.self, from: data) else {
            throw AssistantError.badResponse(Self.preview(data))
        }
        return result.text
    }

    func respond(to question: String) async throws -> String {
        var request = try authorizedRequest(path: "responses")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // The model's training is frozen in time and it has no built-in clock, so left
        // to itself it hedges — "I can't know that", "my info may be out of date",
        // "check a calendar / look it up yourself" — on anything current. But it CAN
        // web-search, so we give it a standing rule to search rather than refuse, and
        // also hand it today's real date (read from the device, fresh each call) so the
        // common "what's the date?" doesn't even need a search.
        let today = Date().formatted(date: .complete, time: .omitted)
        let instructions = """
        \(Self.systemPrompt)

        You have a web-search tool, so you are not limited to what you were trained \
        on. Never tell the user you can't know something, that your information might \
        be out of date, or that they should look it up themselves — if a question can \
        be answered by searching the web, search and then state the answer out loud in \
        plain words. When you search, never read the source's URL, web address, or link \
        aloud — give the fact, and at most name the source plainly (e.g. "the BBC \
        reports…"). For reference, today's date is \(today).
        """

        let payload: [String: Any] = [
            "model": Self.reasoningModel,
            "instructions": instructions,
            "input": question,
            "tools": [["type": "web_search"]]   // server-side search; the model decides when to use it
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data = try await perform(request)
        // Backstop the prompt's "don't read links aloud" rule: strip any URLs the model
        // slipped in before the text is spoken. It slips most on long, search-heavy
        // answers — prompt steering alone was never going to be airtight here.
        return Self.removingLinks(from: try Self.extractText(from: data))
    }

    func synthesizeStream(_ text: String) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = try authorizedRequest(path: "audio/speech")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let payload: [String: Any] = [
                        "model": Self.ttsModel,
                        "voice": Self.ttsVoice,
                        "input": text,
                        // Raw PCM (no container) so it plays as it streams; mp3 would
                        // need the whole file before the first sample is decodable.
                        "response_format": "pcm"
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AssistantError.badResponse("no HTTP response")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        // Non-2xx: the body is the error JSON — collect it for the message.
                        var body = Data()
                        for try await b in bytes { body.append(b) }
                        throw AssistantError.http(status: http.statusCode, body: Self.preview(body))
                    }

                    // Forward PCM in ~0.2s chunks (9600 bytes = 4800 samples @ 24kHz/16-bit).
                    var chunk = Data(); chunk.reserveCapacity(9600)
                    for try await byte in bytes {
                        chunk.append(byte)
                        if chunk.count >= 9600 {
                            continuation.yield(chunk)
                            chunk.removeAll(keepingCapacity: true)
                        }
                    }
                    if !chunk.isEmpty { continuation.yield(chunk) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Plumbing

    private func authorizedRequest(path: String) throws -> URLRequest {
        let key = Secrets.openAIKey
        guard !key.isEmpty, key != "PASTE_YOUR_OPENAI_KEY_HERE" else {
            throw AssistantError.missingAPIKey
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AssistantError.badResponse("no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AssistantError.http(status: http.statusCode, body: Self.preview(data))
        }
        return data
    }

    /// Remove web links from the answer before it's spoken — the in-code backstop to
    /// the prompt rule. Markdown links keep their visible label; bare http(s)/www links
    /// are dropped; then we tidy the brackets, doubled spaces, and orphaned punctuation
    /// they leave behind. Not grammar-perfect, but a rare bit of debris beats a URL read
    /// aloud letter by letter.
    private static func removingLinks(from text: String) -> String {
        func sub(_ pattern: String, _ replacement: String, in s: String) -> String {
            s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        var s = text
        s = sub(#"\[([^\]]+)\]\((?:https?://|www\.)[^)]*\)"#, "$1", in: s)  // [label](url) -> label
        s = sub(#"(?:https?://|www\.)[^\s)]+"#, "", in: s)                  // bare url -> gone
        s = sub(#"\(\s*\)"#, "", in: s)                                     // empty () left behind
        s = sub(#"\s+([.,;:!?])"#, "$1", in: s)                            // " ." -> "."
        s = sub(#"[ \t]{2,}"#, " ", in: s)                                 // collapse double spaces
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pull the assistant's text out of a Responses API payload. Its `output` is
    /// an array of items; we want the message item's `output_text` parts. (Tool
    /// calls like web search appear as their own items and are skipped here.)
    private static func extractText(from data: Data) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = root["output"] as? [[String: Any]] else {
            throw AssistantError.badResponse(preview(data))
        }
        var text = ""
        for item in output where (item["type"] as? String) == "message" {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for part in content where (part["type"] as? String) == "output_text" {
                if let chunk = part["text"] as? String { text += chunk }
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AssistantError.badResponse(preview(data)) }
        return trimmed
    }

    /// A short, log-friendly snippet of a response body (used in error messages).
    private static func preview(_ data: Data) -> String {
        let text = String(data: data, encoding: .utf8) ?? "<non-text response>"
        return text.count > 300 ? String(text.prefix(300)) + "…" : text
    }
}

private extension Data {
    /// Append a UTF-8 string — handy for assembling multipart request bodies.
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
