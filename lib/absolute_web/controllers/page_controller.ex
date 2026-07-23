defmodule AbsoluteWeb.PageController do
  use AbsoluteWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def aws_guide(conn, _params) do
    render(conn, :aws_guide)
  end
end
