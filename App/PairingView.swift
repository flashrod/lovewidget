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
    @State private var selectedMode: PairMode = .create
    @State private var waitingHeartPulse = false
    @State private var pairedAnimating = false

    enum PairMode: String, CaseIterable {
        case create = "Create"
        case join   = "Join"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let pair = pairState, pair.isPaired {
                pairedView(pair)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let code = generatedCode, pairState != nil {
                waitingView(code)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                unpairedView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: pairState?.isPaired)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: generatedCode)
    }

    private func loadExistingState() {
        let settings = (try? AppGroupStorage.shared.loadSettings()) ?? AppUserSettings()
        if !settings.displayName.isEmpty {
            displayName = settings.displayName
        }
        pairState = try? AppGroupStorage.shared.loadPair()
        if pairState == nil {
            Task { await restorePairFromSupabase() }
        }
    }

    private func restorePairFromSupabase() async {
        guard let pairRepo else { return }
        do {
            try await supabaseClient?.ensureAuthenticated()
            guard let userID = try await userRepo?.createOrFetchUser(
                name: displayName.isEmpty ? "Me" : displayName,
                deviceID: DeviceIdentifier.current
            ).id else { return }
            guard let pair = try await pairRepo.fetchPair(for: userID) else { return }
            let partner: AppUser?
            if let partnerID = pair.userTwoID {
                partner = try? await userRepo?.fetchUser(id: partnerID)
            } else {
                partner = nil
            }
            let localState = PairLocalState(
                pairID: pair.id,
                partnerID: pair.userTwoID,
                partnerName: partner?.name,
                inviteCode: pair.inviteCode
            )
            try? AppGroupStorage.shared.savePair(localState)
            await MainActor.run { self.pairState = localState }
            if pair.userTwoID != nil {
                await syncEngine?.start(pairID: pair.id, userID: userID)
            }
        } catch {}
    }

    private func startPollingIfNeeded() {
        guard generatedCode != nil, pairState?.isPaired != true else { return }
        pollTask?.cancel()
        pollTask = Task { await pollForPartner() }
    }

    // MARK: - Unpaired View

    private var unpairedView: some View {
        VStack(spacing: 0) {
            headerArea

            Picker("Mode", selection: $selectedMode) {
                ForEach(PairMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 48)
            .padding(.bottom, 28)

            switch selectedMode {
            case .create:
                createSection
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .join:
                joinSection
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Spacer()
        }
        .frame(maxWidth: 420)
    }

    private var headerArea: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundStyle(.pink)

            Text("Connect")
                .font(.system(size: 22, weight: .semibold))

            Text("Share a canvas with your partner")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 36)
        .padding(.bottom, 24)
    }

    // MARK: - Create Section

    private var createSection: some View {
        VStack(spacing: 20) {
            formCard {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.pink)

                Text("Create a pair code")
                    .font(.system(size: 15, weight: .medium))

                Text("Share this code with your partner so they can join your canvas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Your Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                Button(action: createPair) {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Create Pair")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(isCreating || displayName.isEmpty)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Join Section

    private var joinSection: some View {
        VStack(spacing: 20) {
            formCard {
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.pink)

                Text("Join a pair")
                    .font(.system(size: 15, weight: .medium))

                Text("Enter the invite code your partner shared with you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    TextField("Invite Code (e.g. ABC-1234)", text: $inviteCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .textCase(.uppercase)
                        .onChange(of: inviteCode) { _, newValue in
                            inviteCode = newValue.uppercased()
                        }

                    TextField("Your Name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

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
                .tint(.pink)
                .disabled(isJoining || inviteCode.count < 5 || displayName.isEmpty)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Waiting View

    private func waitingView(_ code: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 32))
                .foregroundStyle(.pink)
                .scaleEffect(waitingHeartPulse ? 1.15 : 0.85)
                .opacity(waitingHeartPulse ? 1 : 0.6)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        waitingHeartPulse = true
                    }
                }

            Text("Share this code")
                .font(.system(size: 18, weight: .semibold))

            Text("Your partner enters this code to connect.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(code)
                    .font(.system(size: 32, design: .monospaced))
                    .fontWeight(.bold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                            )
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

            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Waiting for partner...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Cancel", role: .destructive) {
                cancelPairCreation()
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: 380)
    }

    // MARK: - Paired View

    private func pairedView(_ pair: PairLocalState) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .scaleEffect(pairedAnimating ? 1 : 0.3)
                .opacity(pairedAnimating ? 1 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        pairedAnimating = true
                    }
                }

            VStack(spacing: 6) {
                Text("Connected!")
                    .font(.system(size: 22, weight: .semibold))

                if !pair.partnerDisplayName.isEmpty {
                    HStack(spacing: 6) {
                        Text("Paired with")
                            .foregroundStyle(.secondary)
                        Text(pair.partnerDisplayName)
                            .fontWeight(.medium)
                    }
                    .font(.body)
                }
            }

            VStack(spacing: 4) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 18))
                    .foregroundStyle(.pink)
                Text("Start drawing on the canvas!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Button("Reset Pair", role: .destructive) {
                Task { await resetPair() }
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: 380)
    }

    // MARK: - Form Card

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16) {
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Actions

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

                let pair: Pair
                if let existing = try await pairRepo.fetchPair(for: user.id) {
                    pair = existing
                } else {
                    do {
                        pair = try await pairRepo.createPair(userOneID: user.id)
                    } catch {
                        if let recovered = try await pairRepo.fetchPair(for: user.id) {
                            pair = recovered
                        } else {
                            throw error
                        }
                    }
                }
                currentPair = pair

                let localState = PairLocalState(
                    pairID: pair.id,
                    partnerID: nil,
                    partnerName: nil,
                    inviteCode: pair.inviteCode
                )
                try? AppGroupStorage.shared.savePair(localState)
                await MainActor.run {
                    self.pairState = localState
                    self.generatedCode = pair.inviteCode
                    self.startPollingIfNeeded()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { self.isCreating = false }
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
                try? AppGroupStorage.shared.savePair(localState)
                await MainActor.run {
                    self.pairState = localState
                    self.canvasViewModel.partnerName = partnerName ?? "Your Partner"
                }

                await syncEngine?.start(pairID: pair.id, userID: user.id)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { self.isJoining = false }
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

    @MainActor
    private func resetPair() async {
        await syncEngine?.stop()
        if let pairRepo, let pair = pairState {
            try? await pairRepo.deletePair(id: pair.pairID)
        }
        try? AppGroupStorage.shared.clearPair()
        try? AppGroupStorage.shared.clearPartnerDrawing()
        try? AppGroupStorage.shared.clearHistory()
        try? AppGroupStorage.shared.clearPendingUpload()
        pairState = nil
        generatedCode = nil
        inviteCode = ""
        currentUser = nil
        currentPair = nil
        canvasViewModel.partnerName = ""
        errorMessage = nil
        canvasViewModel.syncStatus = .idle
    }

    private func saveUserSettings(userID: UUID) {
        var settings = (try? AppGroupStorage.shared.loadSettings()) ?? AppUserSettings()
        settings.userID = userID
        settings.displayName = displayName
        try? AppGroupStorage.shared.saveSettings(settings)
    }
}
