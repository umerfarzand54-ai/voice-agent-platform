defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: "/dashboard")
  end
end
