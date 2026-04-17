defmodule MyAppWeb.Plugs.TwilioSignaturePlug do
  @moduledoc """
  Validates X-Twilio-Signature for all Twilio webhook requests.
  Skip validation in dev/test environments.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:my_app, :validate_twilio_signature, true) do
      validate(conn)
    else
      conn
    end
  end

  defp validate(conn) do
    auth_token =
      Application.get_env(:my_app, :twilio_auth_token) || System.get_env("TWILIO_AUTH_TOKEN", "")

    signature = get_req_header(conn, "x-twilio-signature") |> List.first("")
    url = build_url(conn)
    params = conn.body_params

    if MyApp.Services.Twilio.validate_signature(url, params, signature, auth_token) do
      conn
    else
      conn
      |> send_resp(403, "Forbidden")
      |> halt()
    end
  end

  defp build_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    host = conn.host
    port = conn.port
    path = conn.request_path
    query = conn.query_string

    base = "#{scheme}://#{host}:#{port}#{path}"
    if query && query != "", do: "#{base}?#{query}", else: base
  end
end
