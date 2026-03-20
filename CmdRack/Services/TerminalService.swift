//
//  TerminalService.swift
//  CmdRack
//
//  Runs commands in the user's preferred terminal via osascript.
//  Supports Terminal.app, iTerm2, Warp, and Kitty.
//

import AppKit

enum TerminalService {

    // MARK: - Public API

    /// Run a command string in the given terminal.
    /// If `previousApp` is a supported terminal, it's used instead of `preferred`.
    static func run(
        _ command: String,
        preferred: PreferredTerminal,
        previousApp: NSRunningApplication? = nil
    ) {
        let terminal = resolvedTerminal(preferred: preferred, previousApp: previousApp)
        executeInTerminal(command, terminal: terminal)
    }

    // MARK: - Smart detection

    /// Map of known terminal bundle IDs to our enum.
    private static let knownTerminals: [String: PreferredTerminal] = {
        var map: [String: PreferredTerminal] = [:]
        for t in PreferredTerminal.allCases {
            map[t.bundleIdentifier] = t
        }
        return map
    }()

    /// Returns the display name of the terminal that would be used.
    static func resolvedTerminalName(
        preferred: PreferredTerminal,
        previousApp: NSRunningApplication?
    ) -> String {
        resolvedTerminal(preferred: preferred, previousApp: previousApp).displayName
    }

    /// If the previously-active app is a recognised terminal, use that; otherwise fall back to preferred.
    private static func resolvedTerminal(
        preferred: PreferredTerminal,
        previousApp: NSRunningApplication?
    ) -> PreferredTerminal {
        if let bundleID = previousApp?.bundleIdentifier,
           let detected = knownTerminals[bundleID] {
            return detected
        }
        return preferred
    }

    // MARK: - Execution via osascript

    private static func executeInTerminal(_ command: String, terminal: PreferredTerminal) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script: String
        switch terminal {
        case .terminal:
            script = """
            tell application "Terminal"
                activate
                if (count of windows) > 0 then
                    do script "\(escaped)" in front window
                else
                    do script "\(escaped)"
                end if
            end tell
            """

        case .iterm2:
            script = """
            tell application "iTerm2"
                activate
                if (count of windows) > 0 then
                    tell current session of current window
                        write text "\(escaped)"
                    end tell
                else
                    create window with default profile
                    tell current session of current window
                        write text "\(escaped)"
                    end tell
                end if
            end tell
            """

        case .warp:
            script = """
            tell application "Warp"
                activate
            end tell
            delay 0.3
            tell application "System Events"
                tell process "Warp"
                    keystroke "\(escaped)"
                    keystroke return
                end tell
            end tell
            """

        case .kitty:
            script = """
            do shell script "/Applications/kitty.app/Contents/MacOS/kitty @ --to unix:/tmp/kitty send-text '\(command.replacingOccurrences(of: "'", with: "'\\''"))\\n'" & " || " & "open -a kitty"
            """

        case .ghostty:
            // Ghostty supports AppleScript
            script = """
            tell application "Ghostty"
                activate
            end tell
            delay 0.3
            tell application "System Events"
                tell process "Ghostty"
                    keystroke "\(escaped)"
                    keystroke return
                end tell
            end tell
            """

        case .alacritty:
            // Alacritty has no AppleScript dictionary — activate and type via System Events
            script = """
            tell application "Alacritty"
                activate
            end tell
            delay 0.3
            tell application "System Events"
                tell process "alacritty"
                    keystroke "\(escaped)"
                    keystroke return
                end tell
            end tell
            """
        }

        // Use osascript process instead of NSAppleScript — works reliably
        // in both debug (Xcode) and release builds without permission issues.
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]

            let errorPipe = Pipe()
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    print("[TerminalService] osascript error: \(errorString)")
                }
            } catch {
                print("[TerminalService] Failed to launch osascript: \(error)")
            }
        }
    }
}
