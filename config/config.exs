import Config

config :predicate_to_ecto_converter, Predicates.Repo,
  ecto_repos: [Predicates.Repo],
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("TEST_DB_USER") || System.get_env("DB_USER") || "bxpoc",
  password: System.get_env("TEST_DB_PW") || System.get_env("DB_PW") || "bxpoc",
  database: System.get_env("TEST_DB_DATABASE") || System.get_env("DB_DATABASE") || "bxpoc",
  hostname: System.get_env("TEST_DB_HOST") || System.get_env("DB_HOST") || "localhost",
  port: System.get_env("TEST_DB_PORT") || System.get_env("DB_PORT") || "5432",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.get_env("TEST_DB_POOL_SIZE") || System.get_env("DB_POOL_SIZE") || 20
