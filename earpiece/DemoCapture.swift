import Foundation

/// DEMO-BUILD ONLY — this file lives on the `demo` git branch and must never reach
/// `main`. It captures a full exchange (your spoken query, the AI's spoken answer,
/// and the transcript) to disk so the audio can be laid over a screen recording when
/// making a demo video. The shipping app on `main` has none of this: the mic serves
/// live queries only, and nothing is persisted beyond the transient query file.
///
/// Keeping it in its own file (rather than scattered through the controller) means
/// the demo-vs-shipping difference is one self-contained, obvious unit — easy to
/// audit, and impossible to leave half-merged into main by accident.
enum DemoCapture {

    /// Save one exchange into a timestamped folder in Documents and return the files
    /// produced, ready to hand to a share sheet.
    /// - queryAudio: the `.m4a` the recorder already wrote (your voice).
    /// - answerPCM: the raw 16-bit signed mono little-endian PCM streamed from TTS.
    static func saveSession(queryAudio: URL?,
                            answerPCM: Data,
                            sampleRate: Double,
                            question: String,
                            answer: String) -> [URL] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stamp = Date().formatted(.iso8601.dateSeparator(.dash).timeSeparator(.omitted))
        let folder = docs.appendingPathComponent("demo-\(stamp)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var files: [URL] = []

        // 1) Your query audio — copy the recorder's file in alongside the rest.
        if let queryAudio {
            let dest = folder.appendingPathComponent("query.m4a")
            try? FileManager.default.copyItem(at: queryAudio, to: dest)
            if FileManager.default.fileExists(atPath: dest.path) { files.append(dest) }
        }

        // 2) The answer audio — wrap the streamed PCM in a WAV header so any editor
        //    (iMovie, CapCut…) opens it directly.
        if !answerPCM.isEmpty {
            let answerURL = folder.appendingPathComponent("answer.wav")
            if (try? wav(from: answerPCM, sampleRate: sampleRate).write(to: answerURL)) != nil {
                files.append(answerURL)
            }
        }

        // 3) The transcript — for on-screen captions in the edit.
        let transcript = "Q: \(question)\n\nA: \(answer)\n"
        let textURL = folder.appendingPathComponent("transcript.txt")
        if (try? transcript.write(to: textURL, atomically: true, encoding: .utf8)) != nil {
            files.append(textURL)
        }

        return files
    }

    /// Wrap raw 16-bit signed mono little-endian PCM in a minimal WAV container.
    private static func wav(from pcm: Data, sampleRate: Double) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let rate = UInt32(sampleRate)
        let byteRate = rate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcm.count)

        var d = Data()
        func ascii(_ s: String) { d.append(s.data(using: .ascii)!) }
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }

        ascii("RIFF"); u32(36 + dataSize); ascii("WAVE")              // RIFF header
        ascii("fmt "); u32(16); u16(1); u16(channels)                // fmt chunk (1 = PCM)
        u32(rate); u32(byteRate); u16(blockAlign); u16(bitsPerSample)
        ascii("data"); u32(dataSize); d.append(pcm)                  // data chunk
        return d
    }
}
