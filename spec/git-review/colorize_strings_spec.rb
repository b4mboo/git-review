require_relative '../spec_helper'
require_relative '../../lib/git-review/colorize_strings'

describe 'String Colorization' do

  subject { "Paint me like one of your French girls." }

  it 'allows to set an arbitrary color code for any String' do
    color_code = 42
    expect(subject.colorize(color_code)).
      to eq("\e[#{color_code}m#{subject}\e[0m")
  end

  context 'provides helper methods for commonly used colors' do

    colors = {
      red: 31,
      green: 32,
      yellow: 33,
      blue: 34,
      pink: 35
    }

    colors.each do |color, code|
      it "offers a preset for #{color.to_s.send(color)} (code: #{code})" do
        expect(subject.send(color)).to eq(subject.colorize(code))
      end
    end

  end

end
