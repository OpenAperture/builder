defmodule OpenAperture.Builder.MessageManagerTests do
  use ExUnit.Case

  alias OpenAperture.Builder.MessageManager

  # ===================================
  # track tests

  test "remove success" do

    MessageManager.track(%{subscription_handler: %{}, delivery_tag: "delivery_tag"})
    message = MessageManager.remove("delivery_tag")
    assert message != nil
    assert message[:subscription_handler] == %{}
    assert message[:delivery_tag] == "delivery_tag"
  end  
end