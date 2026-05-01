-- 결 (Gyeol) — 0005 canonical 사전 seed (1차 스캐폴드, 운영 단계 보강 필요)

-- principles (영역별 핵심 원칙)
insert into canonical_principles (id, domain, label_korean, description, aliases) values
    -- belief
    ('belief.secular_morality', 'belief', '사회 합의 기반 도덕', '신·사후세계가 아니라 같이 살아가는 사람들 사이의 합의에 도덕 근거를 두는 입장', '{"무신론","합리주의","세속적"}'),
    ('belief.transcendent_grounding', 'belief', '초월적 근거', '도덕·삶의 의미를 종교·영적 차원에서 찾는 입장', '{"신앙","영성","종교"}'),
    ('belief.agnostic_open', 'belief', '열린 미지', '단정 짓지 않고 미지를 인정하는 입장', '{"불가지","열린","미지"}'),
    -- society
    ('society.structural', 'society', '구조 우선', '사회 구조가 개인 행동을 크게 결정한다고 보는 입장', '{"구조주의","사회 책임"}'),
    ('society.individual', 'society', '개인 책임 우선', '개인 책임을 사회 구조보다 무겁게 두는 입장', '{"자유주의","개인주의"}'),
    ('society.balanced', 'society', '균형', '구조와 개인 책임을 함께 고려하는 입장', '{"중도","조건적"}'),
    -- bioethics
    ('bioethics.bodily_autonomy', 'bioethics', '신체적 자기결정권', '본인 신체에 대한 결정권을 우선하는 입장', '{"자기결정권","프로초이스"}'),
    ('bioethics.life_dignity_strong', 'bioethics', '생명 존엄 우선', '잉태 시점부터 생명 존엄을 강하게 두는 입장', '{"프로라이프","생명 존엄"}'),
    ('bioethics.staged_dignity', 'bioethics', '단계적 존엄', '시점에 따라 도덕적 무게가 달라진다고 보는 입장', '{"단계적","조건적"}'),
    -- family
    ('family.self_priority', 'family', '본인 결정권', '부모/가족 의견보다 본인 결정을 우선하는 입장', '{"자율","독립"}'),
    ('family.parental_weight', 'family', '부모 의견 무게', '부모 의견에 결정 중요 변수로 무게를 두는 입장', '{"가족","유교적"}'),
    ('family.balanced_consult', 'family', '협의 균형', '본인 우선이지만 부모 의견을 완전히 배제하지 않는 입장', '{"협의","조율"}'),
    -- work_life
    ('work_life.ambition_priority', 'work_life', '야망 우선', '커리어/성취를 시간/관계보다 무겁게 두는 입장', '{"커리어","성취"}'),
    ('work_life.relationship_priority', 'work_life', '관계 우선', '시간과 관계를 야망보다 무겁게 두는 입장', '{"가족 시간","관계"}'),
    ('work_life.meaning_balance', 'work_life', '의미 균형', '의미를 어디서 찾느냐의 균형을 잡는 입장', '{"의미","균형"}'),
    -- intimacy
    ('intimacy.honesty_first', 'intimacy', '솔직함 우선', '신뢰의 핵심을 즉각적 솔직함에 두는 입장', '{"솔직","투명"}'),
    ('intimacy.boundary_first', 'intimacy', '경계 우선', '신뢰의 핵심을 경계 존중에 두는 입장', '{"경계","사적 영역"}'),
    ('intimacy.warmth_first', 'intimacy', '따뜻함 우선', '신뢰의 핵심을 정서적 따뜻함에 두는 입장', '{"따뜻함","애정"}');

-- targets (sacred / disgust / dealbreaker 가능)
insert into canonical_targets (id, domain, category, label_korean, aliases) values
    ('belief.religion.strong_devotion', 'belief', 'religion', '강한 종교적 신앙', '{"독실","열성"}'),
    ('belief.religion.proselytizing', 'belief', 'religion', '전도 강요', '{"전도","개종 강요"}'),
    ('belief.religion.exclusive', 'belief', 'religion', '배타적 신앙', '{"배타적","유일"}'),
    ('bioethics.abortion.choice', 'bioethics', 'abortion', '선택적 임신중지 허용', '{}'),
    ('bioethics.abortion.prohibit', 'bioethics', 'abortion', '임신중지 금지 입장', '{}'),
    ('family.children.required', 'family', 'children', '자녀를 반드시 가져야 함', '{}'),
    ('family.children.refuse', 'family', 'children', '자녀를 갖지 않음', '{}'),
    ('family.parents_intervention', 'family', 'parents', '부모의 결혼 결정 개입', '{"개입","간섭"}'),
    ('intimacy.cheating', 'intimacy', 'fidelity', '불륜·외도', '{}'),
    ('intimacy.violence', 'intimacy', 'violence', '폭력·강요', '{}'),
    ('work_life.workaholism', 'work_life', 'time', '극단적 워커홀릭', '{}');

-- axes
insert into canonical_axes (id, domain, label_korean, pole_negative, pole_positive) values
    ('belief.transcendent', 'belief', '초월적 근거', 'secular', 'transcendent'),
    ('society.responsibility', 'society', '책임 분배', 'individual', 'structural'),
    ('bioethics.dignity', 'bioethics', '생명 존엄 강도', 'staged', 'absolute'),
    ('family.authority', 'family', '가족 권위', 'self_priority', 'parental_priority'),
    ('work_life.priority', 'work_life', '시간 우선순위', 'relationship', 'ambition'),
    ('intimacy.style', 'intimacy', '신뢰 스타일', 'boundary', 'honesty');
