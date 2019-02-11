defmodule LoggerFileBackendWithFormattersStackdriver.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_file_backend_with_formatters_stackdriver,
      version: "0.0.1",
      elixir: "~> 1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:logger_file_backend_with_formatters, "~> 0.0.1"},
      {:jason, "~> 1.1"}
    ]
  end
end
