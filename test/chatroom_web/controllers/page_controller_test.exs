import {Socket} from "phoenix"
defmodule ChatroomWeb.PageControllerTest do
  use ChatroomWeb.ConnCase
  
  def create_user(username) do
   
    # Use the changeset that will match your model

    
  end

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    {:ok, user} = create_user("jerry")
    {:ok, _, socket} = socket("", %{current_user: "jerry"})
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"

  end
  

  
end
