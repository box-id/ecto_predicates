config :ecto_predicates, Predicates.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("TEST_DB_USER") || System.get_env("DB_USER"),
  password: System.get_env("TEST_DB_PW") || System.get_env("DB_PW"),
  database: System.get_env("TEST_DB_DATABASE") || System.get_env("DB_DATABASE"),
  hostname: System.get_env("TEST_DB_HOST") || System.get_env("DB_HOST") || "localhost",
  port: System.get_env("TEST_DB_PORT") || System.get_env("DB_PORT") || "5432",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.get_env("TEST_DB_POOL_SIZE") || System.get_env("DB_POOL_SIZE") || 20
