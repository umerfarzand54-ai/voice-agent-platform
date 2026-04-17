defmodule MyAppWeb.SettingsLive do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    config = %{
      twilio_account_sid: Application.get_env(:my_app, :twilio_account_sid) || "",
      twilio_auth_token: Application.get_env(:my_app, :twilio_auth_token) || "",
      twilio_from_number: Application.get_env(:my_app, :twilio_from_number) || "",
      elevenlabs_api_key: Application.get_env(:my_app, :elevenlabs_api_key) || "",
      sarvam_api_key: Application.get_env(:my_app, :sarvam_api_key) || "",
      claude_api_key: Application.get_env(:my_app, :claude_api_key) || "",
      zoho_refresh_token: Application.get_env(:my_app, :zoho_refresh_token) || "",
      bitrix24_webhook_url: Application.get_env(:my_app, :bitrix24_webhook_url) || "",
      base_url: Application.get_env(:my_app, :base_url) || ""
    }

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:form, to_form(config))
      |> assign(:test_results, %{})

    {:ok, socket}
  end

  @impl true
  def handle_event("test_twilio", _params, socket) do
    result =
      case MyApp.Services.Twilio.list_phone_numbers() do
        {:ok, numbers} -> {:ok, "Connected! #{length(numbers)} phone number(s)"}
        {:error, reason} -> {:error, reason}
      end

    {:noreply, assign(socket, :test_results, Map.put(socket.assigns.test_results, :twilio, result))}
  end

  @impl true
  def handle_event("test_elevenlabs", _params, socket) do
    result =
      case MyApp.Services.ElevenLabs.list_voices() do
        {:ok, voices} -> {:ok, "Connected! #{length(voices)} voice(s) available"}
        {:error, reason} -> {:error, reason}
      end

    {:noreply, assign(socket, :test_results, Map.put(socket.assigns.test_results, :elevenlabs, result))}
  end

  @impl true
  def handle_event("test_sarvam", _params, socket) do
    result =
      case MyApp.Services.SarvamAI.detect_language("Hello namaste") do
        {:ok, lang} -> {:ok, "Connected! Detected: #{lang}"}
        {:error, reason} -> {:error, reason}
      end

    {:noreply, assign(socket, :test_results, Map.put(socket.assigns.test_results, :sarvam, result))}
  end

  @impl true
  def handle_event("test_claude", _params, socket) do
    result =
      case MyApp.Services.Claude.complete([%{role: "user", content: "Say 'OK'"}], max_tokens: 5) do
        {:ok, %{text: text}} -> {:ok, "Connected! Response: #{text}"}
        {:error, reason} -> {:error, reason}
      end

    {:noreply, assign(socket, :test_results, Map.put(socket.assigns.test_results, :claude, result))}
  end

  defp test_badge(nil), do: nil
  defp test_badge({:ok, msg}), do: {:ok, msg}
  defp test_badge({:error, reason}), do: {:error, "#{inspect(reason)}"}
end
