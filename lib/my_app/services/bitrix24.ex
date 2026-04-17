defmodule MyApp.Services.Bitrix24 do
  @moduledoc """
  Bitrix24 CRM integration via REST webhooks.
  """

  def sync_call(call, contact) do
    with {:ok, crm_id} <- find_or_create_contact(contact),
         {:ok, _} <- register_call_activity(call, crm_id, contact) do
      {:ok, %{crm_id: crm_id}}
    end
  end

  def import_contacts(opts \\ []) do
    start = Keyword.get(opts, :start, 0)

    body = %{
      filter: %{"!PHONE" => false},
      select: ["ID", "NAME", "LAST_NAME", "PHONE", "EMAIL"],
      start: start
    }

    case request(:post, "crm.contact.list", body) do
      {:ok, %{"result" => contacts}} ->
        mapped =
          Enum.map(contacts, fn c ->
            phone = get_in(c, ["PHONE", Access.at(0), "VALUE"])

            %{
              name: "#{c["NAME"]} #{c["LAST_NAME"]}" |> String.trim(),
              phone_number: normalize_phone(phone),
              email: get_in(c, ["EMAIL", Access.at(0), "VALUE"]),
              crm_source: "bitrix24",
              crm_id: c["ID"],
              meta: %{}
            }
          end)
          |> Enum.filter(&(&1.phone_number != nil))

        {:ok, mapped}

      error ->
        error
    end
  end

  defp find_or_create_contact(contact) do
    search_body = %{
      filter: %{"PHONE" => contact.phone_number},
      select: ["ID"]
    }

    case request(:post, "crm.contact.list", search_body) do
      {:ok, %{"result" => [%{"ID" => id} | _]}} ->
        {:ok, id}

      _ ->
        [first | rest] = String.split(contact.name || "Unknown", " ")
        last = Enum.join(rest, " ")

        create_body = %{
          fields: %{
            "NAME" => first,
            "LAST_NAME" => last,
            "PHONE" => [%{"VALUE" => contact.phone_number, "VALUE_TYPE" => "WORK"}],
            "EMAIL" => if(contact.email, do: [%{"VALUE" => contact.email, "VALUE_TYPE" => "WORK"}], else: []),
            "SOURCE_ID" => "AI_VOICE_AGENT"
          }
        }

        case request(:post, "crm.contact.add", create_body) do
          {:ok, %{"result" => id}} -> {:ok, "#{id}"}
          error -> error
        end
    end
  end

  defp register_call_activity(call, crm_id, _contact) do
    direction = if call.direction == "outbound", do: 1, else: 2

    body = %{
      USER_PHONE_INNER: Application.get_env(:my_app, :bitrix24_phone) || "",
      USER_ID: 1,
      PHONE_NUMBER: call.to_number || call.from_number,
      TYPE: direction,
      CALL_START_DATE: format_datetime(call.started_at),
      CRM_CREATE: 0,
      CRM_SOURCE: "CONTACT_ID",
      CRM_ENTITY_TYPE: "CONTACT",
      CRM_ENTITY_ID: crm_id,
      SHOW: 0,
      CALL_DURATION: call.duration_seconds || 0,
      CALL_FAILED_CODE: call.status == "completed" and 0 or 1,
      CALL_FAILED_REASON: call.outcome_notes || "",
      RECORD_URL: call.recording_url || ""
    }

    request(:post, "telephony.externalcall.finish", body)
  end

  defp request(method, endpoint, body \\ %{}) do
    webhook_url = Application.get_env(:my_app, :bitrix24_webhook_url) || System.get_env("BITRIX24_WEBHOOK_URL")

    unless webhook_url do
      {:error, "Bitrix24 webhook URL not configured"}
    else
      url = "#{webhook_url}/#{endpoint}.json"

      opts =
        case method do
          :get -> [params: body]
          :post -> [json: body]
        end

      case apply(Req, method, [url, opts]) do
        {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, "Bitrix24 error #{status}: #{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp normalize_phone(nil), do: nil
  defp normalize_phone(phone) do
    digits = String.replace(phone, ~r/[^\d]/, "")
    cond do
      String.length(digits) == 10 -> "+91#{digits}"
      String.starts_with?(digits, "91") and String.length(digits) == 12 -> "+#{digits}"
      true -> "+#{digits}"
    end
  end

  defp format_datetime(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp format_datetime(dt), do: DateTime.to_iso8601(dt)
end
