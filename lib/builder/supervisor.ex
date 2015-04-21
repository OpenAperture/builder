defmodule OpenAperture.Builder.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(OpenAperture.Builder.Dispatcher, []),
      #worker(OpenAperture.Builder.Build, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end