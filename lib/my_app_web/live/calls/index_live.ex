defmodule MyAppWeb.CallsLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Calls

  @impl true
  def mount(_params, _session, socket) do
    calls = Calls.list_calls()

    socket =
      socket
      |> assign(:page_title, "Call History")
      |> assign(:filter_status, nil)
      |> assign(:filter_direction, nil)
      |> stream(:calls, calls)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"status" => status, "direction" => direction}, socket) do
    status = if status == "", do: nil, else: status
    direction = if direction == "", do: nil, else: direction

    calls = Calls.list_calls(status: status, direction: direction)

    socket =
      socket
      |> assign(:filter_status, status)
      |> assign(:filter_direction, direction)
      |> stream(:calls, calls, reset: true)

    {:noreply, socket}
  end

  defp format_duration(nil), do: "—"
  defp format_duration(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}m #{s}s"
  end

  defp status_badge("completed"), do: {"Completed", "bg-emerald-100 text-emerald-700"}
  defp status_badge("in_progress"), do: {"In Progress", "bg-blue-100 text-blue-700"}
  defp status_badge("failed"), do: {"Failed", "bg-red-100 text-red-700"}
  defp status_badge("no_answer"), do: {"No Answer", "bg-slate-100 text-slate-600"}
  defp status_badge("busy"), do: {"Busy", "bg-amber-100 text-amber-700"}
  defp status_badge(s), do: {String.capitalize(s || "Unknown"), "bg-slate-100 text-slate-600"}

  defp outcome_badge("goal_achieved"), do: {"Goal Achieved", "bg-green-100 text-green-700"}
  defp outcome_badge("partial"), do: {"Partial", "bg-yellow-100 text-yellow-700"}
  defp outcome_badge("not_achieved"), do: {"Not Achieved", "bg-red-100 text-red-700"}
  defp outcome_badge("no_answer"), do: {"No Answer", "bg-slate-100 text-slate-500"}
  defp outcome_badge("voicemail"), do: {"Voicemail", "bg-purple-100 text-purple-700"}
  defp outcome_badge(_), do: {nil, ""}
end
