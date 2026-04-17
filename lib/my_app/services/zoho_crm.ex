defmodule MyApp.Services.ZohoCRM do
  @moduledoc """
  Zoho CRM integration for syncing call outcomes and contact data.
  """

  @base_url "https://www.zohoapis.in/crm/v3"
  @auth_url "https://accounts.zoho.in/oauth/v2/token"

  def sync_call(call, contact) do
    with {:ok, token} <- get_access_token(),
         {:ok, lead_id} <- find_or_create_lead(contact, token),
         {:ok, _} <- create_call_activity(call, lead_id, contact, token) do
      {:ok, %{lead_id: lead_id}}
    end
  end

  def import_leads(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 200)

    with {:ok, token} <- get_access_token() do
      case request(:get, "/Leads", %{page: page, per_page: per_page}, token) do
        {:ok, %{"data" => leads}} ->
          contacts =
            Enum.map(leads, fn lead ->
              %{
                name: "#{lead["First_Name"]} #{lead["Last_Name"]}",
                phone_number: normalize_phone(lead["Phone"] || lead["Mobile"]),
                email: lead["Email"],
                crm_source: "zoho",
                crm_id: lead["id"],
                meta: %{"company" => lead["Company"], "lead_source" => lead["Lead_Source"]}
              }
            end)
            |> Enum.filter(&(&1.phone_number != nil))

          {:ok, contacts}

        error ->
          error
      end
    end
  end

  defp find_or_create_lead(contact, token) do
    search_params = %{criteria: "(Phone:equals:#{contact.phone_number})", fields: "id,Phone"}

    case request(:get, "/Leads/search", search_params, token) do
      {:ok, %{"data" => [%{"id" => id} | _]}} ->
        {:ok, id}

      _ ->
        body = %{
          data: [
            %{
              "First_Name" => String.split(contact.name || "", " ") |> List.first() || "",
              "Last_Name" => String.split(contact.name || "Unknown", " ") |> List.last() || "Unknown",
              "Phone" => contact.phone_number,
              "Email" => contact.email,
              "Lead_Source" => "AI Voice Agent"
            }
          ]
        }

        case request(:post, "/Leads", body, token) do
          {:ok, %{"data" => [%{"details" => %{"id" => id}} | _]}} -> {:ok, id}
          {:ok, %{"data" => [%{"id" => id} | _]}} -> {:ok, id}
          error -> error
        end
    end
  end

  defp create_call_activity(call, lead_id, _contact, token) do
    outcome_map = %{
      "goal_achieved" => "Interested",
      "partial" => "Follow-up",
      "not_achieved" => "Not Interested",
      "no_answer" => "No Answer",
      "voicemail" => "Left Voicemail"
    }

    body = %{
      data: [
        %{
          "Call_Type" => if(call.direction == "outbound", do: "Outbound", else: "Inbound"),
          "Call_Duration" => format_duration(call.duration_seconds || 0),
          "Call_Start_Time" => format_datetime(call.started_at || call.inserted_at),
          "Subject" => "AI Voice Call - #{Map.get(outcome_map, call.outcome, "Completed")}",
          "Description" => call.outcome_notes || "Automated call by AI Voice Agent",
          "Call_Result" => Map.get(outcome_map, call.outcome, "Completed"),
          "Who_Id" => %{"id" => lead_id, "module" => "Leads"}
        }
      ]
    }

    request(:post, "/Calls", body, token)
  end

  defp get_access_token do
    refresh_token = Application.get_env(:my_app, :zoho_refresh_token) || System.get_env("ZOHO_REFRESH_TOKEN")
    client_id = Application.get_env(:my_app, :zoho_client_id) || System.get_env("ZOHO_CLIENT_ID")
    client_secret = Application.get_env(:my_app, :zoho_client_secret) || System.get_env("ZOHO_CLIENT_SECRET")

    params = %{
      "refresh_token" => refresh_token,
      "client_id" => client_id,
      "client_secret" => client_secret,
      "grant_type" => "refresh_token"
    }

    case Req.post!(@auth_url, form: params) do
      %{status: 200, body: %{"access_token" => token}} -> {:ok, token}
      %{body: body} -> {:error, "Zoho auth failed: #{inspect(body)}"}
    end
  rescue
    e -> {:error, "Zoho auth exception: #{inspect(e)}"}
  end

  defp request(method, path, body_or_params, token) do
    headers = [{"Authorization", "Zoho-oauthtoken #{token}"}, {"content-type", "application/json"}]

    opts =
      case method do
        :get -> [headers: headers, params: body_or_params]
        _ -> [headers: headers, json: body_or_params]
      end

    case apply(Req, method, ["#{@base_url}#{path}", opts]) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "Zoho error #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_phone(nil), do: nil
  defp normalize_phone(phone) do
    digits = String.replace(phone, ~r/[^\d]/, "")
    cond do
      String.length(digits) == 10 -> "+91#{digits}"
      String.starts_with?(digits, "91") and String.length(digits) == 12 -> "+#{digits}"
      String.starts_with?(digits, "0") -> "+91#{String.slice(digits, 1..-1//1)}"
      true -> "+#{digits}"
    end
  end

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{String.pad_leading("#{minutes}", 2, "0")}:#{String.pad_leading("#{secs}", 2, "0")}"
  end

  defp format_datetime(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp format_datetime(dt), do: DateTime.to_iso8601(dt)
end
