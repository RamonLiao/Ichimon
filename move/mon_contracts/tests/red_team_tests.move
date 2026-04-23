/// Red-Team adversarial tests — 主動攻擊合約邏輯、狀態機、經濟設計。
///
/// 與 `fan_sbt_tests` / `memorial_hall_tests` 互補：
/// - 後者驗證 happy path + 單一 abort
/// - 本檔模擬 **攻擊者** 組合攻擊、狀態穿越、邏輯漏洞
///
/// 每個 test 開頭標註 Attack Vector + 預期結果（DEFENDED / EXPLOITED / FLAG）。
#[test_only]
module mon_contracts::red_team_tests;

use std::string;
use sui::clock::{Self, Clock};
use sui::test_scenario::{Self as ts, Scenario};
use mon_contracts::fan_sbt::{Self, FanSBT, AdminCap, MintRegistry};
use mon_contracts::memorial_hall::{Self, MemorialMoment};

const ADMIN:   address = @0xAD;
const ATTACKER: address = @0xBAD;
const VICTIM:   address = @0xBEEF;
const CAROL:    address = @0xC;
const FIGHTER:  address = @0x7A;
const OTHER_FIGHTER: address = @0x7B;

const STATUS_CANDIDATE: u8 = 0;
const STATUS_FINALIZED: u8 = 1;
const STATUS_EXPIRED:   u8 = 2;

// --- helpers ---

fun start(): Scenario {
    let mut sc = ts::begin(ADMIN);
    fan_sbt::init_for_testing(sc.ctx());
    sc.next_tx(ADMIN);
    sc
}

fun mint_for(sc: &mut Scenario, who: address, fighter: address) {
    sc.next_tx(who);
    let mut reg = sc.take_shared<MintRegistry>();
    fan_sbt::mint_fan_card(&mut reg, fighter, sc.ctx());
    ts::return_shared(reg);
    sc.next_tx(who);
}

fun level_up(sc: &mut Scenario, who: address) {
    mint_for(sc, who, FIGHTER);
    sc.next_tx(who);
    let mut sbt = sc.take_from_sender<FanSBT>();
    fan_sbt::record_check_in(&mut sbt, b"e1", sc.ctx());
    fan_sbt::record_check_in(&mut sbt, b"e2", sc.ctx());
    fan_sbt::record_check_in(&mut sbt, b"e3", sc.ctx());
    sc.return_to_sender(sbt);
    sc.next_tx(who);
}

fun propose(sc: &mut Scenario, who: address, clock: &Clock) {
    sc.next_tx(who);
    let sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::propose_moment(
        &sbt,
        string::utf8(b"t"),
        string::utf8(b"d"),
        string::utf8(b"blob"),
        clock,
        sc.ctx(),
    );
    sc.return_to_sender(sbt);
    sc.next_tx(who);
}

// =====================================================================
// Round 1 — Access Control Bypass
// =====================================================================

/// [DEFENDED] Attacker tries to mint a second FanSBT to the same address by first
/// transferring it — compiler blocks transfer (no store). We simulate via double
/// mint_fan_card call. MintRegistry aborts.
#[test]
#[expected_failure(abort_code = ::mon_contracts::fan_sbt::EAlreadyMinted)]
fun rt_1_double_mint_same_address_blocked() {
    let mut sc = start();
    mint_for(&mut sc, ATTACKER, FIGHTER);
    sc.next_tx(ATTACKER);
    let mut reg = sc.take_shared<MintRegistry>();
    // Attacker attempts second mint with different fighter_id — still blocked
    // because registry keys on sender address, not fighter.
    fan_sbt::mint_fan_card(&mut reg, OTHER_FIGHTER, sc.ctx());
    abort 0xDEAD
}

/// [DEFENDED] Attacker tries to call official_certify without owning AdminCap.
/// Can't even construct &AdminCap → compile blocks most paths; we simulate the
/// closest runtime attempt: take AdminCap from ADMIN, pass to attacker tx.
/// `take_from_address` requires the object to exist at that address — if attacker
/// tries to take from a non-owner address, it panics at runtime.
#[test]
#[expected_failure(abort_code = ::mon_contracts::fan_sbt::ENotLv2)]
fun rt_1b_official_certify_on_lv1_blocked() {
    let mut sc = start();
    mint_for(&mut sc, VICTIM, FIGHTER);

    // ADMIN holds AdminCap; attempt certify before victim reaches Lv.2
    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    sc.next_tx(VICTIM);
    let mut sbt = sc.take_from_sender<FanSBT>();
    fan_sbt::official_certify(&cap, &mut sbt, sc.ctx()); // aborts ENotLv2
    sc.return_to_sender(sbt);
    ts::return_to_address(ADMIN, cap);
    sc.end();
}

// =====================================================================
// Round 2 — Integer / Economic Abuse
// =====================================================================

/// [DEFENDED] Attacker votes with MAX_U64 points → spend_points aborts
/// EInsufficientPoints before any overflow path runs.
#[test]
#[expected_failure(abort_code = ::mon_contracts::fan_sbt::EInsufficientPoints)]
fun rt_2_vote_max_u64_points_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER); // 3 points

    let mut clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ATTACKER);
    let mut m = sc.take_shared<MemorialMoment>();
    let mut sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::vote_moment(&mut m, &mut sbt, 18446744073709551615u64, &clk); // u64::MAX
    ts::return_shared(m);
    sc.return_to_sender(sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

/// [DEFENDED] Zero-point vote aborts EVotePointsZero (economic spam guard).
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::EVotePointsZero)]
fun rt_2b_zero_vote_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ATTACKER);
    let mut m = sc.take_shared<MemorialMoment>();
    let mut sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::vote_moment(&mut m, &mut sbt, 0, &clk);
    ts::return_shared(m);
    sc.return_to_sender(sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

// =====================================================================
// Round 3 — State Machine Corruption
// =====================================================================

/// [DEFENDED] Vote on FINALIZED moment → EMomentNotCandidate.
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::EMomentNotCandidate)]
fun rt_3_vote_after_finalized_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    // finalize
    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    let mut m = sc.take_shared<MemorialMoment>();
    memorial_hall::finalize_season(&cap, &mut m, STATUS_FINALIZED);
    ts::return_shared(m);
    ts::return_to_address(ADMIN, cap);

    // attacker tries to keep voting post-finalize
    sc.next_tx(ATTACKER);
    let mut m2 = sc.take_shared<MemorialMoment>();
    let mut sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::vote_moment(&mut m2, &mut sbt, 1, &clk);
    ts::return_shared(m2);
    sc.return_to_sender(sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

/// [DEFENDED] Double finalize → EInvalidStatusTransition (one-way transition).
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::EInvalidStatusTransition)]
fun rt_3b_double_finalize_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    let mut m = sc.take_shared<MemorialMoment>();
    memorial_hall::finalize_season(&cap, &mut m, STATUS_FINALIZED);
    memorial_hall::finalize_season(&cap, &mut m, STATUS_EXPIRED); // abort
    ts::return_shared(m);
    ts::return_to_address(ADMIN, cap);
    clock::destroy_for_testing(clk);
    sc.end();
}

/// [DEFENDED] Admin tries to finalize with invalid status code (e.g., 99) → abort.
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::EInvalidStatusTransition)]
fun rt_3c_finalize_invalid_status_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    let mut m = sc.take_shared<MemorialMoment>();
    memorial_hall::finalize_season(&cap, &mut m, 99);
    ts::return_shared(m);
    ts::return_to_address(ADMIN, cap);
    clock::destroy_for_testing(clk);
    sc.end();
}

/// [DEFENDED] Finalize then try to set back to CANDIDATE → abort.
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::EInvalidStatusTransition)]
fun rt_3d_finalize_rollback_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    let mut m = sc.take_shared<MemorialMoment>();
    memorial_hall::finalize_season(&cap, &mut m, STATUS_FINALIZED);
    memorial_hall::finalize_season(&cap, &mut m, STATUS_CANDIDATE); // abort
    ts::return_shared(m);
    ts::return_to_address(ADMIN, cap);
    clock::destroy_for_testing(clk);
    sc.end();
}

// =====================================================================
// Round 4 — Badge Minting Attacks
// =====================================================================

/// [DEFENDED] Mint badge on CANDIDATE (not yet finalized) → EMomentNotFinalized.
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::EMomentNotFinalized)]
fun rt_4_early_badge_mint_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ATTACKER);
    let mut m = sc.take_shared<MemorialMoment>();
    let mut sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::vote_moment(&mut m, &mut sbt, 1, &clk);
    memorial_hall::mint_guardian_badge(&m, &mut sbt, &clk, sc.ctx()); // abort
    ts::return_shared(m);
    sc.return_to_sender(sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

/// [DEFENDED] Mint badge on EXPIRED moment → EMomentNotFinalized (season failed).
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::EMomentNotFinalized)]
fun rt_4b_expired_moment_badge_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ATTACKER);
    let mut m = sc.take_shared<MemorialMoment>();
    let mut sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::vote_moment(&mut m, &mut sbt, 1, &clk);
    ts::return_shared(m);
    sc.return_to_sender(sbt);

    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    let mut m2 = sc.take_shared<MemorialMoment>();
    memorial_hall::finalize_season(&cap, &mut m2, STATUS_EXPIRED);
    ts::return_shared(m2);
    ts::return_to_address(ADMIN, cap);

    sc.next_tx(ATTACKER);
    let m3 = sc.take_shared<MemorialMoment>();
    let mut sbt2 = sc.take_from_sender<FanSBT>();
    memorial_hall::mint_guardian_badge(&m3, &mut sbt2, &clk, sc.ctx()); // abort
    ts::return_shared(m3);
    sc.return_to_sender(sbt2);
    clock::destroy_for_testing(clk);
    sc.end();
}

/// [DEFENDED] Non-guardian (never voted) tries to mint badge → ENotGuardian.
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::ENotGuardian)]
fun rt_4c_non_guardian_badge_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER); // proposer & voter
    level_up(&mut sc, CAROL);    // bystander, never votes
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ATTACKER);
    let mut m = sc.take_shared<MemorialMoment>();
    let mut sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::vote_moment(&mut m, &mut sbt, 1, &clk);
    ts::return_shared(m);
    sc.return_to_sender(sbt);

    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    let mut m2 = sc.take_shared<MemorialMoment>();
    memorial_hall::finalize_season(&cap, &mut m2, STATUS_FINALIZED);
    ts::return_shared(m2);
    ts::return_to_address(ADMIN, cap);

    // CAROL tries to mint badge without ever voting
    sc.next_tx(CAROL);
    let m3 = sc.take_shared<MemorialMoment>();
    let mut carol_sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::mint_guardian_badge(&m3, &mut carol_sbt, &clk, sc.ctx());
    ts::return_shared(m3);
    sc.return_to_sender(carol_sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

/// [DEFENDED] Double badge mint for same moment → dynamic_field duplicate key abort.
/// Uses Sui's built-in abort (EFieldAlreadyExists) — arbitrary abort code accepted.
#[test]
#[expected_failure]
fun rt_4d_double_badge_mint_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ATTACKER);
    let mut m = sc.take_shared<MemorialMoment>();
    let mut sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::vote_moment(&mut m, &mut sbt, 1, &clk);
    ts::return_shared(m);
    sc.return_to_sender(sbt);

    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    let mut m2 = sc.take_shared<MemorialMoment>();
    memorial_hall::finalize_season(&cap, &mut m2, STATUS_FINALIZED);
    ts::return_shared(m2);
    ts::return_to_address(ADMIN, cap);

    sc.next_tx(ATTACKER);
    let m3 = sc.take_shared<MemorialMoment>();
    let mut sbt2 = sc.take_from_sender<FanSBT>();
    memorial_hall::mint_guardian_badge(&m3, &mut sbt2, &clk, sc.ctx());
    memorial_hall::mint_guardian_badge(&m3, &mut sbt2, &clk, sc.ctx()); // abort
    ts::return_shared(m3);
    sc.return_to_sender(sbt2);
    clock::destroy_for_testing(clk);
    sc.end();
}

// =====================================================================
// Round 5 — Proposer Self-Vote Economic Attack
// =====================================================================

/// [⚠️ FLAG / BY-DESIGN] Proposer can immediately vote own moment and lock rank #1
/// (gold tier). 合約層沒有禁止 self-vote — 從合約角度這是 "legitimate point spend"。
/// 但業務邏輯上 proposer 搶 gold tier 自己的 moment 可能不公平。
///
/// 本 test 記錄此行為 — 若產品決定要擋，應加 `assert!(sbt_id != object::id_for_proposer)` 或類似。
/// 目前視為 ACCEPTED DESIGN。
#[test]
fun rt_5_proposer_self_vote_captures_rank1_FLAG() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ATTACKER);
    let mut m = sc.take_shared<MemorialMoment>();
    let mut sbt = sc.take_from_sender<FanSBT>();
    let sbt_id = object::id(&sbt);
    memorial_hall::vote_moment(&mut m, &mut sbt, 1, &clk);

    assert!(memorial_hall::guardian_rank(&m, sbt_id) == 1, 0);
    assert!(memorial_hall::guardian_tier(&m, sbt_id) == 1, 1); // TIER_GOLD
    ts::return_shared(m);
    sc.return_to_sender(sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

// =====================================================================
// Round 6 — Input Fuzzing / Metadata
// =====================================================================

/// [DEFENDED] Empty title/blob_id → abort EEmptyMetadata (106).
/// Description 允許為空（符合直覺）。
#[test]
#[expected_failure(abort_code = 106, location = mon_contracts::memorial_hall)]
fun rt_6_empty_title_rejected() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());

    sc.next_tx(ATTACKER);
    let sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::propose_moment(
        &sbt,
        string::utf8(b""),
        string::utf8(b"desc"),
        string::utf8(b"blob"),
        &clk,
        sc.ctx(),
    );
    sc.return_to_sender(sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

#[test]
#[expected_failure(abort_code = 106, location = mon_contracts::memorial_hall)]
fun rt_6b_empty_blob_rejected() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER);
    let clk = clock::create_for_testing(sc.ctx());

    sc.next_tx(ATTACKER);
    let sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::propose_moment(
        &sbt,
        string::utf8(b"title"),
        string::utf8(b"desc"),
        string::utf8(b""),
        &clk,
        sc.ctx(),
    );
    sc.return_to_sender(sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

// =====================================================================
// Round 7 — DoS / Resource Exhaustion
// =====================================================================

/// [DEFENDED] 100 check-ins — verify no overflow, state consistent, level stable at 2.
/// Acts as baseline for gas cost / storage growth regression.
#[test]
fun rt_7_many_checkins_stable() {
    let mut sc = start();
    mint_for(&mut sc, ATTACKER, FIGHTER);

    sc.next_tx(ATTACKER);
    let mut sbt = sc.take_from_sender<FanSBT>();
    let mut i = 0;
    while (i < 100) {
        fan_sbt::record_check_in(&mut sbt, b"spam", sc.ctx());
        i = i + 1;
    };
    assert!(fan_sbt::check_in_count(&sbt) == 100, 0);
    assert!(fan_sbt::available_points(&sbt) == 100, 1);
    assert!(fan_sbt::level(&sbt) == 2, 2); // auto-upgraded after 3rd
    sc.return_to_sender(sbt);
    sc.end();
}

/// [DEFENDED] Attacker votes 1 point × 50 times → 只有第一次創 entry，其餘累加。
/// total_guardians 保持 1，防止 rank 灌水。
#[test]
fun rt_7b_vote_spam_single_rank_only() {
    let mut sc = start();
    mint_for(&mut sc, ATTACKER, FIGHTER);
    sc.next_tx(ATTACKER);
    let mut sbt = sc.take_from_sender<FanSBT>();
    let mut i = 0;
    while (i < 50) {
        fan_sbt::record_check_in(&mut sbt, b"s", sc.ctx());
        i = i + 1;
    };
    sc.return_to_sender(sbt);
    sc.next_tx(ATTACKER);

    let clk = clock::create_for_testing(sc.ctx());
    propose(&mut sc, ATTACKER, &clk);

    sc.next_tx(ATTACKER);
    let mut m = sc.take_shared<MemorialMoment>();
    let mut sbt2 = sc.take_from_sender<FanSBT>();
    let sbt_id = object::id(&sbt2);
    let mut j = 0;
    while (j < 50) {
        memorial_hall::vote_moment(&mut m, &mut sbt2, 1, &clk);
        j = j + 1;
    };
    assert!(memorial_hall::total_guardians(&m) == 1, 0);
    assert!(memorial_hall::total_points(&m) == 50, 1);
    assert!(memorial_hall::guardian_rank(&m, sbt_id) == 1, 2);
    ts::return_shared(m);
    sc.return_to_sender(sbt2);
    clock::destroy_for_testing(clk);
    sc.end();
}

// =====================================================================
// Round 8 — Combo: State + Access
// =====================================================================

/// [DEFENDED] Lv.1 user tries to propose_moment (not yet station 姐) → EProposerNotStation.
#[test]
#[expected_failure(abort_code = ::mon_contracts::memorial_hall::EProposerNotStation)]
fun rt_8_lv1_propose_blocked() {
    let mut sc = start();
    mint_for(&mut sc, ATTACKER, FIGHTER); // Lv.1 only
    let clk = clock::create_for_testing(sc.ctx());

    sc.next_tx(ATTACKER);
    let sbt = sc.take_from_sender<FanSBT>();
    memorial_hall::propose_moment(
        &sbt,
        string::utf8(b"t"),
        string::utf8(b"d"),
        string::utf8(b"b"),
        &clk,
        sc.ctx(),
    );
    sc.return_to_sender(sbt);
    clock::destroy_for_testing(clk);
    sc.end();
}

/// [DEFENDED] upgrade_to_station called without meeting threshold
/// (2 check-ins) → EUpgradeRequirementsNotMet.
#[test]
#[expected_failure(abort_code = ::mon_contracts::fan_sbt::EUpgradeRequirementsNotMet)]
fun rt_8b_premature_upgrade_blocked() {
    let mut sc = start();
    mint_for(&mut sc, ATTACKER, FIGHTER);
    sc.next_tx(ATTACKER);
    let mut sbt = sc.take_from_sender<FanSBT>();
    fan_sbt::record_check_in(&mut sbt, b"e1", sc.ctx());
    fan_sbt::record_check_in(&mut sbt, b"e2", sc.ctx()); // only 2
    fan_sbt::upgrade_to_station(&mut sbt, sc.ctx());
    sc.return_to_sender(sbt);
    sc.end();
}

/// [DEFENDED] upgrade_to_station on already-Lv.2 SBT → ENotLv1 (idempotent guard).
#[test]
#[expected_failure(abort_code = ::mon_contracts::fan_sbt::ENotLv1)]
fun rt_8c_double_upgrade_blocked() {
    let mut sc = start();
    level_up(&mut sc, ATTACKER); // already Lv.2 via auto-upgrade
    sc.next_tx(ATTACKER);
    let mut sbt = sc.take_from_sender<FanSBT>();
    fan_sbt::upgrade_to_station(&mut sbt, sc.ctx());
    sc.return_to_sender(sbt);
    sc.end();
}
