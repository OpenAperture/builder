defmodule OpenAperture.Builder.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      #worker(OpenAperture.Builder.Dispatcher, []),
      worker(OpenAperture.Builder.MessageManager, []),
      worker(OpenAperture.Builder.BuildLogPublisher, [])

    ]

    supervise(children, strategy: :one_for_one)
  end
end