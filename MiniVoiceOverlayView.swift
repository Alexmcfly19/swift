import SwiftUI
import AVFoundation

/// A compact overlay card displayed at the bottom of the map or feed when a
/// voice annotation is selected. This view presents a small preview of the
/// voice including its title, owner, a play bar and basic reaction
/// controls. The layout and styling are inspired by the provided design
/// screenshot: the avatar, title and close button appear in a header row,
/// followed by an audio waveform with like/comment counters on the right.
/// Tapping the close button will hide the overlay by toggling the bound
/// `isPresented` value back to `false`. Like and comment counts update
/// immediately in the UI and send API requests when the user is signed in.
struct MiniVoiceOverlayView: View {
    /// The voice being previewed.
    let voice: Voice
    /// Binding to control the presentation of this overlay. When set to
    /// `false` the overlay will dismiss itself.
    @Binding var isPresented: Bool
    /// Provides access to authentication tokens and user identifiers.
    @EnvironmentObject private var app: AppState
    /// Tracks whether the current user has liked this voice. Defaults
    /// to `false` and toggles on tap.
    @State private var isLiked: Bool = false
    /// Local like count. Initialised from the `voice.likes` property and
    /// updated optimistically when the like button is tapped.
    @State private var likeCount: Int
    /// Local comment count. Derived from `voice.commentsCount` and
    /// toggled by tapping the comment button. This is a placeholder until
    /// a full comments feature is implemented.
    @State private var commentCount: Int
    /// Local playback count. Derived from `voice.playCount`. Displayed for
    /// completeness but not currently updated by this overlay.
    @State private var playCount: Int

    /// Custom initialiser to extract initial state values from the voice.
    /// - Parameters:
    ///   - voice: The voice to display.
    ///   - isPresented: A binding controlling whether the overlay is shown.
    init(voice: Voice, isPresented: Binding<Bool>) {
        self.voice = voice
        self._isPresented = isPresented
        _likeCount = State(initialValue: voice.likes ?? 0)
        _commentCount = State(initialValue: voice.commentsCount ?? 0)
        _playCount = State(initialValue: voice.playCount ?? 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header row containing avatar, title/owner and close button
            HStack(alignment: .center, spacing: 8) {
                // Display the voice's picture if available; otherwise fall back
                // to the placeholder avatar stored in assets. The avatar is
                // clipped to a circle to match the design.
                Group {
                    if let url = voice.pictureURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Image("placeholder-avatar").resizable().scaledToFill()
                            }
                        }
                    } else {
                        Image("placeholder-avatar").resizable().scaledToFill()
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                // Title and owner information. Limit the title to one line to
                // prevent it from overflowing the available space.
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.title)
                        .font(.headline)
                        .lineLimit(1)
                    if let name = voice.ownerName {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                // Close button. Tapping sets isPresented to false,
                // dismissing the overlay.
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            // Main content row: audio bar on the left and reaction
            // controls on the right. The audio bar expands to fill
            // available width, leaving room for the like/comment stack.
            HStack(alignment: .center, spacing: 12) {
                // Only display the audio bar if a voice URL is present.
                if voice.voiceURL != nil {
                    PostAudioBar(url: voice.voiceURL)
                        .frame(maxWidth: .infinity, maxHeight: 40)
                }
                // Reaction buttons: like and comment. Playback count is
                // omitted here to conserve space but can be added in
                // future iterations. The counts update optimistically.
                HStack(spacing: 16) {
                    Button(action: toggleLike) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .red : .primary)
                            Text(formattedCount(likeCount))
                                .font(.footnote)
                                .foregroundColor(.primary)
                        }
                    }
                    Button(action: toggleComment) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .foregroundColor(.primary)
                            Text(formattedCount(commentCount))
                                .font(.footnote)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        // Padding around the content to provide breathing room within
        // the rounded rectangle. Additional bottom padding ensures
        // separation from the bottom edge of the screen when presented.
        .padding(12)
        .background(
            // Use a semi‑transparent background so the map content
            // beneath is subtly visible, reflecting the designs. The
            // rounded corners mirror other cards in the app.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Convert a numeric count into a compact string representation. Values
    /// are abbreviated using K (thousand) and M (million) units to
    /// conserve space. Negative values default to "0".
    private func formattedCount(_ count: Int) -> String {
        guard count >= 0 else { return "0" }
        if count >= 1_000_000 {
            let m = Double(count) / 1_000_000
            let rounded = (m * 10).rounded() / 10
            if rounded.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0fM", rounded)
            }
            return String(format: "%.1fM", rounded)
        } else if count >= 1_000 {
            let k = Double(count) / 1_000
            let rounded = (k * 10).rounded() / 10
            if rounded.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0fK", rounded)
            }
            return String(format: "%.1fK", rounded)
        } else {
            return String(count)
        }
    }

    /// Handle tapping the like button. When the user is signed in
    /// (`app.token` and `app.currentUserId` are available) an API
    /// request is dispatched to register the like/unlike on the server.
    /// The UI updates immediately regardless of API availability to
    /// provide responsive feedback.
    private func toggleLike() {
        guard let token = app.token, let clientId = app.currentUserId else {
            // Optimistically update the UI when not signed in. This
            // toggles the like state and adjusts the count accordingly.
            if isLiked {
                likeCount = max(0, likeCount - 1)
            } else {
                likeCount += 1
            }
            isLiked.toggle()
            return
        }
        // When the user is signed in, toggle the like state and send
        // the appropriate API request in the background. The counts
        // update immediately for snappy feedback.
        if isLiked {
            likeCount = max(0, likeCount - 1)
            isLiked = false
            Task {
                try? await APIClient.shared.unlikeVoice(voiceId: voice.id, clientId: clientId, token: token)
            }
        } else {
            likeCount += 1
            isLiked = true
            Task {
                try? await APIClient.shared.likeVoice(voiceId: voice.id, clientId: clientId, token: token)
            }
        }
    }

    /// Toggle the comment count locally. This is a placeholder action that
    /// simply increments or decrements the displayed comment count. In a
    /// future iteration this could present a comments view or composer.
    private func toggleComment() {
        if commentCount > 0 {
            commentCount -= 1
        } else {
            commentCount += 1
        }
    }
}