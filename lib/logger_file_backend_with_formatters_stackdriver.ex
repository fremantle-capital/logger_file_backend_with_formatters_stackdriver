defmodule LoggerFileBackendWithFormattersStackdriver do
  @moduledoc """
  Google Cloud Stackdriver formatter.
  """

  import Jason.Helpers, only: [json_map: 1]

  @behaviour LoggerFileBackendWithFormatters.Formatter

  # @processed_metadata_keys ~w[pid file line function module application]a

  # Severity levels can be found in Google Cloud Logger docs:
  # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#LogSeverity
  @severity_levels [{:debug, "DEBUG"}, {:info, "INFO"}, {:warn, "WARNING"}, {:error, "ERROR"}]

  @doc """
  Builds structured paylpad which is mapped to Google Cloud Logger
  [`LogEntry`](https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry) format.

  See: https://cloud.google.com/logging/docs/agent/configuration#special_fields_in_structured_payloads
  """
  for {level, gcp_level} <- @severity_levels do
    def format_event(
          unquote(level),
          msg,
          ts,
          md,
          %LoggerFileBackendWithFormatters.State{} = state
        ) do
      Map.merge(
        %{
          timestamp: format_timestamp(ts),
          severity: unquote(gcp_level),
          message: IO.iodata_to_binary(msg)
        },
        format_metadata(md, state)
      )
      |> encode()
    end
  end

  def format_event(_level, msg, ts, md, %LoggerFileBackendWithFormatters.State{} = state) do
    Map.merge(
      %{
        timestamp: format_timestamp(ts),
        severity: "DEFAULT",
        message: IO.iodata_to_binary(msg)
      },
      format_metadata(md, state)
    )
    |> encode()
  end

  defp encode(event, json_encoder \\ Jason) do
    case json_encoder do
      nil ->
        raise ArgumentError,
              "invalid json_encoder. " <>
                "Expected one of supported encoders module name or {module, function}, " <>
                "got: #{inspect(json_encoder)}. Logged entry: #{inspect(event)}"

      {module, fun} ->
        apply(module, fun, [event]) <> "\n"

      json_encoder ->
        [json_encoder.encode_to_iodata!(event) | "\n"]
    end
  end

  defp format_metadata(md, state) do
    md
    |> LoggerFileBackendWithFormatters.take_metadata(state.metadata)
    |> maybe_put(:error, format_process_crash(md))
    |> maybe_put(:"logging.googleapis.com/sourceLocation", format_source_location(md))
    |> maybe_put(:"logging.googleapis.com/operation", format_operation(md))
    |> Enum.into(%{})
  end

  defp maybe_put(metadata, _key, nil), do: metadata
  defp maybe_put(metadata, key, value), do: metadata |> Keyword.put(key, value)

  defp format_operation(md) do
    if request_id = Keyword.get(md, :request_id) do
      json_map(id: request_id)
    end
  end

  defp format_process_crash(md) do
    if crash_reason = Keyword.get(md, :crash_reason) do
      initial_call = Keyword.get(md, :initial_call)

      json_map(
        initial_call: format_initial_call(initial_call),
        reason: format_crash_reason(crash_reason)
      )
    end
  end

  defp format_initial_call(nil), do: nil

  defp format_initial_call({module, function, arity}),
    do: format_function(module, function, arity)

  defp format_crash_reason({:throw, reason}) do
    Exception.format(:throw, reason)
  end

  defp format_crash_reason({:exit, reason}) do
    Exception.format(:exit, reason)
  end

  defp format_crash_reason({%{} = exception, stacktrace}) do
    Exception.format(:error, exception, stacktrace)
  end

  # https://cloud.google.com/logging/docs/agent/configuration#timestamp-processing
  defp format_timestamp({date, {h, m, s, ms}}) do
    duration = Time.from_erl!({h, m, s}) |> Timex.Duration.from_time()

    unix_sec =
      date
      |> Date.from_erl!()
      |> Timex.to_datetime()
      |> Timex.add(duration)
      |> Timex.to_unix()

    %{
      seconds: unix_sec,
      nanos: ms * 1_000 * 1_000
    }
  end

  # Description can be found in Google Cloud Logger docs;
  # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#LogEntrySourceLocation
  defp format_source_location(metadata) do
    file = Keyword.get(metadata, :file)
    line = Keyword.get(metadata, :line, 0)
    function = Keyword.get(metadata, :function)
    module = Keyword.get(metadata, :module)

    json_map(
      file: file,
      line: line,
      function: format_function(module, function)
    )
  end

  defp format_function(nil, function), do: function
  defp format_function(module, function), do: "#{module}.#{function}"
  defp format_function(module, function, arity), do: "#{module}.#{function}/#{arity}"
end
