defmodule AshDeskWeb.Helpers do
  def relative_time(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      diff < 2_592_000 -> "#{div(diff, 86_400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  def relative_time(_), do: ""
end
