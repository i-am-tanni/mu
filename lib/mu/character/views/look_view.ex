defmodule Mu.Character.LookView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView
  alias Mu.Character.ItemView

  def render("look", %{room: room}) do
    ~E"""
    <%= room.name %>
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

    ~i(Exits: [#{exits}])
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
      |> Enum.map(&ItemView.render("name", %{item_instance: &1, context: :room}))
      |> View.join(", ")

    View.join(["Items:", items], " ")
  end

  def render("item", %{item_instance: item_instance}) do
    [
      [ItemView.render("name", %{item_instance: item_instance}), "\n"],
      ~i(  #{item_instance.item.description}\n)
    ]
  end

  def render("character", %{character: character}) do
    [
      CharacterView.render("name", %{character: character})
    ]
  end

  def render("unknown", %{text: text}) do
    ~i(Could not find: "#{text}")
  end
end
