class Jpegli < Formula
  desc "JPEG encoder with improved quality/density, split out of libjxl"
  homepage "https://github.com/google/jpegli"
  # jpegli has no tagged releases. Pinned to the exact commit the Daybook
  # Photos reclamation work measured against; see
  # docs/specs/2026-07-26-photos-icloud-reclamation.md in ephes/daybook.
  url "https://github.com/google/jpegli.git",
      revision: "031a0077f5799a6041004267fc12b956c1f52a20"
  version "0.0.0-20260601"
  license "BSD-3-Clause"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build

  depends_on "giflib"
  depends_on "highway"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "little-cms2"

  def install
    args = %w[
      -DBUILD_TESTING=OFF
      -DBUILD_SHARED_LIBS=OFF
      -DJPEGLI_ENABLE_TOOLS=ON
      -DJPEGLI_ENABLE_BENCHMARK=OFF
      -DJPEGLI_ENABLE_DEVTOOLS=OFF
      -DJPEGLI_ENABLE_DOXYGEN=OFF
      -DJPEGLI_ENABLE_FUZZERS=OFF
      -DJPEGLI_ENABLE_JNI=OFF
      -DJPEGLI_ENABLE_MANPAGES=OFF
      -DJPEGLI_ENABLE_OPENEXR=OFF
      -DJPEGLI_ENABLE_SJPEG=OFF
      -DJPEGLI_FORCE_SYSTEM_HWY=ON
      -DJPEGLI_FORCE_SYSTEM_LCMS2=ON
    ]

    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja", *std_cmake_args, *args
    system "cmake", "--build", "build"

    bin.install "build/tools/cjpegli"
    bin.install "build/tools/djpegli" if File.exist?("build/tools/djpegli")
  end

  test do
    # A tiny binary P6 PPM proves the encoder runs and emits a real JPEG.
    # cjpegli rejects ASCII P3, so the pixel data must be raw bytes.
    pixels = (0...4).flat_map do |y|
      (0...4).flat_map { |x| [(x * 60) % 256, (y * 60) % 256, ((x + y) * 40) % 256] }
    end
    (testpath/"in.ppm").binwrite("P6\n4 4\n255\n" + pixels.pack("C*"))

    system bin/"cjpegli", testpath/"in.ppm", testpath/"out.jpg", "-d", "1.0"
    assert_predicate testpath/"out.jpg", :exist?
    assert_predicate (testpath/"out.jpg").size, :positive?

    # JPEG SOI marker
    assert_equal "\xFF\xD8".b, (testpath/"out.jpg").binread(2)
  end
end
