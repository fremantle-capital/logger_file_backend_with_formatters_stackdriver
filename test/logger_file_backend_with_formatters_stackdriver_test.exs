defmodule LoggerFileBackendWithFormattersStackdriverTest do
  use ExUnit.Case, async: false
  doctest LoggerFileBackendWithFormattersStackdriver
  require Logger

  @backend {LoggerFileBackendWithFormatters, :test}
  @basedir "test/logs"

  setup_all do
    on_exit(fn ->
      File.rm_rf!(@basedir)
    end)
  end

  setup context do
    # We add and remove the backend here to avoid cross-test effects
    Logger.add_backend(@backend, flush: true)

    config(path: logfile(context, @basedir), level: :debug)

    on_exit(fn ->
      :ok = Logger.remove_backend(@backend)
    end)
  end

  test "formats each event as stackdriver JSON per line" do
    config(formatter: LoggerFileBackendWithFormattersStackdriver)

    Logger.debug("hello")
    Logger.info("world")

    {jsonl_1, jsonl_2} = log_lines()

    assert jsonl_1 |> Map.fetch!("log") == "hello"
    assert jsonl_1 |> Map.fetch!("severity") == "DEBUG"
    assert jsonl_1 |> Map.fetch!("time") != nil
    assert jsonl_1 |> Map.fetch!("logging.googleapis.com/sourceLocation") != nil

    assert jsonl_2 |> Map.fetch!("log") == "world"
    assert jsonl_2 |> Map.fetch!("severity") == "INFO"
    assert jsonl_2 |> Map.fetch!("time") != nil
    assert jsonl_2 |> Map.fetch!("logging.googleapis.com/sourceLocation") != nil
  end

  test "can configure metadata" do
    config(formatter: LoggerFileBackendWithFormattersStackdriver, metadata: [:user_id, :auth])

    Logger.debug("hello")
    Logger.metadata(auth: true)
    Logger.metadata(user_id: 11)
    Logger.metadata(user_id: 13)
    Logger.debug("world")

    {jsonl_1, jsonl_2} = log_lines()

    assert jsonl_1 |> Map.fetch!("log") == "hello"
    assert jsonl_1 |> Map.get("user_id") == nil
    assert jsonl_1 |> Map.get("auth") == nil

    assert jsonl_2 |> Map.fetch!("log") == "world"
    assert jsonl_2 |> Map.fetch!("user_id") == 13
    assert jsonl_2 |> Map.fetch!("auth") == true
  end

  defp log_lines do
    log()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
    |> List.to_tuple()
  end

  defp path do
    {:ok, path} = :gen_event.call(Logger, @backend, :path)
    path
  end

  defp log do
    File.read!(path())
  end

  defp config(opts) do
    :ok = Logger.configure_backend(@backend, opts)
  end

  defp logfile(context, basedir) do
    logfile =
      context.test
      |> Atom.to_string()
      |> String.replace(" ", "_")

    Path.join(basedir, logfile)
  end
end
