;; Fantasy Metaverse League Smart Contract - STAGE 2

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-LEAGUE-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-JOINED (err u102))
(define-constant ERR-DRAFT-CLOSED (err u103))
(define-constant ERR-ATHLETE-NOT-FOUND (err u104))
(define-constant ERR-ATHLETE-ALREADY-DRAFTED (err u105))
(define-constant ERR-SEASON-IN-PROGRESS (err u106))
(define-constant ERR-SEASON-NOT-ACTIVE (err u107))
(define-constant ERR-INVALID-MANAGER (err u108))
(define-constant ERR-INSUFFICIENT-FUNDS (err u109))
(define-constant ERR-INVALID-PARAMETER (err u110))
(define-constant ERR-INVALID-LEAGUE-NAME (err u111))
(define-constant ERR-INVALID-LEAGUE-DESCRIPTION (err u112))
(define-constant ERR-INVALID-ENTRY-FEE (err u113))
(define-constant ERR-INVALID-WEEK-SPAN (err u114))
(define-constant ERR-INVALID-START-WEEK (err u115))
(define-constant ERR-INVALID-MANAGER-LIMIT (err u116))
(define-constant ERR-INSUFFICIENT-MANAGERS (err u117))
(define-constant ERR-SYSTEM-LOCKED (err u118))
(define-constant ERR-INVALID-LEAGUE-ID (err u119))
(define-constant ERR-INVALID-ATHLETE-ID (err u120))
(define-constant ERR-ROSTER-FULL (err u121))
(define-constant ERR-ATHLETE-NOT-AVAILABLE (err u122))
(define-constant ERR-ATHLETE-ALREADY-OWNED (err u123))
(define-constant ERR-INVALID-LEAGUE-PHASE (err u124))
(define-constant ERR-SEASON-NOT-OVER (err u125))

;; League phases
(define-constant PHASE-REGISTRATION u0)
(define-constant PHASE-DRAFT u1)
(define-constant PHASE-SEASON u2)
(define-constant PHASE-COMPLETE u3)

;; Athlete positions
(define-constant POS-QUARTERBACK u1)
(define-constant POS-RUNNING-BACK u2)
(define-constant POS-WIDE-RECEIVER u3)
(define-constant POS-TIGHT-END u4)
(define-constant POS-KICKER u5)
(define-constant POS-DEFENSE u6)

;; Data maps
(define-map leagues
  { league-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 255),
    commissioner: principal,
    phase: uint,
    entry-fee: uint,
    prize-pool: uint,
    start-week: uint,
    end-week: uint,
    manager-limit: uint,
    manager-count: uint,
    roster-size: uint
  }
)

(define-map league-managers
  { league-id: uint, manager: principal }
  {
    joined-at: uint,
    total-points: uint,
    draft-position: uint,
    roster-spots-filled: uint
  }
)

(define-map athlete-registry
  { athlete-id: uint }
  {
    name: (string-ascii 50),
    team: (string-ascii 20),
    position: uint,
    available: bool
  }
)

(define-map manager-rosters
  { league-id: uint, manager: principal, roster-slot: uint }
  {
    athlete-id: uint,
    acquired-week: uint
  }
)

(define-map athlete-ownership
  { league-id: uint, athlete-id: uint }
  { owner: (optional principal) }
)

;; Variables
(define-data-var league-counter uint u0)
(define-data-var athlete-registry-counter uint u0)
(define-data-var platform-admin principal tx-sender)
(define-data-var system-locked bool false)
(define-data-var platform-fee-percent uint u5) ;; 5% platform fee

;; Access control - only platform admin
(define-private (is-platform-admin)
  (is-eq tx-sender (var-get platform-admin))
)

;; Access control - only league commissioner
(define-private (is-league-commissioner (league-id uint))
  (match (map-get? leagues { league-id: league-id })
    league (is-eq tx-sender (get commissioner league))
    false
  )
)

;; Check if league exists
(define-private (league-exists (league-id uint))
  (is-some (map-get? leagues { league-id: league-id }))
)

;; Check if system is locked
(define-private (check-not-locked)
  (not (var-get system-locked))
)

;; Validate league ID
(define-private (validate-league-id (league-id uint))
  (if (<= league-id (var-get league-counter))
    true
    false
  )
)

;; Validate athlete ID
(define-private (validate-athlete-id (athlete-id uint))
  (if (<= athlete-id (var-get athlete-registry-counter))
    true
    false
  )
)

;; Get platform admin (read-only function)
(define-read-only (get-platform-admin)
  (var-get platform-admin)
)

;; Change platform admin
(define-public (set-platform-admin (new-admin principal))
  (begin
    (asserts! (is-platform-admin) ERR-UNAUTHORIZED-ACCESS)
    ;; Validate new admin is not null principal
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) ERR-INVALID-PARAMETER)
    (ok (var-set platform-admin new-admin))
  )
)

;; Set platform fee percentage
(define-public (set-platform-fee (fee-percent uint))
  (begin
    (asserts! (is-platform-admin) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= fee-percent u20) ERR-INVALID-PARAMETER) ;; Max 20% fee
    (ok (var-set platform-fee-percent fee-percent))
  )
)

;; Lock/unlock system
(define-public (set-system-lock (lock bool))
  (begin
    (asserts! (is-platform-admin) ERR-UNAUTHORIZED-ACCESS)
    (ok (var-set system-locked lock))
  )
)

;; Create a new league
(define-public (create-league
    (name (string-ascii 50))
    (description (string-ascii 255))
    (entry-fee uint)
    (start-week uint)
    (end-week uint)
    (manager-limit uint)
    (roster-size uint)
  )
  (let (
    (league-id (+ (var-get league-counter) u1))
  )
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR-INVALID-LEAGUE-NAME)
    (asserts! (> (len description) u0) ERR-INVALID-LEAGUE-DESCRIPTION)
    (asserts! (<= entry-fee u1000000000) ERR-INVALID-ENTRY-FEE) ;; Limit to 1000 STX
    (asserts! (< start-week end-week) ERR-INVALID-WEEK-SPAN)
    (asserts! (>= start-week block-height) ERR-INVALID-START-WEEK)
    (asserts! (> manager-limit u1) ERR-INVALID-MANAGER-LIMIT)
    (asserts! (<= roster-size u20) ERR-INVALID-PARAMETER) ;; Reasonable roster size limit
    (asserts! (>= roster-size u5) ERR-INVALID-PARAMETER) ;; Minimum roster size

    (map-set leagues
      { league-id: league-id }
      {
        name: name,
        description: description,
        commissioner: tx-sender,
        phase: PHASE-REGISTRATION,
        entry-fee: entry-fee,
        prize-pool: u0,
        start-week: start-week,
        end-week: end-week,
        manager-limit: manager-limit,
        manager-count: u0,
        roster-size: roster-size
      }
    )
    (var-set league-counter league-id)
    (ok league-id)
  )
)

;; Join a league as manager
(define-public (join-league (league-id uint))
  (let (
    (league (unwrap! (map-get? leagues { league-id: league-id }) ERR-LEAGUE-NOT-FOUND))
    (entry-fee (get entry-fee league))
    (manager-count (get manager-count league))
    (manager-limit (get manager-limit league))
  )
    ;; Validate league ID
    (asserts! (validate-league-id league-id) ERR-INVALID-LEAGUE-ID)
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    (asserts! (is-eq (get phase league) PHASE-REGISTRATION) ERR-DRAFT-CLOSED)
    (asserts! (< manager-count manager-limit) ERR-DRAFT-CLOSED)
    (asserts! (is-none (map-get? league-managers { league-id: league-id, manager: tx-sender })) ERR-ALREADY-JOINED)
    
    ;; Check if fee payment is required
    (if (> entry-fee u0)
      (begin
        ;; Transfer fee to contract
        (unwrap! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Update prize pool
        (map-set leagues
          { league-id: league-id }
          (merge league {
            prize-pool: (+ (get prize-pool league) entry-fee),
            manager-count: (+ manager-count u1)
          })
        )
      )
      ;; No fee, just update manager count
      (map-set leagues
        { league-id: league-id }
        (merge league { manager-count: (+ manager-count u1) })
      )
    )
    
    ;; Register manager with a random draft position (simplified)
    (map-set league-managers
      { league-id: league-id, manager: tx-sender }
      {
        joined-at: block-height,
        total-points: u0,
        draft-position: (+ manager-count u1), ;; Sequential for simplicity
        roster-spots-filled: u0
      }
    )
    
    (ok true)
  )
)

;; Start draft phase
(define-public (start-draft (league-id uint))
  (let (
    (league (unwrap! (map-get? leagues { league-id: league-id }) ERR-LEAGUE-NOT-FOUND))
  )
    ;; Validate league ID
    (asserts! (validate-league-id league-id) ERR-INVALID-LEAGUE-ID)
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    (asserts! (or (is-platform-admin) (is-eq tx-sender (get commissioner league))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get phase league) PHASE-REGISTRATION) ERR-SEASON-IN-PROGRESS)
    (asserts! (>= (get manager-count league) u2) ERR-INSUFFICIENT-MANAGERS)
    
    ;; Update league phase
    (map-set leagues
      { league-id: league-id }
      (merge league { phase: PHASE-DRAFT })
    )
    
    (ok true)
  )
)

;; Register a new athlete to the global registry
(define-public (register-athlete (name (string-ascii 50)) (team (string-ascii 20)) (position uint))
  (let (
    (athlete-id (+ (var-get athlete-registry-counter) u1))
  )
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    (asserts! (is-platform-admin) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> (len name) u0) ERR-INVALID-PARAMETER)
    (asserts! (> (len team) u0) ERR-INVALID-PARAMETER)
    (asserts! (and (>= position u1) (<= position u6)) ERR-INVALID-PARAMETER) ;; Valid position
    
    (map-set athlete-registry
      { athlete-id: athlete-id }
      {
        name: name,
        team: team,
        position: position,
        available: true
      }
    )
    
    (var-set athlete-registry-counter athlete-id)
    (ok athlete-id)
  )
)

;; Draft an athlete to a manager's roster
(define-public (draft-athlete (league-id uint) (athlete-id uint))
  (let (
    (league (unwrap! (map-get? leagues { league-id: league-id }) ERR-LEAGUE-NOT-FOUND))
    (athlete (unwrap! (map-get? athlete-registry { athlete-id: athlete-id }) ERR-ATHLETE-NOT-FOUND))
    (manager-data (unwrap! (map-get? league-managers { league-id: league-id, manager: tx-sender }) ERR-INVALID-MANAGER))
    (roster-spots-filled (get roster-spots-filled manager-data))
    (roster-size (get roster-size league))
    (ownership (default-to { owner: none } (map-get? athlete-ownership { league-id: league-id, athlete-id: athlete-id })))
  )
    ;; Validate inputs
    (asserts! (validate-league-id league-id) ERR-INVALID-LEAGUE-ID)
    (asserts! (validate-athlete-id athlete-id) ERR-INVALID-ATHLETE-ID)
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    (asserts! (is-eq (get phase league) PHASE-DRAFT) ERR-INVALID-LEAGUE-PHASE)
    (asserts! (< roster-spots-filled roster-size) ERR-ROSTER-FULL)
    (asserts! (get available athlete) ERR-ATHLETE-NOT-AVAILABLE)
    (asserts! (is-none (get owner ownership)) ERR-ATHLETE-ALREADY-OWNED)
    
    ;; Add athlete to manager's roster
    (map-set manager-rosters
      { league-id: league-id, manager: tx-sender, roster-slot: roster-spots-filled }
      {
        athlete-id: athlete-id,
        acquired-week: block-height
      }
    )
    
    ;; Update athlete ownership
    (map-set athlete-ownership
      { league-id: league-id, athlete-id: athlete-id }
      { owner: (some tx-sender) }
    )
    
    ;; Update manager's roster count
    (map-set league-managers
      { league-id: league-id, manager: tx-sender }
      (merge manager-data {
        roster-spots-filled: (+ roster-spots-filled u1)
      })
    )
    
    (ok true)
  )
)

;; Start the league season
(define-public (start-season (league-id uint))
  (let (
    (league (unwrap! (map-get? leagues { league-id: league-id }) ERR-LEAGUE-NOT-FOUND))
  )
    ;; Validate league ID
    (asserts! (validate-league-id league-id) ERR-INVALID-LEAGUE-ID)
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    (asserts! (or (is-platform-admin) (is-eq tx-sender (get commissioner league))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get phase league) PHASE-DRAFT) ERR-INVALID-LEAGUE-PHASE)
    
    ;; Update league phase
    (map-set leagues
      { league-id: league-id }
      (merge league { phase: PHASE-SEASON })
    )
    
    (ok true)
  )
)

;; Complete league season
(define-public (complete-season (league-id uint))
  (let (
    (league (unwrap! (map-get? leagues { league-id: league-id }) ERR-LEAGUE-NOT-FOUND))
  )
    ;; Validate league ID
    (asserts! (validate-league-id league-id) ERR-INVALID-LEAGUE-ID)
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    (asserts! (or (is-platform-admin) (is-eq tx-sender (get commissioner league))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get phase league) PHASE-SEASON) ERR-SEASON-NOT-ACTIVE)
    (asserts! (>= block-height (get end-week league)) ERR-SEASON-NOT-OVER)
    
    ;; Update league phase
    (map-set leagues
      { league-id: league-id }
      (merge league { phase: PHASE-COMPLETE })
    )
    
    (ok true)
  )
)

;; Read-only function to get league details
(define-read-only (get-league (league-id uint))
  (map-get? leagues { league-id: league-id })
)

;; Read-only function to get manager details
(define-read-only (get-manager (league-id uint) (manager principal))
  (map-get? league-managers { league-id: league-id, manager: manager })
)

;; Read-only function to get athlete details
(define-read-only (get-athlete (athlete-id uint))
  (map-get? athlete-registry { athlete-id: athlete-id })
)

;; Read-only function to get athlete ownership
(define-read-only (get-athlete-owner (league-id uint) (athlete-id uint))
  (map-get? athlete-ownership { league-id: league-id, athlete-id: athlete-id })
)

;; Read-only function to get manager's roster
(define-read-only (get-roster-athlete (league-id uint) (manager principal) (roster-slot uint))
  (map-get? manager-rosters { league-id: league-id, manager: manager, roster-slot: roster-slot })
)

;; Platform fee withdrawal by admin
(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-platform-admin) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    
    ;; Transfer requested amount to platform admin
    (unwrap! (as-contract (stx-transfer? amount (as-contract tx-sender) (var-get platform-admin))) ERR-INSUFFICIENT-FUNDS)
    
    (ok amount)
  )
)