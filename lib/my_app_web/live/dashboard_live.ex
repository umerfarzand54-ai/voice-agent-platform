defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  alias MyApp.Calls

  @refresh_interval 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "calls:active")
      Process.send_after(self(), :refresh_stats, @refresh_interval)
    end

    stats = Calls.get_dashboard_stats()
    active_calls = Calls.list_active_calls()
    recent_calls = Calls.list_calls(limit: 10, status: "completed")
    chart_data = Calls.calls_last_7_days()

    socket =
      socket
      |> assign(:stats, stats)
      |> assign(:chart_data, Jason.encode!(Enum.map(chart_data, fn {date, count} -> %{date: Date.to_string(date), count: count} end)))
      |> stream(:active_calls, active_calls)
      |> stream(:recent_calls, recent_calls)
      |> assign(:page_title, "Dashboard")

    {:ok, socket}
  end

  @impl true
  def handle_info({:call_started, call}, socket) do
    {:noreply, stream_insert(socket, :active_calls, call)}
  end

  @impl true
  def handle_info({:call_updated, call}, socket) do
    if call.status in ["completed", "failed", "busy", "no_answer", "cancelled"] do
      socket =
        socket
        |> stream_delete(:active_calls, call)
        |> stream_insert(:recent_calls, call, at: 0)

      {:noreply, socket}
    else
      {:noreply, stream_insert(socket, :active_calls, call)}
    end
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    Process.send_after(self(), :refresh_stats, @refresh_interval)
    stats = Calls.get_dashboard_stats()
    {:noreply, assign(socket, :stats, stats)}
  end

  defp format_duration(nil), do: "—"
  defp format_duration(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}m #{s}s"
  end

  defp status_color("in_progress"), do: "bg-green-100 text-green-700"
  defp status_color("ringing"), do: "bg-yellow-100 text-yellow-700"
  defp status_color("initiated"), do: "bg-blue-100 text-blue-700"
  defp status_color("completed"), do: "bg-slate-100 text-slate-600"
  defp status_color("failed"), do: "bg-red-100 text-red-700"
  defp status_color(_), do: "bg-slate-100 text-slate-600"

  defp sentiment_color("positive"), do: "text-green-600"
  defp sentiment_color("negative"), do: "text-red-500"
  defp sentiment_color(_), do: "text-slate-400"

  defp sentiment_icon("positive"), do: "hero-face-smile"
  defp sentiment_icon("negative"), do: "hero-face-frown"
  defp sentiment_icon(_), do: "hero-minus-circle"
end
