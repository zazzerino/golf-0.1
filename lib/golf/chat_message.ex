defmodule Golf.ChatMessage do
  alias __MODULE__

  defstruct [:session_id, :username, :text, :sent_at]

  def new(session_id, username, text) do
    %ChatMessage{
      session_id: session_id,
      username: username,
      text: text,
      sent_at: DateTime.utc_now()
    }
  end
end
