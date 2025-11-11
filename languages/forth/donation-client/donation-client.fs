\ Forth Solana Donation Client
\
\ A minimalist, stack-based client for interacting with the Solana
\ donation smart contract. Demonstrates concatenative programming
\ and Reverse Polish Notation (RPN).
\
\ Stack notation:
\   ( n1 n2 -- n3 ) means: takes n1 and n2, returns n3
\   Top of stack is on the right
\
\ Example:
\   init-client
\   s" DonorPubkey" 1000000000 donate
\   get-vault-stats .stats

\ =============================================================================
\ Constants
\ =============================================================================

1000000000 constant LAMPORTS-PER-SOL
1000000 constant MIN-DONATION       \ 0.001 SOL
100000000000 constant MAX-DONATION  \ 100 SOL

1000000 constant TIER-BRONZE        \ 0.001 SOL
100000000 constant TIER-SILVER      \ 0.1 SOL
1000000000 constant TIER-GOLD       \ 1 SOL
10000000000 constant TIER-PLATINUM  \ 10 SOL

\ =============================================================================
\ Data Structures
\ =============================================================================

\ Client configuration
create rpc-url 256 allot
create program-id 256 allot

\ Vault statistics
variable admin-pubkey
variable total-donated
variable total-withdrawn
variable current-balance
variable donation-count
variable unique-donors
variable is-paused
variable min-donation-amount
variable max-donation-amount

\ Donor information
variable donor-pubkey
variable donor-total-donated
variable donor-donation-count
variable donor-last-timestamp
variable donor-tier

\ Tier enumeration (0=Bronze, 1=Silver, 2=Gold, 3=Platinum)
0 constant BRONZE
1 constant SILVER
2 constant GOLD
3 constant PLATINUM

\ =============================================================================
\ Utility Words
\ =============================================================================

\ Convert SOL to lamports ( f: sol -- n: lamports )
: sol>lamports ( F: sol -- n )
    LAMPORTS-PER-SOL s>f f* f>s ;

\ Convert lamports to SOL ( n: lamports -- f: sol )
: lamports>sol ( n -- F: sol )
    s>f LAMPORTS-PER-SOL s>f f/ ;

\ Calculate tier from total donated amount ( n: lamports -- tier )
: calculate-tier ( n -- tier )
    dup TIER-PLATINUM >= if drop PLATINUM exit then
    dup TIER-GOLD >= if drop GOLD exit then
    dup TIER-SILVER >= if drop SILVER exit then
    drop BRONZE ;

\ Get tier name as string ( tier -- addr len )
: tier-name ( tier -- addr len )
    case
        BRONZE of s" Bronze" endof
        SILVER of s" Silver" endof
        GOLD of s" Gold" endof
        PLATINUM of s" Platinum" endof
        s" Unknown" swap
    endcase ;

\ Get tier emoji ( tier -- addr len )
: tier-emoji ( tier -- addr len )
    case
        BRONZE of s" 🥉" endof
        SILVER of s" 🥈" endof
        GOLD of s" 🥇" endof
        PLATINUM of s" 💎" endof
        s" ?" swap
    endcase ;

\ Display tier with emoji ( tier -- )
: .tier ( tier -- )
    dup tier-name type space
    tier-emoji type ;

\ Get next tier threshold ( tier -- lamports | -1 )
: next-tier-threshold ( tier -- n )
    case
        BRONZE of TIER-SILVER endof
        SILVER of TIER-GOLD endof
        GOLD of TIER-PLATINUM endof
        PLATINUM of -1 endof
        -1 swap
    endcase ;

\ Calculate lamports to next tier ( current-lamports tier -- needed | 0 )
: lamports-to-next-tier ( n tier -- needed )
    next-tier-threshold
    dup -1 = if
        drop drop 0  \ Already at max tier
    else
        swap - dup 0< if drop 0 then  \ If negative, already reached
    then ;

\ =============================================================================
\ Validation Words
\ =============================================================================

\ Validate donation amount ( amount -- flag )
: valid-donation? ( n -- flag )
    dup MIN-DONATION >= swap MAX-DONATION <= and ;

\ Check if contract is paused ( -- flag )
: paused? ( -- flag )
    is-paused @ 0<> ;

\ =============================================================================
\ Client Operations
\ =============================================================================

\ Initialize the donation client
: init-client ( -- )
    s" https://api.devnet.solana.com" rpc-url place
    s" DoNaT1on111111111111111111111111111111111111" program-id place
    0 is-paused !
    MIN-DONATION min-donation-amount !
    MAX-DONATION max-donation-amount !
    cr ." ✓ Donation client initialized" cr ;

\ Make a donation ( donor-addr donor-len amount -- sig-addr sig-len )
: donate ( addr len n -- addr len )
    \ Validate amount
    dup valid-donation? 0= if
        cr ." Error: Invalid donation amount" cr
        2drop drop s" "
        exit
    then

    \ Check if paused
    paused? if
        cr ." Error: Contract is paused" cr
        2drop drop s" "
        exit
    then

    \ Update totals (placeholder - would send transaction)
    total-donated @ + total-donated !
    donation-count @ 1+ donation-count !

    \ Calculate donor tier
    dup calculate-tier donor-tier !

    \ Generate placeholder signature
    2drop
    s" signature_" pad place
    ticks <# #s #> pad +place
    pad count ;

\ Get vault statistics ( -- )
: get-vault-stats ( -- )
    \ Placeholder - would call RPC endpoint
    1000000000 total-donated !
    0 total-withdrawn !
    1000000000 current-balance !
    10 donation-count !
    5 unique-donors !
    0 is-paused !
    MIN-DONATION min-donation-amount !
    MAX-DONATION max-donation-amount ! ;

\ Get donor information ( donor-addr donor-len -- )
: get-donor-info ( addr len -- )
    \ Placeholder - would call RPC endpoint
    2drop
    500000000 donor-total-donated !
    3 donor-donation-count !
    time&date 2drop 2drop drop donor-last-timestamp !
    donor-total-donated @ calculate-tier donor-tier ! ;

\ Withdraw funds (admin only) ( admin-addr admin-len amount -- sig-addr sig-len )
: withdraw ( addr len n -- addr len )
    \ Check sufficient funds
    dup current-balance @ > if
        cr ." Error: Insufficient funds" cr
        drop 2drop s" "
        exit
    then

    \ Update balance
    current-balance @ swap - current-balance !
    total-withdrawn @ + total-withdrawn !

    \ Generate placeholder signature
    2drop
    s" withdraw_sig_" pad place
    ticks <# #s #> pad +place
    pad count ;

\ =============================================================================
\ Display Words
\ =============================================================================

\ Display vault statistics
: .stats ( -- )
    cr ." === Vault Statistics ===" cr
    ."   Admin: " admin-pubkey @ u. cr
    ."   Total donated: " total-donated @ lamports>sol f. ."  SOL" cr
    ."   Total withdrawn: " total-withdrawn @ lamports>sol f. ."  SOL" cr
    ."   Current balance: " current-balance @ lamports>sol f. ."  SOL" cr
    ."   Donations: " donation-count @ u. cr
    ."   Unique donors: " unique-donors @ u. cr
    ."   Paused: " is-paused @ if ." Yes" else ." No" then cr ;

\ Display donor information
: .donor-info ( -- )
    cr ." === Donor Information ===" cr
    ."   Total donated: " donor-total-donated @ lamports>sol f. ."  SOL" cr
    ."   Donation count: " donor-donation-count @ u. cr
    ."   Tier: " donor-tier @ .tier cr

    \ Show progress to next tier
    donor-total-donated @ donor-tier @ lamports-to-next-tier
    dup 0> if
        ."   Need " lamports>sol f. ."  SOL for next tier" cr
    else
        drop ."   Status: Maximum tier reached! 💎" cr
    then ;

\ Display donation result
: .donation-result ( addr len amount -- )
    cr ." === Donation Result ===" cr
    ."   Signature: " rot rot type cr
    ."   Amount: " lamports>sol f. ."  SOL" cr
    ."   Tier: " donor-tier @ .tier cr ;

\ =============================================================================
\ Formatting Helpers
\ =============================================================================

\ Format large number with thousands separator ( n -- )
: .lamports ( n -- )
    s>d <# # # # # # # # # # #> type ."  lamports" ;

\ Display SOL amount nicely ( F: sol -- )
: .sol ( F: sol -- )
    9 set-precision f. ."  SOL" ;

\ Display percentage ( n total -- )
: .percentage ( n total -- )
    swap s>f swap s>f f/ 100e f* f. ." %" ;

\ =============================================================================
\ Advanced Operations
\ =============================================================================

\ Calculate average donation ( total count -- average )
: average-donation ( n1 n2 -- n3 )
    dup 0= if
        2drop 0
    else
        /
    then ;

\ Check if in top donors ( donor-amount total threshold-percent -- flag )
: top-donor? ( n1 n2 n3 -- flag )
    -rot .percentage
    s>f >= ;

\ Format time ago ( timestamp -- )
: .time-ago ( n -- )
    time&date 2drop 2drop drop  \ Get current timestamp
    swap -                       \ Calculate difference
    dup 86400 / dup 0> if
        . ." days ago"
    else
        drop dup 3600 / dup 0> if
            . ." hours ago"
        else
            drop 60 / dup 0> if
                . ." minutes ago"
            else
                drop ." just now"
            then
        then
    then ;

\ =============================================================================
\ Example Usage & Testing
\ =============================================================================

\ Run example donation flow
: example ( -- )
    cr ." === Forth Solana Donation Client Example ===" cr cr

    \ Initialize
    init-client

    \ Make donation
    cr ." Making donation of 0.5 SOL..." cr
    s" DonorPubkey123" 500000000 donate
    500000000 .donation-result

    \ Get vault stats
    get-vault-stats
    .stats

    \ Get donor info
    cr s" DonorPubkey123" get-donor-info
    .donor-info
    cr ;

\ Interactive helper words
: help ( -- )
    cr ." === Forth Donation Client Commands ===" cr cr
    ."   init-client              Initialize the client" cr
    ."   donate                   Make a donation" cr
    ."   get-vault-stats          Get vault statistics" cr
    ."   get-donor-info           Get donor information" cr
    ."   withdraw                 Withdraw funds (admin)" cr
    ."   .stats                   Display vault stats" cr
    ."   .donor-info              Display donor info" cr
    ."   calculate-tier           Calculate tier from lamports" cr
    ."   tier-emoji               Get tier emoji" cr
    ."   sol>lamports             Convert SOL to lamports" cr
    ."   lamports>sol             Convert lamports to SOL" cr
    ."   example                  Run example flow" cr
    ."   help                     Show this help" cr
    cr ;

\ Display welcome message
: welcome ( -- )
    cr ." ╔══════════════════════════════════════════╗" cr
    ."    ║  Forth Solana Donation Client v1.0.0  ║" cr
    ."    ╚══════════════════════════════════════════╝" cr
    cr ." Type 'help' for available commands" cr
    ."    Type 'example' to run a demo" cr
    cr ;

\ Auto-run on load
welcome

\ =============================================================================
\ Advanced Stack Manipulation Examples
\ =============================================================================

\ Example: Chain operations in Forth style
\ Calculate total donated, then get tier, then show emoji
: donation-emoji ( n -- )
    calculate-tier tier-emoji type ;

\ Example: Multiple donations in sequence
: multi-donate ( -- )
    s" Donor1" 100000000 donate type cr
    s" Donor2" 500000000 donate type cr
    s" Donor3" 1000000000 donate type cr
    cr ." Three donations processed!" cr ;

\ Example: Tier progression checker
: check-progression ( current-amount goal-tier -- )
    next-tier-threshold swap -
    dup 0> if
        ." Need " lamports>sol .sol ."  more to reach "
        swap .tier cr
    else
        drop ." Already reached " .tier cr
    then ;

\ =============================================================================
\ Comments on Forth Style
\ =============================================================================

(
  Forth uses postfix notation, where operators come after operands:

  Instead of: 2 + 3
  Forth uses: 2 3 +

  Stack visualization:
  2        -- [ 2 ]
  3        -- [ 2 3 ]
  +        -- [ 5 ]

  This makes composition natural:
  2 3 + 4 *   -- (2+3)*4 = 20

  Benefits:
  - No parentheses needed
  - Natural left-to-right reading
  - Easy to see data flow
  - Efficient execution
)

cr .( Forth Donation Client loaded successfully! ) cr
.( Type 'example' to see it in action ) cr
