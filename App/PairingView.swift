import SwiftUI
import LoveWidgetCore

struct PairingView: View {

    var canvasViewModel: CanvasViewModel
    let syncEngine: SyncEngine?
    let supabaseClient: SupabaseClientActor?
    let userRepo: UserRepository?
    let pairRepo: PairRepository?

    @State private var inviteCode: String = ""
    @State private var displayName: String = ""
    @State private var generatedCode: String?
    @State private var isCreating = false
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var pairState: PairLocalState?
    @State private var currentUser: AppUser?
    @State private var currentPair: Pair?
    @State private var pollTask: Task<Void, Never>?

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
        .onAppear {
            loadExistingState()
            startPollingIfNeeded()
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
        }
    }

    private func loadExistingState() {
        let settings = (try? AppGroupStorage.shared.loadSettings()) ?? AppUserSettings()
        if !settings.displayName.isEmpty {
            displayName = settings.displayName
        }
        pairState = try? AppGroupStorage.shared.loadPair()
    }

    private func startPollingIfNeeded() {
        guard generatedCode != nil, pairState?.isPaired != true else { return }
        pollTask?.cancel()
        pollTask = Task { await pollForPartner() }
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

            HStack(spacing: 8) {
                Text(code)
                    .font(.system(size: 36, design: .monospaced))
                    .fontWeight(.bold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )

                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(code, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                }
                .buttonStyle(.bordered)
                .help("Copy code")
            }

            Text("Waiting for partner to join...")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView()
                .scaleEffect(0.8)

            Button("Cancel", role: .destructive) {
                cancelPairCreation()
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
                guard let repo = userRepo, let pairRepo else {
                    throw PairRepositoryError.notPaired
                }

                try await supabaseClient?.ensureAuthenticated()
                let user = try await repo.createOrFetchUser(
                    name: displayName,
                    deviceID: DeviceIdentifier.current
                )
                currentUser = user
                saveUserSettings(userID: user.id)

                let pair = try await pairRepo.createPair(userOneID: user.id)
                currentPair = pair

                let localState = PairLocalState(
                    pairID: pair.id,
                    partnerID: nil,
                    partnerName: nil,
                    inviteCode: pair.inviteCode
                )
                try AppGroupStorage.shared.savePair(localState)
                pairState = localState
                generatedCode = pair.inviteCode
                startPollingIfNeeded()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }

    private func joinPair() {
        Task {
            isJoining = true
            errorMessage = nil
            do {
                guard let repo = userRepo, let pairRepo else {
                    throw PairRepositoryError.notPaired
                }

                let normalized = InviteCodeGenerator.normalize(inviteCode)
                guard InviteCodeGenerator.isValid(normalized) else {
                    throw PairRepositoryError.invalidInviteCode(inviteCode)
                }

                try await supabaseClient?.ensureAuthenticated()
                let user = try await repo.createOrFetchUser(
                    name: displayName,
                    deviceID: DeviceIdentifier.current
                )
                currentUser = user
                saveUserSettings(userID: user.id)

                let pair = try await pairRepo.joinPair(
                    inviteCode: normalized,
                    userTwoID: user.id
                )
                currentPair = pair

                let partner = try? await repo.fetchUser(id: pair.userOneID)
                let partnerName = partner?.name

                let localState = PairLocalState(
                    pairID: pair.id,
                    partnerID: pair.userOneID,
                    partnerName: partnerName,
                    inviteCode: pair.inviteCode
                )
                try AppGroupStorage.shared.savePair(localState)
                pairState = localState
                canvasViewModel.partnerName = partnerName ?? "Your Partner"

                await syncEngine?.start(pairID: pair.id, userID: user.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            isJoining = false
        }
    }

    private func pollForPartner() async {
        guard let pairRepo, let pair = currentPair else { return }

        while !Task.isCancelled {
            do {
                if let updated = try await pairRepo.fetchPair(id: pair.id),
                   let partnerID = updated.userTwoID {
                    let partner = try? await userRepo?.fetchUser(id: partnerID)
                    let partnerName = partner?.name

                    let localState = PairLocalState(
                        pairID: updated.id,
                        partnerID: partnerID,
                        partnerName: partnerName,
                        inviteCode: updated.inviteCode
                    )
                    try? AppGroupStorage.shared.savePair(localState)

                    await MainActor.run {
                        self.pairState = localState
                        self.canvasViewModel.partnerName = partnerName ?? "Your Partner"
                        self.currentPair = updated
                    }

                    if let userID = currentUser?.id {
                        await syncEngine?.start(pairID: updated.id, userID: userID)
                    }
                    return
                }
            } catch {
                // Retry silently
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    private func cancelPairCreation() {
        generatedCode = nil
        pairState = nil
        pollTask?.cancel()
        pollTask = nil
        if let pair = currentPair {
            Task {
                try? await pairRepo?.deletePair(id: pair.id)
            }
        }
        currentPair = nil
    }

    private func resetPair() async {
        await syncEngine?.stop()
        if let pairRepo, let pair = pairState {
            // Best-effort remote delete (may fail if RLS policy missing)
            try? await pairRepo.deletePair(id: pair.pairID)
        }
        try? AppGroupStorage.shared.clearPair()
        await MainActor.run {
            pairState = nil
            generatedCode = nil
            inviteCode = ""
            currentUser = nil
            currentPair = nil
            canvasViewModel.partnerName = ""
            errorMessage = nil
        }
    }

    private func saveUserSettings(userID: UUID) {
        var settings = (try? AppGroupStorage.shared.loadSettings()) ?? AppUserSettings()
        settings.userID = userID
        settings.displayName = displayName
        try? AppGroupStorage.shared.saveSettings(settings)
    }
}
