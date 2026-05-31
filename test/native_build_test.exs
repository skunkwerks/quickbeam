defmodule QuickBEAM.Native.BuildTest do
  use ExUnit.Case, async: true

  describe "targets/2" do
    test "adds the current target only for source builds" do
      refute "x86_64-freebsd-none" in QuickBEAM.Native.Build.targets(
               false,
               "x86_64-freebsd-none"
             )

      assert "x86_64-freebsd-none" in QuickBEAM.Native.Build.targets(
               true,
               "x86_64-freebsd-none"
             )
    end
  end

  describe "force_build?/3" do
    test "honors explicit source build settings" do
      assert QuickBEAM.Native.Build.force_build?("1", false, "x86_64-linux-gnu")
      assert QuickBEAM.Native.Build.force_build?("true", false, "x86_64-linux-gnu")
      assert QuickBEAM.Native.Build.force_build?(nil, true, "x86_64-linux-gnu")
      refute QuickBEAM.Native.Build.force_build?(nil, false, "x86_64-linux-gnu")
    end

    test "source builds when no precompiled target is available" do
      assert QuickBEAM.Native.Build.force_build?(nil, false, "x86_64-freebsd-none")
      refute QuickBEAM.Native.Build.force_build?(nil, false, "x86_64-linux-gnu")
    end

    test "raises a clear error when source build needs Zigler" do
      assert_raise RuntimeError, ~r/Zigler is not available/, fn ->
        QuickBEAM.Native.Build.ensure_zigler_available!(true, false)
      end
    end
  end
end
