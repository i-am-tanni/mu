defmodule Mu.Character.TextEditData do
  defstruct [
    :topic,
    :callback,
    :index,
    mode: :write,
    buffer: [],
    insert: [],
    saved: [],
    line_count: 0,
    unsaved_changes?: false
  ]
end

defmodule Mu.Character.EditController.EditParser do
  import NimbleParsec

  def run() do
    choice([save_quit(), save(), quit(), delete(), insert(), replace(), print(), cancel(), load()])
  end

  defp quit() do
    replace(string(":q"), :quit)
    |> unwrap_and_tag(:command)
  end

  defp save() do
    replace(string(":w"), :save)
    |> unwrap_and_tag(:command)
  end

  defp save_quit() do
    replace(string(":wq"), :save_quit)
    |> unwrap_and_tag(:command)
  end

  def load() do
    replace(string(":l"), :load)
    |> unwrap_and_tag(:command)
  end

  defp delete() do
    ignore(string(":"))
    |> optional(choice([range(), index()]))
    |> replace(string("d"), {:command, :delete})
  end

  defp insert() do
    ignore(string(":"))
    |> optional(index())
    |> replace(string("i"), {:command, :insert})
  end

  defp replace() do
    ignore(string(":"))
    |> optional(choice([range(), index()]))
    |> replace(string("s"), {:command, :replace})
    |> ignore(string("/"))
    |> concat(utf8_string([not: ?/, not: ?\r, not: ?\n], min: 1) |> unwrap_and_tag(:pattern))
    |> ignore(string("/"))
    |> concat(utf8_string([not: ?/, not: ?\r, not: ?\n], min: 1) |> unwrap_and_tag(:replacement))
  end

  defp cancel() do
    replace(string(":c"), :cancel)
    |> unwrap_and_tag(:command)
  end

  defp print() do
    replace(string(":p"), :print)
    |> unwrap_and_tag(:command)
  end

  defp range() do
    integer(min: 1, max: 2)
    |> ignore(string(","))
    |> integer(min: 1, max: 2)
    |> tag(:range)
  end

  defp index() do
    integer(min: 1, max: 2)
    |> unwrap_and_tag(:index)
  end
end

defmodule Mu.Character.EditController do
  @moduledoc """
  An edit mode companion to the write controller.
  Has the following commands:
  - :q - quit and discard unsaved changes
  - :wq - save and quit
  - :w - save - stash current text
  - :l - load - discard unsaved changes and load last saved
  - :[index | min,max]d - deletes a line. If no index or range, deletes last line
  - :[index]i - insert on index. If no index, append.
  - :[index | min,max]s/pattern/replacement - find and replace with optional index / range
  """
  use Kalevala.Character.Controller

  import NimbleParsec, only: [defparsec: 2]

  alias Mu.Character.TextEditData
  alias Mu.Character.WriteController
  alias Mu.Character.CommandController
  alias Mu.Character.ConfirmController
  alias Mu.Character.EditController
  alias Mu.Character.WriteView
  alias Mu.Character.CommandView
  alias Mu.Character.LookCommand

  defparsec(:parse, __MODULE__.EditParser.run())
  defdelegate confirm(conn, prompt, callback_fun), to: ConfirmController, as: :put

  def put(conn, topic, text, callback_fun) do
    flash = %TextEditData{
      topic: topic,
      callback: callback_fun,
      buffer: word_wrap(text),
      saved: [],
      insert: [],
      index: nil,
      unsaved_changes?: false,
      mode: :write,
      line_count: 0
    }

    put_controller(conn, __MODULE__, flash)
  end

  @impl true
  def init(conn) do
    %{topic: topic, buffer: buffer} = conn.flash

    conn
    |> put_flash(:mode, :edit)
    |> put_flash(:unsaved_changes?, true)
    |> prompt(WriteView, "topic", %{topic: topic})
    |> prompt(WriteView, "buffer", %{buffer: buffer})
    |> prompt(WriteView, "edit-instructions")
    |> render(CommandView, ">")
  end

  @impl true
  def recv(conn, data) do
    case parse_command(data) do
      {:ok, result} ->
        route(conn, result)

      :error ->
        conn
        |> prompt(WriteView, "invalid-command")
        |> prompt(WriteView, "edit-instructions")
        |> render(CommandView, ">")
    end
  end

  defp route(conn, parsed_result) do
    case parsed_result.command do
      :save -> save(conn)
      :quit -> quit(conn)
      :save_quit -> save_quit(conn)
      :cancel -> cancel(conn)
      :print -> print(conn)
      :load -> load(conn)
      :insert -> insert(conn, parsed_result)
      :delete -> delete(conn, parsed_result)
      :replace -> replace(conn, parsed_result)
    end
  end

  # edit commands

  defp save(conn) do
    conn
    |> put_flash(:saved, get_flash(conn, :buffer))
    |> put_flash(:unsaved_changes?, false)
    |> prompt(WriteView, "saved")
    |> render(CommandView, ">")
  end

  defp save_quit(conn) do
    %{buffer: buffer, callback: callback_fun} = conn.flash
    text = Enum.join(buffer, " ")

    conn
    |> callback_fun.(text)
    |> put_controller(CommandController)
  end

  defp quit(conn) when conn.flash.unsaved_changes? do
    flash = conn.flash

    confirm(conn, "Discard unsaved changes?", fn
      true -> quit_firm(conn)
      false -> put_controller(conn, EditController, flash)
    end)
  end

  defp quit(conn), do: quit_firm(conn)

  defp quit_firm(conn) do
    %{saved: saved, buffer: buffer, callback: callback_fun} = conn.flash
    saved = with [] <- saved, do: buffer
    text = Enum.join(saved)

    conn
    |> callback_fun.(text)
    |> put_controller(CommandController)
    |> LookCommand.room(%{})
  end

  defp cancel(conn) do
    conn
    |> put_controller(CommandController)
    |> LookCommand.room(%{})
  end

  defp load(conn) do
    %{saved: buffer, topic: topic} = conn.flash

    conn
    |> put_flash(:buffer, buffer)
    |> assign(:buffer, buffer)
    |> prompt(WriteView, "topic", %{topic: topic})
    |> prompt(WriteView, "buffer")
    |> prompt(WriteView, "edit-instructions")
    |> render(CommandView, ">")
  end

  defp print(conn) do
    %{buffer: buffer, topic: topic} = conn.flash

    conn
    |> assign(:buffer, buffer)
    |> prompt(WriteView, "topic", %{topic: topic})
    |> prompt(WriteView, "buffer")
    |> prompt(WriteView, "edit-instructions")
    |> render(CommandView, ">")
  end

  defp insert(conn, params) do
    buffer = get_flash(conn, :buffer)
    index = with nil <- params[:index], do: Enum.count(buffer)
    flash = %{conn.flash | mode: :insert, index: index, insert: []}
    put_controller(conn, WriteController, flash)
  end

  defp delete(conn, params) do
    %{buffer: buffer, topic: topic} = conn.flash
    buffer =
      cond do
        index = params[:index] ->
          List.delete_at(buffer, index)

        range = params[:range] ->
          [min, max] = range
          delete_slice(buffer, min, max)

        true ->
          drop_last(buffer)
      end

    conn
    |> put_flash(:buffer, buffer)
    |> prompt(WriteView, "topic", %{topic: topic})
    |> prompt(WriteView, "buffer", %{buffer: buffer})
    |> prompt(WriteView, "edit-instructions")
    |> render(CommandView, ">")
  end

  defp replace(conn, params) do
    %{pattern: pattern, replacement: replacement} = params
    %{buffer: buffer, topic: topic} = conn.flash
    buffer = _replace(buffer, pattern, replacement, params)

    conn
    |> put_flash(:buffer, buffer)
    |> prompt(WriteView, "topic", %{topic: topic})
    |> prompt(WriteView, "buffer", %{buffer: buffer})
    |> prompt(WriteView, "edit-instructions")
    |> render(CommandView, ">")
  end

  # helpers

  defp _replace(buffer, pattern, replacement, %{index: index}) do
    List.update_at(buffer, index, &String.replace(&1, pattern, replacement))
  end

  defp _replace(buffer, pattern, replacement, %{range: [min, max]}) do
    {buffer, _} =
      Enum.map_reduce(buffer, 0, fn
        line, i when i >= min and i <= max ->
          {String.replace(line, pattern, replacement), i + 1}

        no_change, i ->
          {no_change, i + 1}
      end)

    buffer
  end

  defp _replace(buffer, pattern, replacement, _) do
    Enum.map(buffer, &String.replace(&1, pattern, replacement))
  end

  defp delete_slice(list, min, max, i \\ 0)
  defp delete_slice([], _, _, _), do: []
  defp delete_slice([_ | t], min, max, i) when i in min..max//1, do: delete_slice(t, min, max, i + 1)
  defp delete_slice([h | t], min, max, i), do: [h | delete_slice(t, min, max, i + 1)]

  defp drop_last([]), do: []
  defp drop_last([_]), do: []
  defp drop_last([h | t]), do: [h | drop_last(t)]

  defp parse_command(data) do
    case parse(data) do
      {:ok, result, _, _, _, _} -> {:ok, Enum.into(result, %{})}
      _ -> :error
    end
  end

  # chunks text by max width without breaking up words
  @spec word_wrap(binary(), integer) :: list()
  def word_wrap(text, max_cols \\ 80) do
    _word_wrap(text, [], [], [], 0, max_cols)
    |> Enum.reverse()
    |> Enum.map(&Enum.join(&1, " "))
  end

  defp _word_wrap("", chunks, [], [], _, _), do: chunks

  defp _word_wrap("", chunks, curr_line, [], _, _) do
    curr_line = Enum.reverse(curr_line)
    [curr_line | chunks]
  end

  defp _word_wrap("", chunks, curr_line, curr_word, index, max_cols) when index < max_cols do
    curr_word = Enum.reverse(curr_word)
    curr_line = Enum.reverse([curr_word | curr_line])
    [curr_line | chunks]
  end

  defp _word_wrap("", chunks, curr_line, curr_word, _, _) do
    curr_word = Enum.reverse(curr_word)
    curr_line = Enum.reverse([curr_word | curr_line])
    [[curr_word], curr_line | chunks]
  end

  defp _word_wrap(<<grapheme::utf8, text::binary>>, chunks, curr_line, curr_word, index, max_cols) do
    case grapheme do
      ?\s when index >= max_cols ->
        curr_word = Enum.reverse(curr_word)
        curr_line = Enum.reverse(curr_line)
        _word_wrap(text, [curr_line | chunks] , [curr_word], [], length(curr_word), max_cols)

      ?\s ->
        curr_word = Enum.reverse(curr_word)
        _word_wrap(text, chunks, [curr_word | curr_line], [], index + 1, max_cols)

      x when x in [?\r, ?\n] ->
        _word_wrap(text, chunks, curr_line, curr_word, index, max_cols)

      _ ->
        _word_wrap(text, chunks, curr_line, [grapheme | curr_word], index + 1, max_cols)
    end
  end
end

defmodule Mu.Character.WriteController do
  @moduledoc """
  Controller for entering and editing multi-line text such as room descriptions.
  """
  use Kalevala.Character.Controller

  alias Mu.Character.EditController
  alias Mu.Character.CommandView
  alias Mu.Character.WriteView
  alias Mu.Character.TextEditData

  @max_line_count 20

  @doc """
  Wrapper function that prepares the data for the controller

  The callback_fun is called on exit of this controller if text is entered.

  Accepts two arguments:
  1. conn
  2. a string, which is text output for this controller
  """

  def put(conn, topic, callback_fun) do
    flash = %TextEditData{
      topic: topic,
      callback: callback_fun,
      index: nil,
      buffer: [],
      insert: [],
      saved: [],
      unsaved_changes?: false,
      mode: :write,
      line_count: 0
    }

    put_controller(conn, __MODULE__, flash)
  end

  @impl true
  def init(conn) do
    conn
    |> prompt(WriteView, "write-instructions")
    |> render(CommandView, ">")
  end

  @impl true
  def recv(conn, ""), do: render(conn, CommandView, ">")

  def recv(conn, data) when conn.flash.line_count < @max_line_count do
    data = String.replace_trailing(data, "\r\n", "")
    case get_flash(conn, :mode) do
      :write -> write(conn, data)
      :insert -> insert(conn, data)
    end
  end

  def recv(conn, _) do
    conn
    |> prompt(WriteView, "max-lines-reached")
    |> recv("~")
  end

  defp write(conn, data) do
    case data do
      <<?~, _::binary>> ->
        # end reached
        buffer = Enum.reverse(get_flash(conn, :buffer))

        put_controller(conn, EditController, %{conn.flash | buffer: buffer})

      text ->
        %{buffer: buffer, line_count: line_count} = conn.flash

        conn
        |> put_flash(:buffer, [text | buffer])
        |> put_flash(:line_count, line_count + 1)
        |> render(CommandView, ">")
    end
  end

  defp insert(conn, data) do
    case data do
    <<?~, _::binary>> ->
      # end reached
      flash = conn.flash
      %{buffer: buffer, insert: insert, index: index} = flash
      insert = Enum.reverse(insert)
      buffer =
        buffer
        |> List.insert_at(index, insert)
        |> List.flatten()

      put_controller(conn, EditController, %{flash | buffer: buffer})


    text ->
      %{insert: insert, line_count: line_count} = conn.flash

      conn
      |> put_flash(:insert, [text | insert])
      |> put_flash(:line_count, line_count + 1)
      |> render(CommandView, ">")
    end
  end

  @impl true
  def event(conn, _), do: conn
end
