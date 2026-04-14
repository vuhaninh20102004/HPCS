
BEGIN;

-- ============================================================================
-- 0. TRIGGER FUNCTION — fn_set_updated_at()
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_set_updated_at()
    IS 'Automatically sets updated_at to now() before each UPDATE. Replaces MySQL ON UPDATE CURRENT_TIMESTAMP.';

-- ============================================================================
-- 1. ROLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS roles (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(50)     NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Unique constraint (idempotent)
DO $$ BEGIN
    ALTER TABLE roles ADD CONSTRAINT uq_roles_name UNIQUE (name);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE  roles              IS 'Lookup table for dynamic role definitions (SUPER_ADMIN, GATE_OPERATOR, TECHNICIAN, MANAGER).';
COMMENT ON COLUMN roles.name         IS 'Unique role identifier, e.g. SUPER_ADMIN, GATE_OPERATOR, TECHNICIAN, MANAGER.';
COMMENT ON COLUMN roles.description  IS 'Human-readable description of the role.';

-- ============================================================================
-- 2. ADMIN_USERS
-- ============================================================================
CREATE TABLE IF NOT EXISTS admin_users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(50)     NOT NULL,
    email           VARCHAR(120)    NOT NULL,
    password_hash   TEXT            NOT NULL,
    full_name       VARCHAR(120)    NOT NULL,
    phone_number    VARCHAR(30),
    role            VARCHAR(30)     NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    last_login_at   TIMESTAMPTZ
);

-- Unique constraints (idempotent)
DO $$ BEGIN
    ALTER TABLE admin_users ADD CONSTRAINT uq_admin_users_username UNIQUE (username);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE admin_users ADD CONSTRAINT uq_admin_users_email UNIQUE (email);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger: updated_at
DO $$ BEGIN
    CREATE TRIGGER trg_admin_users_updated_at
        BEFORE UPDATE ON admin_users
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE  admin_users                IS 'System administrators, security operators, technicians, and managers with login access.';
COMMENT ON COLUMN admin_users.username        IS 'Unique login username.';
COMMENT ON COLUMN admin_users.password_hash   IS 'Bcrypt hash of the password. MUST be a real hash in production.';
COMMENT ON COLUMN admin_users.role            IS 'Role identifier: SUPER_ADMIN | GATE_OPERATOR | TECHNICIAN | MANAGER.';
COMMENT ON COLUMN admin_users.last_login_at   IS 'Timestamp of the most recent successful login.';

-- ============================================================================
-- 3. USERS (students / employees — NOT system admins)
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    student_code    VARCHAR(50),
    full_name       VARCHAR(120)    NOT NULL,
    email           VARCHAR(120),
    phone_number    VARCHAR(30),
    card_uid        VARCHAR(50),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Unique constraints (idempotent)
DO $$ BEGIN
    ALTER TABLE users ADD CONSTRAINT uq_users_student_code UNIQUE (student_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE users ADD CONSTRAINT uq_users_card_uid UNIQUE (card_uid);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger: updated_at
DO $$ BEGIN
    CREATE TRIGGER trg_users_updated_at
        BEFORE UPDATE ON users
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE  users               IS 'End-users (students / employees) who use the parking gates. NOT system administrators.';
COMMENT ON COLUMN users.student_code   IS 'Student or employee ID code (nullable for guests).';
COMMENT ON COLUMN users.card_uid       IS 'UID of the RFID / student card used at the gate.';
COMMENT ON COLUMN users.is_active      IS 'Soft-delete / deactivation flag.';

-- ============================================================================
-- 4. USER_ROLES (many-to-many: users ↔ roles)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_roles (
    user_id     UUID        NOT NULL,
    role_id     UUID        NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    assigned_by UUID,

    PRIMARY KEY (user_id, role_id)
);

-- Foreign keys (idempotent)
DO $$ BEGIN
    ALTER TABLE user_roles
        ADD CONSTRAINT fk_user_roles_user_id
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE user_roles
        ADD CONSTRAINT fk_user_roles_role_id
        FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE user_roles
        ADD CONSTRAINT fk_user_roles_assigned_by
        FOREIGN KEY (assigned_by) REFERENCES admin_users(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE  user_roles              IS 'Junction table linking users to roles (many-to-many).';
COMMENT ON COLUMN user_roles.assigned_by  IS 'Admin who assigned this role to the user.';

-- ============================================================================
-- 5. GATES
-- ============================================================================
CREATE TABLE IF NOT EXISTS gates (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(30)     NOT NULL,
    name        VARCHAR(100)    NOT NULL,
    gate_type   VARCHAR(10)     NOT NULL,
    location    VARCHAR(150),
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    managed_by  UUID,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Unique & check constraints (idempotent)
DO $$ BEGIN
    ALTER TABLE gates ADD CONSTRAINT uq_gates_code UNIQUE (code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE gates ADD CONSTRAINT chk_gates_gate_type CHECK (gate_type IN ('ENTRY', 'EXIT'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- FK: managed_by → admin_users
DO $$ BEGIN
    ALTER TABLE gates
        ADD CONSTRAINT fk_gates_managed_by
        FOREIGN KEY (managed_by) REFERENCES admin_users(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger: updated_at
DO $$ BEGIN
    CREATE TRIGGER trg_gates_updated_at
        BEFORE UPDATE ON gates
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE  gates             IS 'Physical entry/exit gates of the parking facility.';
COMMENT ON COLUMN gates.code        IS 'Unique gate code, e.g. ENTRY_A, EXIT_B.';
COMMENT ON COLUMN gates.gate_type   IS 'ENTRY or EXIT.';
COMMENT ON COLUMN gates.managed_by  IS 'Admin/operator currently responsible for this gate.';

-- ============================================================================
-- 6. DEVICES
-- ============================================================================
CREATE TABLE IF NOT EXISTS devices (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    gate_id             UUID,
    device_code         VARCHAR(50)     NOT NULL,
    device_name         VARCHAR(100)    NOT NULL,
    device_type         VARCHAR(30)     NOT NULL,
    ip_address          INET,
    status              VARCHAR(20)     NOT NULL DEFAULT 'OFFLINE',
    last_heartbeat_at   TIMESTAMPTZ,
    error_count         INTEGER         NOT NULL DEFAULT 0,
    metadata            JSONB,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Unique constraint
DO $$ BEGIN
    ALTER TABLE devices ADD CONSTRAINT uq_devices_device_code UNIQUE (device_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- FK: gate_id → gates
DO $$ BEGIN
    ALTER TABLE devices
        ADD CONSTRAINT fk_devices_gate_id
        FOREIGN KEY (gate_id) REFERENCES gates(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger: updated_at
DO $$ BEGIN
    CREATE TRIGGER trg_devices_updated_at
        BEFORE UPDATE ON devices
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE  devices                    IS 'Hardware devices installed at gates: cameras, barriers, card readers, dispensers, cash modules, LEDs, speakers.';
COMMENT ON COLUMN devices.device_type        IS 'CAMERA | BARRIER | CARD_READER | CARD_DISPENSER | CASH_MODULE | LED | SPEAKER.';
COMMENT ON COLUMN devices.status             IS 'ONLINE | OFFLINE | ERROR | MAINTENANCE.';
COMMENT ON COLUMN devices.last_heartbeat_at  IS 'Last time the device reported a heartbeat.';
COMMENT ON COLUMN devices.metadata           IS 'Flexible JSONB for protocol, port, and device-specific config.';

-- ============================================================================
-- 7. WHITELIST_ENTRIES
-- ============================================================================
CREATE TABLE IF NOT EXISTS whitelist_entries (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    plate_normalized    VARCHAR(20)     NOT NULL,
    plate_display       VARCHAR(20)     NOT NULL,
    owner_name          VARCHAR(120),
    owner_type          VARCHAR(20)     NOT NULL,
    staff_id            VARCHAR(50),
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    valid_from          TIMESTAMPTZ,
    valid_to            TIMESTAMPTZ,
    notes               TEXT,
    created_by          UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Unique constraint
DO $$ BEGIN
    ALTER TABLE whitelist_entries ADD CONSTRAINT uq_whitelist_entries_plate_normalized UNIQUE (plate_normalized);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Check: at least plate_normalized OR staff_id must be non-null
DO $$ BEGIN
    ALTER TABLE whitelist_entries
        ADD CONSTRAINT chk_whitelist_entries_plate_or_staff
        CHECK (plate_normalized IS NOT NULL OR staff_id IS NOT NULL);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- FK: created_by → admin_users
DO $$ BEGIN
    ALTER TABLE whitelist_entries
        ADD CONSTRAINT fk_whitelist_entries_created_by
        FOREIGN KEY (created_by) REFERENCES admin_users(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger: updated_at
DO $$ BEGIN
    CREATE TRIGGER trg_whitelist_entries_updated_at
        BEFORE UPDATE ON whitelist_entries
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_whitelist_entries_staff_id
    ON whitelist_entries (staff_id);
CREATE INDEX IF NOT EXISTS idx_whitelist_entries_is_active
    ON whitelist_entries (is_active);
CREATE INDEX IF NOT EXISTS idx_whitelist_entries_validity
    ON whitelist_entries (valid_from, valid_to);

COMMENT ON TABLE  whitelist_entries                    IS 'Vehicles granted free entry (lecturers, administrators, staff, VIP).';
COMMENT ON COLUMN whitelist_entries.plate_normalized   IS 'License plate in normalized form (uppercase, no spaces).';
COMMENT ON COLUMN whitelist_entries.plate_display      IS 'Original license plate string for display purposes.';
COMMENT ON COLUMN whitelist_entries.owner_type         IS 'LECTURER | ADMINISTRATOR | STAFF | VIP.';
COMMENT ON COLUMN whitelist_entries.staff_id           IS 'Employee or lecturer ID (alternative to plate lookup).';

-- ============================================================================
-- 8. LPR_CAPTURES
-- ============================================================================
CREATE TABLE IF NOT EXISTS lpr_captures (
    id                          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    gate_id                     UUID            NOT NULL,
    capture_phase               VARCHAR(10)     NOT NULL,
    plate_raw                   VARCHAR(30)     NOT NULL,
    plate_normalized            VARCHAR(20)     NOT NULL,
    confidence_score            NUMERIC(5,2)    NOT NULL,
    image_path                  TEXT,
    recognized_text             VARCHAR(20),
    processing_ms               INTEGER,
    is_manual_review_required   BOOLEAN         NOT NULL DEFAULT FALSE,
    processed_at                TIMESTAMPTZ     NOT NULL,
    raw_result                  JSONB,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Check constraints
DO $$ BEGIN
    ALTER TABLE lpr_captures
        ADD CONSTRAINT chk_lpr_captures_capture_phase
        CHECK (capture_phase IN ('ENTRY', 'EXIT'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE lpr_captures
        ADD CONSTRAINT chk_lpr_captures_confidence_score
        CHECK (confidence_score >= 0 AND confidence_score <= 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- FK: gate_id → gates
DO $$ BEGIN
    ALTER TABLE lpr_captures
        ADD CONSTRAINT fk_lpr_captures_gate_id
        FOREIGN KEY (gate_id) REFERENCES gates(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_lpr_captures_gate_id
    ON lpr_captures (gate_id);
CREATE INDEX IF NOT EXISTS idx_lpr_captures_capture_phase
    ON lpr_captures (capture_phase);
CREATE INDEX IF NOT EXISTS idx_lpr_captures_created_at_desc
    ON lpr_captures (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lpr_captures_plate_normalized
    ON lpr_captures (plate_normalized);

COMMENT ON TABLE  lpr_captures                            IS 'License Plate Recognition captures — one record per plate read at a gate.';
COMMENT ON COLUMN lpr_captures.plate_raw                  IS 'Raw OCR string from the LPR engine.';
COMMENT ON COLUMN lpr_captures.plate_normalized           IS 'Normalized plate (uppercase, no spaces).';
COMMENT ON COLUMN lpr_captures.confidence_score           IS 'Recognition confidence from 0.00 to 100.00.';
COMMENT ON COLUMN lpr_captures.image_path                 IS 'Object-storage key (S3/MinIO) of the captured image.';
COMMENT ON COLUMN lpr_captures.processing_ms              IS 'Processing time in milliseconds.';
COMMENT ON COLUMN lpr_captures.is_manual_review_required  IS 'Flag indicating the capture needs a human review (low confidence, etc.).';
COMMENT ON COLUMN lpr_captures.raw_result                 IS 'Full OCR/LPR JSON payload.';

-- ============================================================================
-- 9. PARKING_SESSIONS (central table)
-- ============================================================================
-- Business rules (not enforced by constraints — documented here):
--   1. A ticket_uid must NOT be active across two sessions simultaneously.
--   2. A COMPLETED session must NOT receive additional SUCCESS payments.
--   3. exit_time must be >= entry_time when both are non-NULL.
--   4. If payment_required = FALSE then payment_status = 'NOT_REQUIRED'.
CREATE TABLE IF NOT EXISTS parking_sessions (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    session_code            VARCHAR(50)     NOT NULL,
    session_status          VARCHAR(30)     NOT NULL,
    entry_gate_id           UUID            NOT NULL,
    exit_gate_id            UUID,
    entry_lpr_capture_id    UUID,
    exit_lpr_capture_id     UUID,
    recognized_plate_entry  VARCHAR(20),
    recognized_plate_exit   VARCHAR(20),
    plate_match_status      VARCHAR(20),
    user_id                 UUID,
    whitelist_entry_id      UUID,
    access_policy           VARCHAR(20)     NOT NULL DEFAULT 'PAID',
    payment_required        BOOLEAN         NOT NULL DEFAULT TRUE,
    payment_status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    entry_time              TIMESTAMPTZ     NOT NULL,
    exit_time               TIMESTAMPTZ,
    occupancy_counted       BOOLEAN         NOT NULL DEFAULT FALSE,
    override_by             UUID,
    override_reason         TEXT,
    notes                   TEXT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Unique constraint
DO $$ BEGIN
    ALTER TABLE parking_sessions ADD CONSTRAINT uq_parking_sessions_session_code UNIQUE (session_code);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Foreign keys
DO $$ BEGIN
    ALTER TABLE parking_sessions
        ADD CONSTRAINT fk_parking_sessions_entry_gate_id
        FOREIGN KEY (entry_gate_id) REFERENCES gates(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE parking_sessions
        ADD CONSTRAINT fk_parking_sessions_exit_gate_id
        FOREIGN KEY (exit_gate_id) REFERENCES gates(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE parking_sessions
        ADD CONSTRAINT fk_parking_sessions_entry_lpr_capture_id
        FOREIGN KEY (entry_lpr_capture_id) REFERENCES lpr_captures(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE parking_sessions
        ADD CONSTRAINT fk_parking_sessions_exit_lpr_capture_id
        FOREIGN KEY (exit_lpr_capture_id) REFERENCES lpr_captures(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE parking_sessions
        ADD CONSTRAINT fk_parking_sessions_user_id
        FOREIGN KEY (user_id) REFERENCES users(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE parking_sessions
        ADD CONSTRAINT fk_parking_sessions_whitelist_entry_id
        FOREIGN KEY (whitelist_entry_id) REFERENCES whitelist_entries(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE parking_sessions
        ADD CONSTRAINT fk_parking_sessions_override_by
        FOREIGN KEY (override_by) REFERENCES admin_users(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger: updated_at
DO $$ BEGIN
    CREATE TRIGGER trg_parking_sessions_updated_at
        BEFORE UPDATE ON parking_sessions
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_parking_sessions_session_status
    ON parking_sessions (session_status);
CREATE INDEX IF NOT EXISTS idx_parking_sessions_entry_time_desc
    ON parking_sessions (entry_time DESC);
CREATE INDEX IF NOT EXISTS idx_parking_sessions_exit_time
    ON parking_sessions (exit_time);
CREATE INDEX IF NOT EXISTS idx_parking_sessions_recognized_plate_entry
    ON parking_sessions (recognized_plate_entry);
CREATE INDEX IF NOT EXISTS idx_parking_sessions_recognized_plate_exit
    ON parking_sessions (recognized_plate_exit);
CREATE INDEX IF NOT EXISTS idx_parking_sessions_user_id
    ON parking_sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_parking_sessions_whitelist_entry_id
    ON parking_sessions (whitelist_entry_id);

COMMENT ON TABLE  parking_sessions                          IS 'Central table — each record represents one parking session from entry to exit.';
COMMENT ON COLUMN parking_sessions.session_code             IS 'Human-readable session lookup code.';
COMMENT ON COLUMN parking_sessions.session_status           IS 'INITIATED | PAYMENT_PENDING | PAID | TICKET_ISSUED | ENTERED | EXIT_PENDING | COMPLETED | DENIED | ERROR | OVERRIDDEN.';
COMMENT ON COLUMN parking_sessions.entry_lpr_capture_id     IS 'FK to lpr_captures; set after capture to avoid circular dependency.';
COMMENT ON COLUMN parking_sessions.exit_lpr_capture_id      IS 'FK to lpr_captures; set when the vehicle exits.';
COMMENT ON COLUMN parking_sessions.plate_match_status       IS 'PENDING | MATCHED | MISMATCH | MANUAL_OVERRIDE.';
COMMENT ON COLUMN parking_sessions.access_policy            IS 'PAID | WHITELIST_FREE | DENIED.';
COMMENT ON COLUMN parking_sessions.payment_status           IS 'NOT_REQUIRED | PENDING | PAID | FAILED | CANCELLED.';
COMMENT ON COLUMN parking_sessions.occupancy_counted        IS 'Whether this session has been counted towards the occupancy dashboard.';
COMMENT ON COLUMN parking_sessions.override_by              IS 'Admin who performed a manual override (lost card, proxy swipe, etc.).';
COMMENT ON COLUMN parking_sessions.override_reason          IS 'Free-text reason for the override.';

-- ============================================================================
-- 10. TICKETS
-- ============================================================================
CREATE TABLE IF NOT EXISTS tickets (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id              UUID,
    ticket_uid              VARCHAR(50)     NOT NULL,
    ticket_type             VARCHAR(20)     NOT NULL,
    ticket_status           VARCHAR(20)     NOT NULL DEFAULT 'AVAILABLE',
    issue_gate_id           UUID,
    issued_at               TIMESTAMPTZ,
    retrieved_at            TIMESTAMPTZ,
    retrieved_gate_id       UUID,
    last_blocked_reason     TEXT,
    transaction_id          UUID,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Unique constraints
DO $$ BEGIN
    ALTER TABLE tickets ADD CONSTRAINT uq_tickets_session_id UNIQUE (session_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE tickets ADD CONSTRAINT uq_tickets_ticket_uid UNIQUE (ticket_uid);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Foreign keys
DO $$ BEGIN
    ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_session_id
        FOREIGN KEY (session_id) REFERENCES parking_sessions(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_issue_gate_id
        FOREIGN KEY (issue_gate_id) REFERENCES gates(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE tickets
        ADD CONSTRAINT fk_tickets_retrieved_gate_id
        FOREIGN KEY (retrieved_gate_id) REFERENCES gates(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger: updated_at
DO $$ BEGIN
    CREATE TRIGGER trg_tickets_updated_at
        BEFORE UPDATE ON tickets
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE  tickets                        IS 'Physical tickets (RFID cards or paper tickets) bound to a parking session.';
COMMENT ON COLUMN tickets.ticket_uid             IS 'Unique identifier printed/encoded on the ticket.';
COMMENT ON COLUMN tickets.ticket_type            IS 'RFID_CARD | PAPER_TICKET.';
COMMENT ON COLUMN tickets.ticket_status          IS 'AVAILABLE | ISSUED | IN_USE | RETURNED | BLOCKED | LOST.';
COMMENT ON COLUMN tickets.retrieved_at           IS 'Timestamp when the ticket was returned at exit.';
COMMENT ON COLUMN tickets.transaction_id         IS 'Optional loose FK to payment_transactions if a payment is tied to this ticket.';

-- ============================================================================
-- 11. PAYMENT_TRANSACTIONS
-- ============================================================================
CREATE TABLE IF NOT EXISTS payment_transactions (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID            NOT NULL,
    payment_method      VARCHAR(20)     NOT NULL,
    amount              NUMERIC(12,2)   NOT NULL,
    currency            VARCHAR(10)     NOT NULL DEFAULT 'VND',
    transaction_status  VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    external_ref        VARCHAR(100),
    failure_reason      TEXT,
    paid_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Check constraints
DO $$ BEGIN
    ALTER TABLE payment_transactions
        ADD CONSTRAINT chk_payment_transactions_amount_non_negative
        CHECK (amount >= 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE payment_transactions
        ADD CONSTRAINT chk_payment_transactions_free_access_zero
        CHECK (
            (payment_method <> 'FREE_ACCESS') OR (amount = 0)
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- FK: session_id → parking_sessions
DO $$ BEGIN
    ALTER TABLE payment_transactions
        ADD CONSTRAINT fk_payment_transactions_session_id
        FOREIGN KEY (session_id) REFERENCES parking_sessions(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Trigger: updated_at
DO $$ BEGIN
    CREATE TRIGGER trg_payment_transactions_updated_at
        BEFORE UPDATE ON payment_transactions
        FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_payment_transactions_session_id
    ON payment_transactions (session_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_transaction_status
    ON payment_transactions (transaction_status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_paid_at
    ON payment_transactions (paid_at);

COMMENT ON TABLE  payment_transactions                        IS 'Payment records for parking sessions.';
COMMENT ON COLUMN payment_transactions.payment_method         IS 'STUDENT_CARD (2,000 VND) | CASH (4,000 VND, guard collects) | FREE_ACCESS (whitelist, amount=0).';
COMMENT ON COLUMN payment_transactions.amount                 IS 'Transaction amount; must be 0 when payment_method is FREE_ACCESS.';
COMMENT ON COLUMN payment_transactions.transaction_status     IS 'PENDING | SUCCESS | FAILED | CANCELLED | REFUNDED.';
COMMENT ON COLUMN payment_transactions.external_ref           IS 'Reference code from card gateway or payment provider.';

-- ============================================================================
-- 12. GATE_EVENTS (audit trail — technical)
-- ============================================================================
CREATE TABLE IF NOT EXISTS gate_events (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID,
    gate_id         UUID            NOT NULL,
    device_id       UUID,
    event_type      VARCHAR(50)     NOT NULL,
    event_status    VARCHAR(20)     NOT NULL,
    payload         JSONB,
    error_code      VARCHAR(30),
    error_message   TEXT,
    occurred_at     TIMESTAMPTZ     NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- Foreign keys
DO $$ BEGIN
    ALTER TABLE gate_events
        ADD CONSTRAINT fk_gate_events_session_id
        FOREIGN KEY (session_id) REFERENCES parking_sessions(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE gate_events
        ADD CONSTRAINT fk_gate_events_gate_id
        FOREIGN KEY (gate_id) REFERENCES gates(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE gate_events
        ADD CONSTRAINT fk_gate_events_device_id
        FOREIGN KEY (device_id) REFERENCES devices(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_gate_events_session_id
    ON gate_events (session_id);
CREATE INDEX IF NOT EXISTS idx_gate_events_gate_id
    ON gate_events (gate_id);
CREATE INDEX IF NOT EXISTS idx_gate_events_event_type
    ON gate_events (event_type);
CREATE INDEX IF NOT EXISTS idx_gate_events_occurred_at_desc
    ON gate_events (occurred_at DESC);

COMMENT ON TABLE  gate_events                IS 'Detailed technical event log for every action at a gate.';
COMMENT ON COLUMN gate_events.event_type     IS 'VEHICLE_DETECTED | PLATE_CAPTURED | PAYMENT_STARTED | PAYMENT_SUCCESS | TICKET_ISSUED | BARRIER_OPENED | BARRIER_DENIED | EXIT_MATCHED.';
COMMENT ON COLUMN gate_events.event_status   IS 'SUCCESS | ERROR | WARNING | INFO.';
COMMENT ON COLUMN gate_events.payload        IS 'Arbitrary JSONB data accompanying the event.';

-- ============================================================================
-- 13. AUDIT_LOGS (administrative actions)
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID,
    action          VARCHAR(100)    NOT NULL,
    entity_type     VARCHAR(50)     NOT NULL,
    entity_id       VARCHAR(50)     NOT NULL,
    old_value       JSONB,
    new_value       JSONB,
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- FK: user_id → admin_users
DO $$ BEGIN
    ALTER TABLE audit_logs
        ADD CONSTRAINT fk_audit_logs_user_id
        FOREIGN KEY (user_id) REFERENCES admin_users(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id
    ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_type
    ON audit_logs (entity_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at_desc
    ON audit_logs (created_at DESC);

COMMENT ON TABLE  audit_logs                IS 'Administrative audit trail: login, whitelist changes, manual overrides, config updates.';
COMMENT ON COLUMN audit_logs.action         IS 'Action name, e.g. WHITELIST_UPDATE, SESSION_OVERRIDE, ADMIN_LOGIN.';
COMMENT ON COLUMN audit_logs.entity_type    IS 'Name of the affected table.';
COMMENT ON COLUMN audit_logs.entity_id      IS 'Primary key of the affected record (text form).';
COMMENT ON COLUMN audit_logs.old_value      IS 'JSONB snapshot of the record BEFORE the change.';
COMMENT ON COLUMN audit_logs.new_value      IS 'JSONB snapshot of the record AFTER the change.';

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Default SUPER_ADMIN account
-- ⚠️  REPLACE password_hash WITH A REAL BCRYPT HASH BEFORE DEPLOYING TO PRODUCTION!
INSERT INTO admin_users (username, email, password_hash, full_name, role)
VALUES (
    'superadmin',
    'admin@parking.local',
    'REPLACE_WITH_BCRYPT_HASH',
    'Super Administrator',
    'SUPER_ADMIN'
)
ON CONFLICT (username) DO NOTHING;

-- Default roles
INSERT INTO roles (name, description) VALUES
    ('SUPER_ADMIN',    'Full system access — all operations and configurations.')
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description) VALUES
    ('GATE_OPERATOR',  'Operates entry/exit gates, handles manual overrides.')
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description) VALUES
    ('TECHNICIAN',     'Manages devices, hardware diagnostics, and maintenance.')
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description) VALUES
    ('MANAGER',        'Views reports, dashboards, and manages whitelist entries.')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- DONE
-- ============================================================================
COMMIT;
