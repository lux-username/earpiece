import Foundation

/// TEMPLATE — copy this file into the `earpiece/` folder as `Secrets.swift` and
/// paste your own OpenAI API key. It lives at the repo root (not inside `earpiece/`)
/// on purpose: that folder is a synchronized group where every `.swift` gets
/// compiled, so a second `enum Secrets` there would collide with the real one.
/// `earpiece/Secrets.swift` is git-ignored, so your real key never leaves your
/// machine; this placeholder is the version that's safe to commit.
///
/// ▸ Get a key at https://platform.openai.com/api-keys (it starts with "sk-...").
/// ▸ Paste it in Xcode — never into a chat, a commit, or a screenshot.
enum Secrets {
    static let openAIKey = "PASTE_YOUR_OPENAI_KEY_HERE"
}
