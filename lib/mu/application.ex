defmodule Mu.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    foreman_options = [
      supervisor_name: Mu.Character.Foreman.Supervisor,
      communication_module: Mu.Communication,
      initial_controller: Mu.Character.LoginController,
      presence_module: Mu.Character.Presence,
      quit_view: {Mu.Character.QuitView, "disconnected"}
    ]

    telnet_config = [
      telnet: [
        port: 4444
      ],
      protocol: [
        output_processors: [
          Kalevala.Output.Tags,
          Kalevala.Output.TagColors,
          Kalevala.Output.StripTags
        ]
      ],
      foreman: foreman_options
    ]

    children = [
      {Kalevala.Character.Foreman.Supervisor, [name: Mu.Character.Foreman.Supervisor]},
      {Kalevala.Telnet.Listener, telnet_config}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mu.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
