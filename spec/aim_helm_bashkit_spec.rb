# frozen_string_literal: true

RSpec.describe AimHelmBashkit do
  it "loads the pinned libbashkit" do
    expect(described_class.version).to eq(AimHelmBashkit::BASHKIT_VERSION)
    expect(described_class.capabilities).to include("abi" => 1)
  end
end
