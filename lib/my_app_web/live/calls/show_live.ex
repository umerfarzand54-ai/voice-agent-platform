defmodule MyAppWeb.CallsLive.Show do
  use MyAppWeb, :live_view

  alias MyApp.Calls

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    call = Calls.get_call!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "call:#{id}")
    end

    socket =
      socket
      |> assign(:page_title, "Call ##{id}")
      |> assign(:call, call)
      |> stream(:turns, call.conversation_turns)
      |> assign(:recording_url, call.recording_url)

    {:ok, socket}
  end

  @impl true
  def handle_info({:turn_added, turn}, socket) do
    {:noreply, stream_insert(socket, :turns, turn, at: -1)}
  end

  @impl true
  def handle_info({:call_updated, call}, socket) do
    {:noreply, assign(socket, :call, call)}
  end

  @impl true
  def handle_info({:recording_ready, url}, socket) do
    {:noreply, assign(socket, :recording_url, url)}
  end

  @impl true
  def handle_event("sync_crm", _params, socket) do
    call = socket.assigns.call

    Task.start(fn ->
      if call.contact_id do
        contact = MyApp.Contacts.get_contact!(call.contact_id)

        cond do
          Application.get_env(:my_app, :zoho_refresh_token) ->
            MyApp.Services.ZohoCRM.sync_call(call, contact)

          Application.get_env(:my_app, :bitrix24_webhook_url) ->
            MyApp.Services.Bitrix24.sync_call(call, contact)

          true ->
            :ok
        end

        Calls.update_call(call, %{crm_synced: true, crm_synced_at: DateTime.utc_now()})
      end
    end)

    {:noreply, put_flash(socket, :info, "CRM sync initiated!")}
  end

  defp format_duration(nil), do: "—"
  defp format_duration(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}m #{String.pad_leading("#{s}", 2, "0")}s"
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt) do
    Calendar.strftime(dt, "%d %b %Y, %I:%M %p")
  end

  defp role_style("user"), do: {"bg-slate-100 text-slate-800", "self-start", "User"}
  defp role_style("assistant"), do: {"bg-indigo-600 text-white", "self-end", "Agent"}
  defp role_style(_), do: {"bg-amber-100 text-amber-800", "self-start", "System"}

  defp sentiment_badge("positive"), do: {"Positive", "bg-green-100 text-green-700"}
  defp sentiment_badge("negative"), do: {"Negative", "bg-red-100 text-red-700"}
  defp sentiment_badge("neutral"), do: {"Neutral", "bg-slate-100 text-slate-600"}
  defp sentiment_badge(_), do: {nil, ""}

  defp outcome_color("goal_achieved"), do: "text-green-600"
  defp outcome_color("not_achieved"), do: "text-red-500"
  defp outcome_color(_), do: "text-slate-500"
end
