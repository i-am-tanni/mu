defmodule Mu.Character.LookView.HighlightText do
  defstruct [:color, :text]
end

defmodule Mu.Character.LookView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView
  alias Mu.Character.ItemView
  alias Mu.Character.LookView.HighlightText

  def render("look", %{room: room}) do
    ~E"""
    {room-title id="<%= to_string(room.id) %>"}<%= room.name %>{/room-title}
    """
  end

  def render("look.extra", %{room: room, characters: characters, item_instances: item_instances}) do
    lines = [
      render("_items", %{item_instances: item_instances}),
      render("_exits", %{room: room}),
      render("_characters", %{characters: characters})
    ]

    lines
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn line ->
      [line, "\n"]
    end)
  end

  def render("extra_desc", %{extra_desc: extra_desc}) do
    extra_desc.description
  end

  def render("description", %{description: description, extra_descs: extra_descs}) do
    description =
      extra_descs
      |> Enum.reject(fn extra_desc -> extra_desc.hidden? end)
      |> Enum.reduce(description, &highlight_keywords(&2, &1))

    # if extra_desc keywords were highlighted
    case is_list(description) do
      true -> stringify_highlights(description)
      false -> description
    end
  end

  def render("exits", %{room: room}) do
    [render("_exits", %{room: room}), "\n"]
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

            [~i(#{room.name} #{render("_distance", %{distance: room.distance})}\n), characters]
            |> Enum.reject(&is_nil(&1))
        end
      end)
      |> View.join("\n")

    [~i(You see:\n), lines]
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
      |> View.join("\n")

    View.join(["You see:", characters], "\n")
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
    ~i(Nothing special there\n)
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
        highlight_text = %HighlightText{color: color, text: keyword}

        binary
        |> String.split(extra_desc.keyword)
        |> View.join(highlight_text)

      no_change ->
        no_change
    end
  end

  defp stringify_highlights(iolist) do
    Enum.map(iolist, fn
      list when is_list(list) ->
        stringify_highlights(list)

      %HighlightText{text: text, color: color} ->
        ~i({color foreground="#{color}"}#{text}{/color})

      no_change ->
        no_change
    end)
  end
end
