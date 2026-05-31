defmodule QuickBEAM.MixProject do
  use Mix.Project

  @version "0.10.15"
  @zig_version "0.15.2"

  @source_url "https://github.com/elixir-volt/quickbeam"

  def project do
    [
      app: :quickbeam,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:crypto, :inets, :ssl, :public_key]],
      name: "QuickBEAM",
      description:
        "JavaScript runtime for the BEAM — Web APIs backed by OTP, native DOM, and a built-in TypeScript toolchain.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs(),
      test_coverage: [tool: QuickBEAM.Cover, ignore_modules: [QuickBEAM.Native.Manifest]]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :public_key, :xmerl],
      mod: {QuickBEAM.Application, []}
    ]
  end

  def cli do
    [preferred_envs: [ci: :test, "qb.test": :test, "qb.native_build_test": :test]]
  end

  defp aliases do
    [
      "qb.zig": &ensure_zig/1,
      "qb.compile": &with_zig_compile/1,
      "qb.format": &with_zig_format/1,
      "qb.format.check": &with_zig_format_check/1,
      "qb.test": &with_zig_test/1,
      "qb.native_build_test": &with_zig_native_build_test/1,
      lint: [
        "format --check-formatted",
        "credo --strict",
        "ex_dna",
        "cmd zlint lib/quickbeam/*.zig lib/quickbeam/napi/*.zig",
        "cmd npx oxlint -c oxlint.json --type-aware --type-check priv/ts/",
        "cmd sh -c \"npx jscpd priv/ts/*.ts --min-tokens 50 --threshold 0\""
      ],
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "dialyzer",
        "ex_dna",
        "cmd zlint lib/quickbeam/*.zig lib/quickbeam/napi/*.zig",
        "cmd npx oxlint -c oxlint.json --type-aware --type-check priv/ts/",
        "cmd sh -c \"npx jscpd priv/ts/*.ts --min-tokens 50 --threshold 0\"",
        "test --no-start --exclude napi_addon --exclude napi_sqlite"
      ],
      "fuzz.sanity": "cmd --cd fuzz zig build test"
    ]
  end

  defp with_zig_compile(args), do: with_zig("compile", args)
  defp with_zig_test(args), do: with_zig("test", args)

  defp with_zig_native_build_test(args),
    do: with_zig("test", ["test/native_build_test.exs" | args])

  defp with_zig_format(args) do
    ensure_zig([])
    ensure_zig_formatter()
    Mix.Task.run("format", args)
  end

  defp with_zig_format_check(args) do
    ensure_zig([])
    ensure_zig_formatter()
    Mix.Task.run("format", ["--check-formatted" | args])
  end

  defp with_zig(task, args) do
    ensure_zig([])
    Mix.Task.run(task, args)
  end

  defp ensure_zig(_args) do
    ensure_zig_get_task()

    {arch, os} = zig_platform()
    path = zig_path(arch, os)

    unless File.exists?(path) do
      Mix.Task.run("zig.get", ["--os", os, "--arch", arch])
    end

    unless File.exists?(path) do
      Mix.raise("expected Zig #{@zig_version} at #{path}, but it was not installed")
    end

    System.put_env("ZIG_EXECUTABLE_PATH", path)
    Mix.shell().info("ZIG_EXECUTABLE_PATH=#{path}")
  end

  defp ensure_zig_get_task do
    zig_get_ebin = Path.join([Mix.Project.build_path(), "lib", "zig_get", "ebin"])
    zig_get_beam = Path.join(zig_get_ebin, "Elixir.Mix.Tasks.Zig.Get.beam")

    unless File.exists?(zig_get_beam) do
      Mix.Task.run("deps.get", [])
      Mix.Task.run("deps.compile", ["zig_get"])
    end

    Code.prepend_path(zig_get_ebin)
  end

  defp ensure_zig_formatter do
    zigler_ebin = Path.join([Mix.Project.build_path(), "lib", "zigler", "ebin"])
    formatter_beam = Path.join(zigler_ebin, "Elixir.Zig.Formatter.beam")

    unless File.exists?(formatter_beam) do
      Mix.Task.run("deps.compile", ["zigler", "--force"])
    end

    Code.prepend_path(zigler_ebin)
  end

  defp zig_path(arch, os) do
    Path.join([zig_cache(), "zig-#{arch}-#{os}-#{@zig_version}", zig_executable()])
  end

  defp zig_cache do
    System.get_env("ZIG_ARCHIVE_PATH", to_string(:filename.basedir(:user_cache, "zigler")))
  end

  defp zig_platform do
    {zig_arch(System.get_env("QUICKBEAM_ZIG_ARCH") || uname("-m")),
     zig_os(System.get_env("QUICKBEAM_ZIG_OS") || uname("-s"))}
  end

  defp uname(flag) do
    case System.cmd("uname", [flag], stderr_to_stdout: true) do
      {value, 0} -> String.trim(value)
      {_error, _status} -> ""
    end
  end

  defp zig_arch(arch) do
    arch
    |> String.downcase()
    |> case do
      "amd64" -> "x86_64"
      "x86_64" -> "x86_64"
      "arm64" -> "aarch64"
      "aarch64" -> "aarch64"
      "i386" -> "x86"
      "i686" -> "x86"
      other -> other
    end
  end

  defp zig_os(os) do
    os
    |> String.downcase()
    |> case do
      "freebsd" <> _version -> "freebsd"
      "darwin" <> _version -> "macos"
      "macos" <> _version -> "macos"
      "linux" <> _version -> "linux"
      other -> other
    end
  end

  defp zig_executable do
    if match?({:win32, _}, :os.type()), do: "zig.exe", else: "zig"
  end

  defp deps do
    [
      {:zigler_precompiled, "~> 0.1.4"},
      {:zigler, "~> 0.15.2", runtime: false, optional: true},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.2", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.4"},
      {:oxc, git: "https://github.com/skunkwerks/oxc_ex.git", branch: "feature/add-freebsd"},
      {:rustler, "~> 0.36 or ~> 0.37", optional: true},
      {:npm, "~> 0.7.4", optional: true},
      {:mint_web_socket, "~> 1.0"},
      {:nimble_pool, "~> 1.1"},
      {:bandit, "~> 1.0", only: :test},
      {:websock_adapter, "~> 0.5", only: :test},
      {:benchee, "~> 1.3", only: :bench, runtime: false},
      {:quickjs_ex, "~> 0.3.1", only: :bench, runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w[
        lib priv/c_src priv/ts
        mix.exs README.md LICENSE CHANGELOG.md
        checksum-QuickBEAM.Native.exs
        .formatter.exs
      ]
    ]
  end

  defp docs do
    [
      main: "QuickBEAM",
      extras: [
        "README.md",
        "docs/javascript-api.md",
        "docs/architecture.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Guides: ["docs/javascript-api.md", "docs/architecture.md"]
      ],
      source_ref: "v#{@version}"
    ]
  end
end
