# frozen_string_literal: true

def gemspec_file(name)
  File.join(__dir__, "gemspecs", name)
end

RSpec.describe Jwl do
  it "has a version number" do
    expect(Jwl::VERSION).not_to be nil
  end

  describe "load_spec" do
    # As a starting point, I'm just including a few gemspecs I have.
    # I'll add more targeted tests or fuzzing later.
    it "loads inq.gemspec" do
      spec = Jwl.load_spec(gemspec_file("inq.gemspec"))
      expect(spec.name).to eq("inq")
      expect(spec.authors).to eq(["Ellen Marie Dash"])
      expect(spec.email).to eq(["me@duckie.co"])
      expect(spec.summary).not_to be_empty
      expect(spec.homepage).not_to be_empty
      expect(spec.licenses).to eq(["MIT"])
      expect(spec.runtime_dependencies).to eq({"github_api" => ["= 0.18.2"], "okay" => ["~> 12.0"], "json_pure" => []})
    end
  end
end
