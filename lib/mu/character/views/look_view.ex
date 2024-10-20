defmodule Mu.Character.LookView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView
  alias Mu.Character.ItemView

  def render("look", %{room: room}) do
    description = render("_description", %{description: room.description, extra_descs: room.extra_descs})

    ~E"""
    {room-title id="<%= to_string(room.id) %>"}<%= room.name %>{/room-title}
      <%= description %>
    """
  end

  def render("look.extra", %{room: room, characters: characters, item_instances: item_instances}) do
    lines = [
      render("_exits", %{room: room}),
      render("_items", %{item_instances: item_instances}),
      render("_characters", %{characters: characters})
    ]

    lines
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&newline/1)
  end

  def render("extra_desc", %{extra_desc: extra_desc}) do
    extra_desc.description
  end

  def render("_description", %{description: description, extra_descs: []}), do: description

  def render("_description", %{description: description, extra_descs: extra_descs}) do
    extra_descs
    |> Enum.reject(fn extra_desc -> extra_desc.hidden? end)
    |> Enum.reduce(description, &highlight_keywords(&2, &1))
  end

  def render("exits", %{room: room}) do
    [render("_exits", %{room: room}), "\r\n"]
  end

  def render("peek-exit", %{rooms: rooms}) do
    lines =
      rooms
      |> Enum.map(fn room ->
        case Map.has_key?(room, :door) do
          true ->
            nil

          false ->
            characters = render("_characters", %{characters: room.characters})

            [~i(#{room.name} #{render("_distance", %{distance: room.distance})}\r\n), characters]
            |> Enum.reject(&is_nil(&1))
        end
      end)
      |> View.join("\r\n")

    [~i(You see:\r\n), lines]
  end

  def render("_exits", %{room: room}) do
    exits =
      room.exits
      |> Enum.reject(fn room_exit ->
        room_exit.hidden? || room_exit.secret?
      end)
      |> Enum.map(fn room_exit ->
        ~i({exit name="#{room_exit.exit_name}"}#{room_exit.exit_name}{/exit})
      end)
      |> View.join(", ")

    ~i(Obvious exits: [#{exits}])
  end

  def render("_characters", %{characters: []}), do: nil

  def render("_characters", %{characters: characters}) do
    characters =
      characters
      |> Enum.map(&render("_character", %{character: &1}))
      |> View.join("\r\n")

    View.join(["You see:", characters], "\r\n")
  end

  def render("_character", %{character: character}) do
    ~i(  #{CharacterView.render("name", %{character: character})})
  end

  def render("_items", %{item_instances: []}), do: nil

  def render("_items", %{item_instances: item_instances}) do
    items =
      item_instances
      |> Enum.map(&ItemView.render("dropped_name", %{item_instance: &1, context: :room}))
      |> View.join(", ")

    View.join(["Items:", items], " ")
  end

  def render("item", %{item_instance: item_instance}) do
    item_verbs = Enum.map(item_instance.item.verbs, & &1.text)

    ~E"""
    <%= ItemView.render("name", %{item_instance: item_instance}) %>
      <%= item_instance.item.description %>

    Obvious Verbs: [<%= View.join(item_verbs, ", ") %>]
    """
  end

  def render("character", %{character: character}) do
    [
      CharacterView.render("name", %{character: character})
    ]
  end

  def render("unknown", %{}) do
    ~i(Nothing special there\r\n)
  end

  def render("_distance", %{distance: distance}) do
    case distance do
      1 -> ""
      _ -> ~i(- #{distance} rooms away)
    end
  end

  defp highlight_keywords(description, extra_desc) do
    case description do
      iolist when is_list(iolist) ->
        Enum.map(iolist, &highlight_keywords(&1, extra_desc))

      binary when is_binary(binary) ->
        %{keyword: keyword, highlight_color_override: color_override} = extra_desc
        color = with nil <- color_override, do: "white"
        highlight_text = ~i({color foreground="#{color}"}#{keyword}{/color})

        binary
        |> String.split(extra_desc.keyword)
        |> View.join(highlight_text)

      no_change ->
        no_change
    end
  end

  defp newline(iodata), do: [iodata, "\r\n"]
end
