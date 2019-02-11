defmodule LoggerFileBackendWithFormattersStackdriver.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_file_backend_with_formatters_stackdriver,
      version: "0.0.1",
      elixir: "~> 1.0",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Google Cloud Stackdriver formatter for :logger_file_backend_with_formatters"
  end

  defp package do
    [
      maintainers: ["Alex Kwiatkowski"],
      licenses: ["MIT"],
      links: %{
        "GitHub" =>
          "https://github.com/fremantle-capital/logger_file_backend_with_formatters_stackdriver"
      }
    ]
  end

  defp deps do
    [
      {:logger_file_backend_with_formatters, "~> 0.0.1"},
      {:jason, "~> 1.1"},
      {:ex_doc, "~> 0.19", only: :dev}
    ]
  end
end
