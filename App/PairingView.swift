import SwiftUI
import LoveWidgetCore

struct PairingView: View {

    var canvasViewModel: CanvasViewModel
    let syncEngine: SyncEngine?
    let supabaseClient: SupabaseClientActor?

    @State private var inviteCode: String = ""
    @State private var displayName: String = ""
    @State private var generatedCode: String?
    @State private var isCreating = false
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var pairState: PairLocalState?
    @State private var notification: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let pair = pairState, pair.isPaired {
                pairedView(pair)
            } else if let code = generatedCode, pairState != nil {
                waitingView(code)
            } else {
                pairingOptions
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Image(systemName: "person.2.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
            Text("Pair")
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var pairingOptions: some View {
        HStack(spacing: 24) {
            joinSection
            Divider()
                .frame(width: 1)
            createSection
        }
        .padding(24)
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Join a Pair")
                .font(.system(size: 14, weight: .semibold))

            TextField("Invite Code (XXX-XXXX)", text: $inviteCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))

            TextField("Your Name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            Button(action: joinPair) {
                if isJoining {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Join")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isJoining || inviteCode.isEmpty || displayName.isEmpty)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create a Pair")
                .font(.system(size: 14, weight: .semibold))

            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)

            Text("Generate a code to share with your partner")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Your Name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            Button(action: createPair) {
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Create")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCreating || displayName.isEmpty)
        }
    }

    private func waitingView(_ code: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)

            Text("Share this code")
                .font(.title2.weight(.semibold))

            Text(code)
                .font(.system(size: 36, design: .monospaced))
                .fontWeight(.bold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

            Text("Waiting for partner to join...")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView()
                .scaleEffect(0.8)

            Button("Cancel", role: .destructive) {
                generatedCode = nil
                pairState = nil
            }
            .padding(.top, 8)
        }
        .padding(40)
    }

    private func pairedView(_ pair: PairLocalState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Connected!")
                .font(.title2.weight(.semibold))

            if !pair.partnerDisplayName.isEmpty {
                Text("Paired with \(pair.partnerDisplayName)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Text("Send a drawing!")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Reset Pair", role: .destructive) {
                Task { await resetPair() }
            }
            .padding(.top, 8)
        }
        .padding(40)
    }

    private func createPair() {
        Task {
            isCreating = true
            errorMessage = nil
            do {
                let code = InviteCodeGenerator.generate()
                generatedCode = code
                // In a real app, this would call supabase to create the pair
                // For now, we simulate
                pairState = PairLocalState(
                    pairID: UUID(),
                    partnerID: nil,
                    partnerName: nil,
                    inviteCode: code
                )
            }
            isCreating = false
        }
    }

    private func joinPair() {
        Task {
            isJoining = true
            errorMessage = nil
            do {
                // Validate and join
                guard inviteCode.range(of: "^[A-Z2-9]{3}-[A-Z2-9]{4}$", options: .regularExpression) != nil else {
                    errorMessage = "Invalid code format. Use XXX-XXXX"
                    isJoining = false
                    return
                }
                // In a real app, this would call supabase to join
                // For now, we simulate
                pairState = PairLocalState(
                    pairID: UUID(),
                    partnerID: UUID(),
                    partnerName: displayName.isEmpty ? nil : displayName,
                    inviteCode: inviteCode
                )
                canvasViewModel.partnerName = displayName
            }
            isJoining = false
        }
    }

    private func resetPair() async {
        guard supabaseClient != nil else { return }
        do {
            await syncEngine?.stop()
            try AppGroupStorage.shared.clearPair()
            pairState = nil
            generatedCode = nil
            inviteCode = ""
            canvasViewModel.partnerName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
