# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mime, :types, %{
  "audio/mp4" => ["m4a"]
}

config :mime, :extensions, %{
  "m4a" => "audio/mp4"
}

config :my_app,
  ecto_repos: [MyApp.Repo],
  generators: [timestamp_type: :utc_datetime],
  # AI & Telephony API Keys (override via environment variables in runtime.exs)
  twilio_account_sid: System.get_env("TWILIO_ACCOUNT_SID"),
  twilio_auth_token: System.get_env("TWILIO_AUTH_TOKEN"),
  twilio_from_number: System.get_env("TWILIO_FROM_NUMBER"),
  elevenlabs_api_key: System.get_env("ELEVENLABS_API_KEY"),
  sarvam_api_key: System.get_env("SARVAM_API_KEY"),
  claude_api_key: System.get_env("CLAUDE_API_KEY"),
  zoho_refresh_token: System.get_env("ZOHO_REFRESH_TOKEN"),
  zoho_client_id: System.get_env("ZOHO_CLIENT_ID"),
  zoho_client_secret: System.get_env("ZOHO_CLIENT_SECRET"),
  bitrix24_webhook_url: System.get_env("BITRIX24_WEBHOOK_URL"),
  base_url: System.get_env("APP_BASE_URL", "http://localhost:4000"),
  validate_twilio_signature: System.get_env("VALIDATE_TWILIO_SIGNATURE", "false") == "true"

# Configure the endpoint
config :my_app, MyAppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MyAppWeb.ErrorHTML, json: MyAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MyApp.PubSub,
  live_view: [signing_salt: "GSwFksf4"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  my_app: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  my_app: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
