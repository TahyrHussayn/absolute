defmodule Absolute.ExAwsReq do
  @moduledoc """
  A custom HTTP client for ExAws that uses `Req` instead of `hackney`.
  This allows us to completely remove `hackney` from the project to avoid
  its known security vulnerabilities (e.g., SSRF, CRLF injections).
  """
  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, req_body, headers, _http_opts) do
    req =
      Req.new(
        method: method,
        url: url,
        headers: headers,
        body: req_body
      )

    case Req.request(req) do
      {:ok, %Req.Response{status: status, body: body, headers: resp_headers}} ->
        # ExAws expects headers as a list of tuples with String values
        formatted_headers = Enum.map(resp_headers, fn {k, v} -> {k, Enum.join(v, ", ")} end)

        {:ok,
         %{
           status_code: status,
           body: body,
           headers: formatted_headers
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
