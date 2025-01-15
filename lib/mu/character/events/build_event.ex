defmodule Mu.Character.BuildEvent do
  use Kalevala.Character.Event

  alias Mu.Character.BuildView
  alias Mu.Character.EditController
  alias Mu.World.NonPlayers
  alias Mu.World.Kickoff

  def dig(conn, %{data: %{exit_name: exit_name}}) do
    conn
    |> assign(:exit_name, exit_name)
    |> render(BuildView, "dig")
    |> request_movement(exit_name)
    |> assign(:prompt, false)
  end

  def edit_desc(conn, %{data: %{description: description}}) do
    EditController.put(conn, "Room Description", description, fn conn, text ->
      data = %{key: :description, val: text}

      conn
      |> event("room/set", data)
      |> assign(:prompt, false)
    end)
  end

  def create_mobile(conn, event) do
    %{zone_id: zone_id, id: id, keywords: keywords} = event.data
    template_id = "#{zone_id}.#{id}"

    get_prototype =
      case NonPlayers.get(template_id) do
        {_, :not_found} ->
          prototype = prototype_mob(template_id, conn.character.room_id, zone_id, keywords)
          {:ok, prototype}

        _ ->
          {:error, {:mobile, "id-already-taken"}}
      end

    spawn_result =
      with {:ok, mobile} <- get_prototype,
           {:ok, _} <- Kickoff.spawn_mobile(mobile) |> replace_error("failed_to_spawn"),
           do: NonPlayers.put(template_id, mobile)

    case spawn_result do
      :ok ->
        conn

      {:error, error} ->
        conn
        |> assign(:id, template_id)
        |> prompt(BuildView, {:mobile, error})
    end
  end

  defp prototype_mob(template_id, room_id, zone_id, keywords) do
    brain = %Mu.Brain{
      id: :brain_not_loaded,
      root: %Kalevala.Brain.NullNode{}
    }

    %Kalevala.Character{
      id: template_id,
      name: "Mobile Prototype",
      description: "Default Description",
      brain: brain,
      room_id: room_id,
      inventory: [],
      meta: %Mu.Character.NonPlayerMeta{
        move_delay: 60_000,
        keywords: keywords,
        pose: :pos_standing,
        pronouns: Mu.Character.Pronouns.get(:male),
        zone_id: zone_id,
        initial_events: [],
        in_combat?: false,
        flags: %Mu.Character.NonPlayerFlags{}
      }
    }
  end

  defp replace_error(result, replacement) do
    with {:error, _} <- result, do: {:error, replacement}
  end
end
