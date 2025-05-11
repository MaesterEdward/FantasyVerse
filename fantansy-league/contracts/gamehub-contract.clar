;; Fantasy Metaverse League Smart Contract - STAGE 1
;; This contract manages fantasy sports leagues with basic functionality for leagues and athletes

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-LEAGUE-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-JOINED (err u102))
(define-constant ERR-LEAGUE-CLOSED (err u103))
(define-constant ERR-ATHLETE-NOT-FOUND (err u104))
(define-constant ERR-INVALID-PARAMETER (err u105))
(define-constant ERR-INVALID-LEAGUE-NAME (err u106))
(define-constant ERR-INVALID-LEAGUE-DESCRIPTION (err u107))
(define-constant ERR-INVALID-ENTRY-FEE (err u108))
(define-constant ERR-INVALID-WEEK-SPAN (err u109))
(define-constant ERR-INVALID-START-WEEK (err u110))
(define-constant ERR-INVALID-MANAGER-LIMIT (err u111))
(define-constant ERR-INSUFFICIENT-FUNDS (err u112))
(define-constant ERR-SYSTEM-LOCKED (err u113))
(define-constant ERR-INVALID-LEAGUE-ID (err u114))

;; League phases
(define-constant PHASE-REGISTRATION u0)
(define-constant PHASE-ACTIVE u1)
(define-constant PHASE-COMPLETE u2)

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
    manager-count: uint
  }
)

(define-map league-managers
  { league-id: uint, manager: principal }
  {
    joined-at: uint,
    total-points: uint
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

;; Variables
(define-data-var league-counter uint u0)
(define-data-var athlete-registry-counter uint u0)
(define-data-var platform-admin principal tx-sender)
(define-data-var system-locked bool false)

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
        manager-count: u0
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
    (asserts! (is-eq (get phase league) PHASE-REGISTRATION) ERR-LEAGUE-CLOSED)
    (asserts! (< manager-count manager-limit) ERR-LEAGUE-CLOSED)
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
    
    ;; Register manager
    (map-set league-managers
      { league-id: league-id, manager: tx-sender }
      {
        joined-at: block-height,
        total-points: u0
      }
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

;; Activate a league (transition from registration to active)
(define-public (activate-league (league-id uint))
  (let (
    (league (unwrap! (map-get? leagues { league-id: league-id }) ERR-LEAGUE-NOT-FOUND))
  )
    ;; Validate league ID
    (asserts! (validate-league-id league-id) ERR-INVALID-LEAGUE-ID)
    (asserts! (check-not-locked) ERR-SYSTEM-LOCKED)
    (asserts! (or (is-platform-admin) (is-eq tx-sender (get commissioner league))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get phase league) PHASE-REGISTRATION) ERR-LEAGUE-CLOSED)
    
    ;; Update league phase
    (map-set leagues
      { league-id: league-id }
      (merge league { phase: PHASE-ACTIVE })
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