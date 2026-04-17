defmodule MyApp.Calls do
  import Ecto.Query
  alias MyApp.Repo
  alias MyApp.Calls.{Call, ConversationTurn}

  def list_calls(opts \\ []) do
    query =
      Call
      |> order_by([c], desc: c.inserted_at)
      |> preload([:ai_agent, :contact])

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, [c], c.status == ^status)
      end

    query =
      case Keyword.get(opts, :direction) do
        nil -> query
        dir -> where(query, [c], c.direction == ^dir)
      end

    query =
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> limit(query, ^limit)
      end

    Repo.all(query)
  end

  def list_active_calls do
    Call
    |> where([c], c.status in ["initiated", "ringing", "in_progress"])
    |> order_by([c], desc: c.started_at)
    |> preload([:ai_agent, :contact])
    |> Repo.all()
  end

  def get_call!(id) do
    Call
    |> Repo.get!(id)
    |> Repo.preload([:ai_agent, :contact, :conversation_turns])
  end

  def get_call_by_sid(sid) do
    Repo.get_by(Call, twilio_call_sid: sid)
  end

  def create_call(attrs) do
    %Call{}
    |> Call.changeset(attrs)
    |> Repo.insert()
  end

  def update_call(%Call{} = call, attrs) do
    call
    |> Call.changeset(attrs)
    |> Repo.update()
  end

  def change_call(%Call{} = call, attrs \\ %{}) do
    Call.changeset(call, attrs)
  end

  def add_conversation_turn(call_id, attrs) do
    turn_index = next_turn_index(call_id)

    %ConversationTurn{}
    |> ConversationTurn.changeset(Map.merge(attrs, %{call_id: call_id, turn_index: turn_index, inserted_at: DateTime.utc_now()}))
    |> Repo.insert()
  end

  def list_conversation_turns(call_id) do
    ConversationTurn
    |> where([t], t.call_id == ^call_id)
    |> order_by([t], asc: t.turn_index)
    |> Repo.all()
  end

  defp next_turn_index(call_id) do
    result = Repo.one(from t in ConversationTurn, where: t.call_id == ^call_id, select: max(t.turn_index))
    (result || -1) + 1
  end

  def get_dashboard_stats do
    today = Date.utc_today()
    today_start = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")

    total_today =
      Repo.aggregate(from(c in Call, where: c.inserted_at >= ^today_start), :count)

    active_now =
      Repo.aggregate(from(c in Call, where: c.status in ["initiated", "ringing", "in_progress"]), :count)

    completed_today =
      Repo.aggregate(from(c in Call, where: c.inserted_at >= ^today_start and c.status == "completed"), :count)

    avg_duration =
      Repo.one(from c in Call, where: c.status == "completed" and c.inserted_at >= ^today_start, select: avg(c.duration_seconds)) || 0

    goals_achieved =
      Repo.aggregate(from(c in Call, where: c.inserted_at >= ^today_start and c.outcome == "goal_achieved"), :count)

    goal_rate = if completed_today > 0, do: round(goals_achieved / completed_today * 100), else: 0

    %{
      total_today: total_today,
      active_now: active_now,
      completed_today: completed_today,
      avg_duration: round(avg_duration),
      goal_rate: goal_rate
    }
  end

  def calls_last_7_days do
    cutoff = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)

    Call
    |> where([c], c.inserted_at >= ^cutoff)
    |> group_by([c], fragment("DATE(? AT TIME ZONE 'UTC')", c.inserted_at))
    |> select([c], {fragment("DATE(? AT TIME ZONE 'UTC')", c.inserted_at), count(c.id)})
    |> order_by([c], fragment("DATE(? AT TIME ZONE 'UTC')", c.inserted_at))
    |> Repo.all()
  end
end
