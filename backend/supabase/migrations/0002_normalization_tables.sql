-- 결 (Gyeol) — 0002 normalization layer
-- 매칭알고리즘 v5 §2 + v7 §2.2 (raw quote 차단 강화)

-- ─────────────────────────────────────────────────────────────
-- normalized_profiles — 정규화 결과 (service_role only)
-- ─────────────────────────────────────────────────────────────

create table normalized_profiles (
    user_id uuid primary key references users(id) on delete cascade,
    profile_version text not null,

    -- 영역별 canonical 정규화 결과 (JSONB)
    -- 매칭 알고리즘 입력으로 사용. 매칭 풀 진입 자격 확인.
    --
    -- 구조:
    -- {
    --   "belief": {
    --     "canonical_principles": [{ "principle": "secular_morality", "weight": "high" }, ...],
    --     "axis_positions": [{ "axis": "transcendent_grounding", "value": -2 }, ...],
    --     "sacred_targets": [{ "target": "personal_autonomy", "stance": "support", "intensity": "moderate" }, ...],
    --     "disgust_targets": [{ "target": "religious_coercion", "intensity": "moderate" }],
    --     "dealbreaker_targets": [...],
    --     "domain_salience": "core" | "important" | "supporting"
    --   },
    --   "society": { ... },
    --   ...
    -- }
    payload jsonb not null,

    raw_quote_detected boolean not null default false,    -- v7 §2.2 차단 표시
    quality_signals jsonb,                                -- depth_distribution, token counts 등

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index idx_normalized_profile_quote on normalized_profiles(raw_quote_detected) where raw_quote_detected;

create trigger trg_normalized_profiles_updated before update on normalized_profiles
for each row execute function set_updated_at();

-- ─────────────────────────────────────────────────────────────
-- canonical dictionary — 정규화 사전 (운영자 관리)
-- ─────────────────────────────────────────────────────────────

create table canonical_principles (
    id text primary key,                                  -- e.g. "secular_morality"
    domain domain_id not null,
    label_korean text not null,
    description text not null,
    aliases text[] not null default '{}',                 -- 자주 등장하는 자유 텍스트
    created_at timestamptz not null default now()
);

create table canonical_targets (
    id text primary key,                                  -- e.g. "religion.strong_devotion"
    domain domain_id not null,
    category text not null,                               -- "religion", "family_role", ...
    label_korean text not null,
    aliases text[] not null default '{}',
    created_at timestamptz not null default now()
);

create table canonical_axes (
    id text primary key,                                  -- e.g. "transcendent_grounding"
    domain domain_id not null,
    label_korean text not null,
    pole_negative text not null,                          -- e.g. "secular"
    pole_positive text not null,                          -- e.g. "transcendent"
    created_at timestamptz not null default now()
);
