defmodule OpenAperture.Builder do
  use Application

  alias OpenAperture.Builder.Docker.AsyncCmd

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    if !Application.get_env(:openaperture_builder, :skip_goon_check, false), do: AsyncCmd.check_goon
    OpenAperture.Builder.Supervisor.start_link
  end
end