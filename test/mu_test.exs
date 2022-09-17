defmodule MuTest do
  use ExUnit.Case
  doctest Mu

  test "greets the world" do
    assert Mu.hello() == :world
  end
end
