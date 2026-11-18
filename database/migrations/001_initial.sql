CREATE TABLE users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('client', 'washer', 'dispatcher'))
);

CREATE TABLE washers (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL UNIQUE REFERENCES users(id),
  name TEXT NOT NULL
);

CREATE TABLE wash_requests (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL REFERENCES users(id),
  vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('hatchback', 'sedan', 'suv', 'van')),
  plate TEXT NOT NULL,
  tier TEXT NOT NULL CHECK (tier IN ('economy', 'professional')),
  address TEXT NOT NULL,
  start_at TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('submitted', 'accepted', 'in_progress', 'completed', 'cancelled')),
  washer_id TEXT REFERENCES washers(id),
  accepted_by TEXT REFERENCES users(id),
  accepted_at TIMESTAMPTZ,
  arrived_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  cancel_reason TEXT,
  cancelled_by TEXT REFERENCES users(id),
  cancelled_at TIMESTAMPTZ,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  CHECK (
    (status = 'submitted' AND washer_id IS NULL) OR
    (status = 'accepted' AND washer_id IS NOT NULL AND accepted_by IS NOT NULL AND accepted_at IS NOT NULL) OR
    (status = 'in_progress' AND washer_id IS NOT NULL AND arrived_at IS NOT NULL) OR
    (status = 'completed' AND finished_at IS NOT NULL) OR
    (status = 'cancelled' AND cancel_reason IS NOT NULL AND cancelled_by IS NOT NULL AND cancelled_at IS NOT NULL)
  )
);

CREATE INDEX requests_client ON wash_requests(client_id);
CREATE INDEX requests_start ON wash_requests(start_at, id);
CREATE INDEX requests_active_washer ON wash_requests(washer_id) WHERE status IN ('accepted', 'in_progress');

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  application TEXT NOT NULL CHECK (application IN ('mobile', 'backoffice')),
  transport TEXT NOT NULL CHECK (transport IN ('bearer', 'cookie')),
  created_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  CHECK (expires_at > created_at)
);

CREATE INDEX sessions_user ON sessions(user_id);
