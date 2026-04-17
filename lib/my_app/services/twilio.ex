defmodule MyApp.Services.Twilio do
  @moduledoc """
  Twilio REST API client and TwiML builder.
  """

  @base_url "https://api.twilio.com/2010-04-01"

  # TwiML Builders

  def twiml_gather(opts \\ []) do
    action = Keyword.get(opts, :action, "/webhooks/twilio/voice/gather")
    language = Keyword.get(opts, :language, "en-IN")
    timeout = Keyword.get(opts, :timeout, 5)
    play_url = Keyword.get(opts, :play_url)
    say_text = Keyword.get(opts, :say_text)
    farewell = Keyword.get(opts, :farewell, false)

    inner_content =
      cond do
        play_url ->
          "<Play>#{play_url}</Play>"

        say_text ->
          "<Say language=\"#{language}\">#{xml_escape(say_text)}</Say>"

        true ->
          ""
      end

    if farewell do
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <Response>
        #{if play_url || say_text, do: inner_content, else: ""}
        <Hangup/>
      </Response>
      """
    else
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <Response>
        <Gather input="speech" action="#{action}" method="POST"
                speechTimeout="auto" language="#{language}"
                speechModel="phone_call" enhanced="true"
                timeout="#{timeout}">
          #{inner_content}
        </Gather>
        <Redirect method="POST">#{action}</Redirect>
      </Response>
      """
    end
  end

  def twiml_voicemail(message, opts \\ []) do
    language = Keyword.get(opts, :language, "en-IN")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
      <Say language="#{language}">#{xml_escape(message)}</Say>
      <Hangup/>
    </Response>
    """
  end

  def twiml_reject do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response>
      <Reject/>
    </Response>
    """
  end

  def twiml_empty do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Response/>
    """
  end

  # REST API

  def initiate_call(to, from, opts \\ []) do
    url = Keyword.get(opts, :url)
    status_callback = Keyword.get(opts, :status_callback)
    machine_detection = Keyword.get(opts, :machine_detection, "Enable")
    timeout = Keyword.get(opts, :timeout, 30)

    params = %{
      "To" => to,
      "From" => from,
      "Url" => url,
      "StatusCallback" => status_callback,
      "StatusCallbackEvent" => "initiated ringing answered completed",
      "StatusCallbackMethod" => "POST",
      "MachineDetection" => machine_detection,
      "Timeout" => timeout
    }

    case rest_request(:post, "/Calls.json", params) do
      {:ok, %{"sid" => sid, "status" => status}} ->
        {:ok, %{sid: sid, status: status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def end_call(call_sid) do
    rest_request(:post, "/Calls/#{call_sid}.json", %{"Status" => "completed"})
  end

  def get_call(call_sid) do
    rest_request(:get, "/Calls/#{call_sid}.json")
  end

  def list_phone_numbers do
    case rest_request(:get, "/IncomingPhoneNumbers.json") do
      {:ok, %{"incoming_phone_numbers" => numbers}} ->
        {:ok, Enum.map(numbers, &%{sid: &1["sid"], phone_number: &1["phone_number"], friendly_name: &1["friendly_name"]})}

      error ->
        error
    end
  end

  def validate_signature(url, params, signature, auth_token) do
    sorted_params = params |> Enum.sort_by(&elem(&1, 0)) |> Enum.map_join(fn {k, v} -> "#{k}#{v}" end)
    expected = :crypto.mac(:hmac, :sha, auth_token, url <> sorted_params) |> Base.encode64()
    Plug.Crypto.secure_compare(expected, signature)
  end

  defp rest_request(method, path, params \\ nil) do
    account_sid = Application.get_env(:my_app, :twilio_account_sid) || System.get_env("TWILIO_ACCOUNT_SID")
    auth_token = Application.get_env(:my_app, :twilio_auth_token) || System.get_env("TWILIO_AUTH_TOKEN")

    url = "#{@base_url}/Accounts/#{account_sid}#{path}"

    opts = [auth: {account_sid, auth_token}]
    opts = if params, do: Keyword.put(opts, :form, params), else: opts

    case apply(Req, method, [url, opts]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "Twilio error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
