/// MemorialHall — candidate moments, guardian voting, badge minting.
///
/// Design invariants (see docs/architecture/mvp-spec.md §4):
///   M1. `rank` written once at first vote (`total_guardians + 1`) — never re-sorted.
///   M2. `tier` derived purely from `rank`: ≤3 gold / ≤10 silver / ≤30 bronze / else none.
///   M3. One GuardianBadge per (moment, FanSBT) — enforced naturally by `dynamic_field::add`
///       aborting on duplicate key; no explicit `minted` flag needed.
///   M4. Only finalized moments can mint badges; status transitions are AdminCap-gated.
///   M5. `total_points` / `total_guardians` are monotonically non-decreasing.
///
/// Events: reuses the 7 locked events in `mon_contracts::events`. No new events —
/// `finalize_season` mutates status only; frontends read object state directly.
module mon_contracts::memorial_hall;

use std::string::String;
use sui::clock::{Self, Clock};
use sui::dynamic_field as df;
use sui::table::{Self, Table};
use sui::tx_context::sender;
use mon_contracts::events;
use mon_contracts::fan_sbt::{Self, FanSBT, AdminCap};

// === Errors ===
const EProposerNotStation: u64 = 100;
const EMomentNotCandidate: u64 = 101;
const EMomentNotFinalized: u64 = 102;
const ENotGuardian: u64 = 103;
const EInvalidStatusTransition: u64 = 104;
const EVotePointsZero: u64 = 105;
const EEmptyMetadata: u64 = 106;

// === Status codes (spec §4.1) ===
const STATUS_CANDIDATE: u8 = 0;
const STATUS_FINALIZED: u8 = 1;
const STATUS_EXPIRED: u8 = 2;

// === Tier codes ===
const TIER_NONE: u8 = 0;
const TIER_GOLD: u8 = 1;
const TIER_SILVER: u8 = 2;
const TIER_BRONZE: u8 = 3;

// === Rank thresholds (spec §4.2) ===
const RANK_GOLD_MAX: u64 = 3;
const RANK_SILVER_MAX: u64 = 10;
const RANK_BRONZE_MAX: u64 = 30;

// Demo season length: 7 days. Extend via AdminCap tooling in later phases.
const SEASON_DURATION_MS: u64 = 7 * 24 * 60 * 60 * 1000;

// === Structs ===

public struct MemorialMoment has key, store {
    id: UID,
    title: String,
    description: String,
    media_walrus_blob_id: String,
    proposer: address,
    proposer_tier: u8,
    total_points: u64,
    total_guardians: u64,
    preservation_until: u64,
    status: u8,
    guardians: Table<ID, GuardianEntry>,
}

public struct GuardianEntry has store {
    sbt_id: ID,
    points_contributed: u64,
    rank: u64,
    tier: u8,
    joined_at: u64,
}

public struct GuardianBadge has key, store {
    id: UID,
    moment_id: ID,
    rank: u64,
    tier: u8,
    minted_at: u64,
}

// === Entries ===

/// Proposer must be Lv.2+ station姐 (or Lv.3 official). Shares MemorialMoment.
public fun propose_moment(
    proposer_sbt: &FanSBT,
    title: String,
    description: String,
    media_walrus_blob_id: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let lvl = fan_sbt::level(proposer_sbt);
    assert!(lvl >= 2, EProposerNotStation);
    assert!(!std::string::is_empty(&title), EEmptyMetadata);
    assert!(!std::string::is_empty(&media_walrus_blob_id), EEmptyMetadata);
    let now = clock::timestamp_ms(clock);
    let proposer_tier = if (lvl >= 3) 1 else 2;
    let moment = MemorialMoment {
        id: object::new(ctx),
        title,
        description,
        media_walrus_blob_id,
        proposer: sender(ctx),
        proposer_tier,
        total_points: 0,
        total_guardians: 0,
        preservation_until: now + SEASON_DURATION_MS,
        status: STATUS_CANDIDATE,
        guardians: table::new<ID, GuardianEntry>(ctx),
    };
    let mid = object::id(&moment);
    events::emit_moment_proposed(mid, sender(ctx), now);
    transfer::share_object(moment);
}

/// Vote with points from voter's FanSBT. First vote creates GuardianEntry (rank locked);
/// subsequent votes accumulate `points_contributed` without touching rank/tier.
public fun vote_moment(
    moment: &mut MemorialMoment,
    voter_sbt: &mut FanSBT,
    points: u64,
    clock: &Clock,
) {
    assert!(moment.status == STATUS_CANDIDATE, EMomentNotCandidate);
    assert!(points > 0, EVotePointsZero);
    // spend_points asserts available_points >= points and decrements (fan_sbt I1).
    fan_sbt::spend_points(voter_sbt, points);

    let sbt_id = object::id(voter_sbt);
    let now = clock::timestamp_ms(clock);
    let is_new_guardian = !moment.guardians.contains(sbt_id);
    if (is_new_guardian) {
        moment.total_guardians = moment.total_guardians + 1;
        let rank = moment.total_guardians;
        let tier = compute_tier(rank);
        moment.guardians.add(sbt_id, GuardianEntry {
            sbt_id,
            points_contributed: points,
            rank,
            tier,
            joined_at: now,
        });
    } else {
        let entry = moment.guardians.borrow_mut(sbt_id);
        entry.points_contributed = entry.points_contributed + points;
    };
    moment.total_points = moment.total_points + points;

    let mid = object::id(moment);
    events::emit_vote_cast(mid, sbt_id, points, is_new_guardian, now);
}

/// Mint GuardianBadge for a finalized moment. Attaches via dynamic field to the
/// voter's FanSBT — duplicate mint aborts on df key conflict (M3).
public fun mint_guardian_badge(
    moment: &MemorialMoment,
    sbt: &mut FanSBT,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(moment.status == STATUS_FINALIZED, EMomentNotFinalized);
    let sbt_id = object::id(sbt);
    assert!(moment.guardians.contains(sbt_id), ENotGuardian);
    let entry = moment.guardians.borrow(sbt_id);
    let rank = entry.rank;
    let tier = entry.tier;
    let now = clock::timestamp_ms(clock);
    let moment_id = object::id(moment);

    let badge = GuardianBadge {
        id: object::new(ctx),
        moment_id,
        rank,
        tier,
        minted_at: now,
    };
    // Key = moment_id; second mint for same moment naturally aborts.
    df::add(fan_sbt::uid_mut(sbt), moment_id, badge);
    fan_sbt::inc_guardian_badge_count(sbt);
    events::emit_guardian_badge_minted(sbt_id, moment_id, rank, tier, now);
}

/// AdminCap-gated status transition: CANDIDATE → FINALIZED or EXPIRED (one-way).
public fun finalize_season(
    _: &AdminCap,
    moment: &mut MemorialMoment,
    new_status: u8,
) {
    assert!(moment.status == STATUS_CANDIDATE, EInvalidStatusTransition);
    assert!(
        new_status == STATUS_FINALIZED || new_status == STATUS_EXPIRED,
        EInvalidStatusTransition,
    );
    moment.status = new_status;
}

// === Internal ===

fun compute_tier(rank: u64): u8 {
    if (rank <= RANK_GOLD_MAX) TIER_GOLD
    else if (rank <= RANK_SILVER_MAX) TIER_SILVER
    else if (rank <= RANK_BRONZE_MAX) TIER_BRONZE
    else TIER_NONE
}

// === Read-only accessors ===

public fun status(m: &MemorialMoment): u8 { m.status }
public fun total_points(m: &MemorialMoment): u64 { m.total_points }
public fun total_guardians(m: &MemorialMoment): u64 { m.total_guardians }
public fun proposer(m: &MemorialMoment): address { m.proposer }
public fun proposer_tier(m: &MemorialMoment): u8 { m.proposer_tier }
public fun preservation_until(m: &MemorialMoment): u64 { m.preservation_until }
public fun is_guardian(m: &MemorialMoment, sbt_id: ID): bool { m.guardians.contains(sbt_id) }
public fun guardian_rank(m: &MemorialMoment, sbt_id: ID): u64 { m.guardians.borrow(sbt_id).rank }
public fun guardian_tier(m: &MemorialMoment, sbt_id: ID): u8 { m.guardians.borrow(sbt_id).tier }
public fun guardian_points(m: &MemorialMoment, sbt_id: ID): u64 {
    m.guardians.borrow(sbt_id).points_contributed
}
