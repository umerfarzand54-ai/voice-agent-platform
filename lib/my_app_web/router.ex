defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :twilio_webhook do
    plug :accepts, ["html", "json", "xml"]
    plug :fetch_session
  end

  scope "/webhooks/twilio", MyAppWeb do
    pipe_through :twilio_webhook

    post "/voice/inbound", TwilioWebhookController, :inbound_voice
    post "/voice/outbound_answer", TwilioWebhookController, :outbound_answer
    post "/voice/gather", TwilioWebhookController, :gather
    post "/voice/status", TwilioWebhookController, :call_status
    post "/voice/recording", TwilioWebhookController, :recording_complete
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :default do
      live "/dashboard", DashboardLive
      live "/agents", AgentsLive.Index
      live "/agents/new", AgentsLive.Form, :new
      live "/agents/:id/edit", AgentsLive.Form, :edit
      live "/calls", CallsLive.Index
      live "/calls/:id", CallsLive.Show
      live "/campaigns", CampaignsLive.Index
      live "/campaigns/new", CampaignsLive.Form, :new
      live "/campaigns/:id/edit", CampaignsLive.Form, :edit
      live "/campaigns/:id", CampaignsLive.Show
      live "/contacts", ContactsLive.Index
      live "/contacts/new", ContactsLive.Form, :new
      live "/contacts/:id/edit", ContactsLive.Form, :edit
      live "/voice-profiles", VoiceProfilesLive.Index
      live "/settings", SettingsLive
    end
  end

  if Application.compile_env(:my_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MyAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
