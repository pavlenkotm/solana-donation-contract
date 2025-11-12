;; Clarity Donation Contract for Stacks (Bitcoin Layer 2)
;; A secure donation system with donor tier tracking and admin controls

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-initialized (err u101))
(define-constant err-already-initialized (err u102))
(define-constant err-contract-paused (err u103))
(define-constant err-donation-too-small (err u104))
(define-constant err-donation-too-large (err u105))
(define-constant err-invalid-limits (err u106))
(define-constant err-insufficient-balance (err u107))
(define-constant err-transfer-failed (err u108))

;; Donor tier constants (based on contribution in microSTX)
(define-constant tier-bronze u1)      ;; 0.01+ STX (10,000 microSTX)
(define-constant tier-silver u2)      ;; 0.1+ STX (100,000 microSTX)
(define-constant tier-gold u3)        ;; 1+ STX (1,000,000 microSTX)
(define-constant tier-platinum u4)    ;; 10+ STX (10,000,000 microSTX)

(define-constant stx-decimals u1000000) ;; 1 STX = 1,000,000 microSTX

;; Data variables
(define-data-var admin principal contract-owner)
(define-data-var total-donations uint u0)
(define-data-var donor-count uint u0)
(define-data-var min-donation uint u0)
(define-data-var max-donation uint u0)
(define-data-var paused bool false)
(define-data-var initialized bool false)

;; Data maps
(define-map donor-amounts principal uint)
(define-map donor-first-donation-block principal uint)

;; Read-only functions

(define-read-only (get-total-donations)
  (ok (var-get total-donations))
)

(define-read-only (get-donor-amount (donor principal))
  (ok (default-to u0 (map-get? donor-amounts donor)))
)

(define-read-only (get-donor-tier (donor principal))
  (let ((amount (default-to u0 (map-get? donor-amounts donor))))
    (ok (calculate-tier amount))
  )
)

(define-read-only (get-donor-count)
  (ok (var-get donor-count))
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (get-min-donation)
  (ok (var-get min-donation))
)

(define-read-only (get-max-donation)
  (ok (var-get max-donation))
)

(define-read-only (is-initialized)
  (ok (var-get initialized))
)

(define-read-only (get-contract-balance)
  (ok (stx-get-balance (as-contract tx-sender)))
)

;; Private functions

(define-private (calculate-tier (amount uint))
  (if (>= amount (* u10 stx-decimals))
    tier-platinum
    (if (>= amount stx-decimals)
      tier-gold
      (if (>= amount (/ stx-decimals u10))
        tier-silver
        (if (>= amount (/ stx-decimals u100))
          tier-bronze
          u0
        )
      )
    )
  )
)

(define-private (is-admin (caller principal))
  (is-eq caller (var-get admin))
)

;; Public functions

(define-public (initialize (new-admin principal) (min uint) (max uint))
  (begin
    (asserts! (not (var-get initialized)) err-already-initialized)
    (asserts! (> min u0) err-invalid-limits)
    (asserts! (> max min) err-invalid-limits)

    (var-set admin new-admin)
    (var-set min-donation min)
    (var-set max-donation max)
    (var-set initialized true)

    (print {
      event: "initialized",
      admin: new-admin,
      min-donation: min,
      max-donation: max,
      block-height: block-height
    })

    (ok true)
  )
)

(define-public (donate (amount uint))
  (begin
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (not (var-get paused)) err-contract-paused)
    (asserts! (>= amount (var-get min-donation)) err-donation-too-small)
    (asserts! (<= amount (var-get max-donation)) err-donation-too-large)

    (let
      (
        (donor tx-sender)
        (current-amount (default-to u0 (map-get? donor-amounts donor)))
        (new-amount (+ current-amount amount))
      )

      ;; Transfer STX to contract
      (try! (stx-transfer? amount donor (as-contract tx-sender)))

      ;; Update donor amount
      (map-set donor-amounts donor new-amount)

      ;; Update total donations
      (var-set total-donations (+ (var-get total-donations) amount))

      ;; Increment donor count if first donation
      (if (is-eq current-amount u0)
        (begin
          (var-set donor-count (+ (var-get donor-count) u1))
          (map-set donor-first-donation-block donor block-height)
        )
        true
      )

      ;; Calculate tier
      (let ((tier (calculate-tier new-amount)))
        (print {
          event: "donation-received",
          donor: donor,
          amount: amount,
          total: new-amount,
          tier: tier,
          block-height: block-height
        })

        (ok tier)
      )
    )
  )
)

(define-public (withdraw (amount uint) (recipient principal))
  (begin
    (asserts! (is-admin tx-sender) err-owner-only)
    (asserts! (var-get initialized) err-not-initialized)
    (asserts! (> amount u0) err-invalid-limits)

    ;; Transfer from contract to recipient
    (match (as-contract (stx-transfer? amount tx-sender recipient))
      success (begin
        (print {
          event: "withdrawal",
          admin: tx-sender,
          amount: amount,
          recipient: recipient,
          block-height: block-height
        })
        (ok true)
      )
      error (err err-transfer-failed)
    )
  )
)

(define-public (emergency-withdraw (recipient principal))
  (begin
    (asserts! (is-admin tx-sender) err-owner-only)
    (asserts! (var-get initialized) err-not-initialized)

    (let ((balance (stx-get-balance (as-contract tx-sender))))
      ;; Transfer all funds from contract to recipient
      (match (as-contract (stx-transfer? balance tx-sender recipient))
        success (begin
          (print {
            event: "emergency-withdrawal",
            admin: tx-sender,
            amount: balance,
            recipient: recipient,
            block-height: block-height
          })
          (ok balance)
        )
        error (err err-transfer-failed)
      )
    )
  )
)

(define-public (pause)
  (begin
    (asserts! (is-admin tx-sender) err-owner-only)
    (asserts! (not (var-get paused)) err-contract-paused)

    (var-set paused true)

    (print {
      event: "contract-paused",
      admin: tx-sender,
      block-height: block-height
    })

    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-admin tx-sender) err-owner-only)
    (asserts! (var-get paused) err-contract-paused)

    (var-set paused false)

    (print {
      event: "contract-unpaused",
      admin: tx-sender,
      block-height: block-height
    })

    (ok true)
  )
)

(define-public (update-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) err-owner-only)

    (var-set admin new-admin)

    (print {
      event: "admin-updated",
      old-admin: tx-sender,
      new-admin: new-admin,
      block-height: block-height
    })

    (ok true)
  )
)

(define-public (update-donation-limits (min uint) (max uint))
  (begin
    (asserts! (is-admin tx-sender) err-owner-only)
    (asserts! (> min u0) err-invalid-limits)
    (asserts! (> max min) err-invalid-limits)

    (var-set min-donation min)
    (var-set max-donation max)

    (print {
      event: "limits-updated",
      min-donation: min,
      max-donation: max,
      block-height: block-height
    })

    (ok true)
  )
)

;; Bulk query functions for analytics

(define-read-only (get-donor-stats (donor principal))
  (ok {
    amount: (default-to u0 (map-get? donor-amounts donor)),
    tier: (calculate-tier (default-to u0 (map-get? donor-amounts donor))),
    first-donation-block: (map-get? donor-first-donation-block donor)
  })
)

(define-read-only (get-contract-stats)
  (ok {
    total-donations: (var-get total-donations),
    donor-count: (var-get donor-count),
    paused: (var-get paused),
    admin: (var-get admin),
    balance: (stx-get-balance (as-contract tx-sender))
  })
)
