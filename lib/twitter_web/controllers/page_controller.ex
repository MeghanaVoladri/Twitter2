defmodule TwitterCloneWeb.PageController do
  use TwitterCloneWeb, :controller

  def index(conn, _params) do
    render conn, "home.html"
  end

  def dashboard(conn, _params) do
    render conn, "dashboard.html"
  end
end
